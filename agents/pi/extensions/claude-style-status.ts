import { execFile } from "node:child_process";
import { mkdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const exec = promisify(execFile);
type Window = { used_percent: number; limit_window_seconds: number; reset_at: number };
type Usage = { rate_limit?: { primary_window?: Window | null; secondary_window?: Window | null } | null };

// Raw usage answers shared with herdr-sidebar's Usage view (which reads and
// writes the same files): ~/.cache/agent-usage/<name>.json. Whoever asked in
// the last minute saves everyone else the request.
const CACHE_DIR = join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "agent-usage");
const CACHE_TTL_MS = 60_000;
async function readCache(name: string): Promise<unknown | undefined> {
	try {
		const path = join(CACHE_DIR, `${name}.json`);
		if (Date.now() - (await stat(path)).mtimeMs >= CACHE_TTL_MS) return undefined;
		return JSON.parse(await readFile(path, "utf8"));
	} catch { return undefined; }
}
async function writeCache(name: string, body: unknown): Promise<void> {
	try {
		await mkdir(CACHE_DIR, { recursive: true });
		const path = join(CACHE_DIR, `${name}.json`);
		const tmp = `${path}.${process.pid}.tmp`;
		await writeFile(tmp, JSON.stringify(body));
		await rename(tmp, path);
	} catch { /* a cache, not a requirement */ }
}
// OpenCode Go key, as pi-codex-status resolves it: $OPENCODE_API_KEY, then
// opencode's auth.json. Inlined rather than imported by absolute path, so this
// file works from the dotfiles (as a symlink) on every machine.
async function resolveOpenCodeGoApiKey(): Promise<string | null> {
	const envKey = process.env.OPENCODE_API_KEY?.trim();
	if (envKey) return envKey;
	const dataHome = process.env.XDG_DATA_HOME?.trim() || join(homedir(), ".local", "share");
	try {
		const auth = JSON.parse(await readFile(join(dataHome, "opencode", "auth.json"), "utf8"));
		const key = auth?.["opencode-go"]?.key;
		return typeof key === "string" && key.trim() ? key.trim() : null;
	} catch { return null; }
}
// The same parsing as pi-codex-status's fetchOpenCodeGoUsage, on a raw answer.
function parseOpenCodeGo(raw: unknown) {
	const usage = (raw as { usage?: Record<string, { percent?: unknown; resetsAt?: unknown }> } | null)?.usage;
	const window = (w: { percent?: unknown; resetsAt?: unknown } | undefined) => {
		if (!w || typeof w.percent !== "number" || typeof w.resetsAt !== "string") return undefined;
		const resetAt = Date.parse(w.resetsAt);
		return Number.isFinite(resetAt) ? { usedPercent: Math.min(100, Math.max(0, w.percent)), resetAt } : undefined;
	};
	const rolling = window(usage?.rolling), weekly = window(usage?.weekly), monthly = window(usage?.monthly);
	if (!rolling || !weekly || !monthly) throw new Error("OpenCode Go usage API returned invalid data");
	return { rolling, weekly, monthly };
}

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | undefined;
	let generation = 0;
	let running = false;
	let nextUsage = 0;
	let usage: Usage | undefined;
	let usageFailed = false;
	let suffix = "";
	let provider = "";
	let pendingRefresh = false;
	let openCodeUsage: ReturnType<typeof parseOpenCodeGo> | undefined;

	function redraw(ctx: ExtensionContext) {
		if (!suffix || ctx.mode !== "tui") return;
		const thinking = ctx.model?.reasoning ? `\x1b[0m · \x1b[36m${pi.getThinkingLevel()}` : "";
		const text = `[\x1b[1;33m${ctx.model?.name ?? ctx.model?.id ?? "no model"}${thinking}\x1b[0m]${suffix}`;
		ctx.ui.setWidget("claude-style", [text], { placement: "belowEditor" });
	}

	async function refresh(ctx: ExtensionContext) {
		if (running) { pendingRefresh = true; return; }
		running = true;
		const current = generation;
		const activeProvider = ctx.model?.provider ?? "";
		if (provider !== activeProvider) {
			provider = activeProvider;
			nextUsage = 0;
			usage = undefined;
			openCodeUsage = undefined;
			usageFailed = false;
		}
		try {
			const git = await exec("git", ["--no-optional-locks", "status", "--porcelain=v1", "-b"], { cwd: ctx.cwd, timeout: 5000 }).then(r => r.stdout).catch(() => "");
			if ((activeProvider === "openai-codex" || activeProvider === "opencode-go") && Date.now() >= nextUsage) {
				nextUsage = Date.now() + 60000;
				try {
					if (activeProvider === "opencode-go") {
						let raw = await readCache("opencode-go");
						if (raw === undefined) {
							const auth = await ctx.modelRegistry.getProviderAuth("opencode-go");
							const key = await resolveOpenCodeGoApiKey() ?? auth?.auth?.apiKey;
							if (typeof key !== "string" || !key) throw new Error("No OpenCode Go credentials");
							const response = await fetch("https://opencode.ai/zen/go/v1/usage", {
								headers: { Authorization: `Bearer ${key}` },
								signal: AbortSignal.timeout(5000),
							});
							if (!response.ok) throw new Error(`OpenCode Go usage API returned ${response.status}`);
							raw = await response.json();
							await writeCache("opencode-go", raw);
						}
						openCodeUsage = parseOpenCodeGo(raw);
					} else {
					const auth = await ctx.modelRegistry.getProviderAuth("openai-codex");
					const token = auth?.auth?.apiKey;
					if (typeof token !== "string") throw new Error("No Codex credentials");
					const payload = JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString());
					const accountId = payload["https://api.openai.com/auth"]?.chatgpt_account_id;
					if (typeof accountId !== "string") throw new Error("No account ID");
					// Per account: pi's Codex login can differ from the Codex CLI's.
					const cached = await readCache(`codex-${accountId}`);
					if (cached !== undefined) {
						usage = cached as Usage;
					} else {
					const response = await fetch("https://chatgpt.com/backend-api/wham/usage", {
						headers: { Authorization: `Bearer ${token}`, "ChatGPT-Account-Id": accountId },
						signal: AbortSignal.timeout(10000),
					});
					if (!response.ok) throw new Error(`Usage HTTP ${response.status}`);
					usage = await response.json() as Usage;
					await writeCache(`codex-${accountId}`, usage);
					}
					}
					usageFailed = false;
				} catch {
					usage = undefined;
					openCodeUsage = undefined;
					usageFailed = true;
				}
			}
			if (current !== generation) return;
			if ((ctx.model?.provider ?? "") !== activeProvider) { pendingRefresh = true; return; }
			const home = homedir();
			const path = ctx.cwd === home ? "~" : ctx.cwd.startsWith(`${home}/`) ? `~${ctx.cwd.slice(home.length)}` : ctx.cwd;
			const dir = path.split("/").slice(-4).join("/");
			const lines = git.split("\n");
			const header = lines[0]?.startsWith("## ") ? lines[0].slice(3) : "";
			const branch = header.split("...")[0].replace(/^HEAD \(no branch\)$/, "HEAD");
			const changes = lines.slice(1);
			const flags = [changes.some(l => l.startsWith("??")) ? "?" : "", changes.some(l => /^[MADRC]/.test(l)) ? "+" : "", changes.some(l => /^.[MD]/.test(l)) ? "!" : "", changes.some(l => /^R/.test(l)) ? "»" : "", changes.some(l => /^(UU|AA|DD|AU|UA|DU|UD)/.test(l)) ? "✖" : "", header.match(/ahead (\d+)/)?.[1] ? `⇡${header.match(/ahead (\d+)/)?.[1]}` : "", header.match(/behind (\d+)/)?.[1] ? `⇣${header.match(/behind (\d+)/)?.[1]}` : ""].join("");
			const gauge = (w: Window | null | undefined, windowLabel?: string) => {
				if (!w || typeof w.used_percent !== "number" || typeof w.reset_at !== "number" || w.reset_at * 1000 <= Date.now()) return undefined;
				const percent = Math.min(100, Math.max(0, Math.round(w.used_percent)));
				const filled = Math.round(percent * 6 / 100);
				const hours = w.limit_window_seconds / 3600;
				const label = windowLabel ?? (hours === 168 ? "7d" : `${hours}h`);
				const mins = Math.max(0, Math.ceil((w.reset_at * 1000 - Date.now()) / 60000));
				const reset = mins >= 60 ? `${Math.floor(mins / 60)}h` : `${mins}m`;
				const color = percent >= 85 ? 31 : percent >= 50 ? 33 : 32;
				return `\x1b[${color}m${label}${"━".repeat(filled)}${percent}%\x1b[90m${"─".repeat(6 - filled)} ↻${reset}\x1b[0m`;
			};
			const goWindow = (w: { usedPercent: number; resetAt: number } | undefined, hours: number): Window | undefined => w && ({ used_percent: w.usedPercent, reset_at: w.resetAt / 1000, limit_window_seconds: hours * 3600 });
			const gauges = activeProvider === "opencode-go"
				? [gauge(goWindow(openCodeUsage?.rolling, 0), "rolling"), gauge(goWindow(openCodeUsage?.weekly, 0), "7d"), gauge(goWindow(openCodeUsage?.monthly, 0), "month")].filter(Boolean).join("|")
				: [gauge(usage?.rate_limit?.primary_window), gauge(usage?.rate_limit?.secondary_window)].filter(Boolean).join("|");
			const usageLabel = activeProvider === "opencode-go" ? "OpenCode Go" : activeProvider === "openai-codex" ? "Codex" : "";
			suffix = `[\x1b[36m${dir}\x1b[0m]${branch ? `[\x1b[35m${branch}\x1b[0m]` : ""}${flags ? `[${flags}]` : ""}${usageLabel ? `[${usageLabel} ${gauges || (usageFailed ? "usage unavailable" : "usage unknown")}]` : ""}`;
			redraw(ctx);
		} finally {
			running = false;
			if (pendingRefresh && current === generation) {
				pendingRefresh = false;
				void refresh(ctx);
			}
		}
	}

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		generation++;
		ctx.ui.setFooter((_tui, _theme, footerData) => ({

			render: (width) => {
				const status = footerData.getExtensionStatuses().get("plan-mode");
				const planning = status === "plan active" || status === "plan ready";
				const label = planning ? "⏸ plan mode on" : "⏵⏵ auto mode on";
				const color = planning ? "\x1b[38;2;187;120;255m" : "\x1b[38;2;255;210;75m";
				return [truncateToWidth(`${color} ${label}\x1b[0m\x1b[90m (shift+tab to cycle)\x1b[0m`, width)];
			},
			invalidate() {},
		}));
		const current = generation;
		setImmediate(() => {
			if (current !== generation) return;
			const previous = ctx.ui.getEditorComponent();
			if (!previous) return;
			ctx.ui.setEditorComponent((tui, theme, keybindings) => {
				const editor = previous(tui, theme, keybindings);
				for (const entry of ctx.sessionManager.getBranch()) {
					if (entry.type !== "message" || entry.message.role !== "user") continue;
					const content = entry.message.content;
					const text = typeof content === "string" ? content : content.filter(part => part.type === "text").map(part => part.text).join("\n");
					if (text) editor.addToHistory?.(text);
				}
				const render = editor.render.bind(editor);
				editor.render = (width) => {
					const lines = render(width);
					if (lines.length > 1) {
						const symbol = "⚡";
						const borderColor = (editor as unknown as { borderColor?: (text: string) => string }).borderColor ?? theme.borderColor;
						lines[1] = lines[1].replace("❯ ", borderColor(symbol) + " ".repeat(Math.max(0, 2 - visibleWidth(symbol))));
					}
					const history = editor as unknown as { history?: string[]; historyIndex?: number };
					const index = history.historyIndex ?? -1;
					const count = history.history?.length ?? 0;
					if (lines.length > 0 && index >= 0 && index < count) {
						const label = ` History ${count - index}/${count} `;
						const prefix = "───";
						if (visibleWidth(prefix + label) <= width) {
							const borderColor = (editor as unknown as { borderColor?: (text: string) => string }).borderColor ?? theme.borderColor;
							lines[0] = borderColor(prefix + label) + truncateToWidth(lines[0], width - visibleWidth(prefix + label), "");
						}
					}
					return lines;
				};
				return editor;
			});
		});
		void refresh(ctx);
		timer = setInterval(() => void refresh(ctx), 10000);
		timer.unref();
	});
	pi.on("thinking_level_select", (_event, ctx) => redraw(ctx));
	pi.on("model_select", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		suffix = "";
		void refresh(ctx);
	});
	pi.on("session_shutdown", () => {
		generation++;
		suffix = "";
		if (timer) clearInterval(timer);
		timer = undefined;
	});
}
