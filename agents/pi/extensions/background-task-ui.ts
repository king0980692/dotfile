import { readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, stripTerminalSequences, truncateToWidth, visibleWidth, type TuiMouseEvent } from "@earendil-works/pi-tui";

type Command = Parameters<ExtensionAPI["registerCommand"]>[1];
type Tool = Parameters<ExtensionAPI["registerTool"]>[0];
type Job = { id: string; command: string; status: string; elapsed: string; log: string };

const clean = (text: string) => stripTerminalSequences(text.split("\r").at(-1) ?? "").replace(/[\x00-\x1f\x7f]/g, " ");

// bg_status prints a summary header followed by a log path. Split on our own
// process's log path so multiline commands do not get mistaken for new jobs.
function parseJobs(text: string): Job[] {
	const jobs: Job[] = [];
	let start = 0;
	for (const match of text.matchAll(/\n  log: ([^\n]+)(?:\n|$)/g)) {
		const header = /^(bg\d+) \[([^,]+), ([^\]]+)\] ([\s\S]*)$/.exec(text.slice(start, match.index));
		if (!header || match[1] !== join(tmpdir(), "pi-bg", `${process.pid}-${header[1]}.log`)) continue;
		jobs.push({ id: header[1], status: header[2], elapsed: header[3], command: header[4], log: match[1] });
		start = match.index + match[0].length;
	}
	return jobs;
}

export default async function (pi: ExtensionAPI) {
	const packageDir = join(getAgentDir(), "npm", "node_modules", "pi-background");
	const manifest = JSON.parse(readFileSync(join(packageDir, "package.json"), "utf8")) as { pi?: { extensions?: string[] } };
	const entry = manifest.pi?.extensions?.[0];
	if (!entry) throw new Error("pi-background has no extension entry point");
	const { default: upstream } = await import(join(packageDir, entry)) as { default: (api: ExtensionAPI) => void | Promise<void> };

	let statusTool: Tool | undefined;
	let killTool: Tool | undefined;
	let upstreamCommand: Command | undefined;
	let uiContext: ExtensionContext | undefined;
	let compatible = false;
	let jobs: Job[] = [];
	let refreshTimer: ReturnType<typeof setInterval> | undefined;
	let pending: Promise<void> | undefined;
	let viewerOpen = false;
	let redrawViewer: (() => void) | undefined;
	let footerLabel: string | undefined;
	let refreshUpstreamWidget: (() => void) | undefined;

	// Load the npm extension once. Keep its native commands and tool definitions;
	// the adapter uses bg_status and bg_kill and filters its redundant jobs widget.
	const adapter = Object.create(pi) as ExtensionAPI;
	adapter.registerTool = (tool) => {
		if (tool.name === "bg_status") statusTool = tool;
		if (tool.name === "bg_kill") killTool = tool;
		pi.registerTool(tool);
	};
	adapter.registerCommand = (name, command) => {
		if (name !== "bg") return pi.registerCommand(name, command);
		upstreamCommand = command;
		pi.registerCommand(name, { ...command, handler: (args, ctx) => compatible && ctx.mode === "tui" ? show(args, ctx) : command.handler(args, ctx) });
	};
	adapter.on = ((name: string, handler: (event: unknown, ctx: ExtensionContext) => unknown) => {
		if (name === "input") {
			return pi.on("input", (event, ctx) => {
				if (compatible && ctx.mode === "tui" && /^\/bg\d+$/i.test(event.text.trim())) return;
				return handler(event, ctx) as never;
			});
		}
		if (name !== "session_start") return Reflect.apply(pi.on, pi, [name, handler]);
		return pi.on("session_start", (event, ctx) => {
			if (ctx.mode !== "tui" || !compatible) return handler(event, ctx);
			const ui: ExtensionContext["ui"] = { ...ctx.ui, setWidget: (key, widget, options) => {
				if (key !== "background-jobs") return ctx.ui.setWidget(key, widget, options);
				// Retain the upstream widget as a fallback if a future release changes the tool format.
				refreshUpstreamWidget = () => ctx.ui.setWidget(key, widget, options);
			} };
			const upstreamContext = Object.create(ctx, { ui: { value: ui } }) as ExtensionContext;
			return handler(event, upstreamContext);
		});
	}) as ExtensionAPI["on"];
	await upstream(adapter);
	compatible = Boolean(statusTool && killTool && upstreamCommand);
	if (!compatible) return;

	function publish() {
		if (!uiContext) return;
		const count = jobs.filter(job => job.status === "running").length;
		const hidden = (pi.getSettings() as { background?: { jobs?: string } }).background?.jobs === "off";
		const label = count && !hidden && !viewerOpen ? `${count} active ${count === 1 ? "shell" : "shells"}` : undefined;
		if (label !== footerLabel) uiContext.ui.setStatus("background-shells", footerLabel = label);
	}

	function refresh(): Promise<void> {
		if (!uiContext || !compatible || !statusTool) return Promise.resolve();
		if (pending) return pending;
		const ctx = uiContext;
		pending = statusTool.execute("background-ui-list", {}, undefined, undefined, ctx as Parameters<Tool["execute"]>[4])
			.then(result => {
				if (ctx !== uiContext) return;
				const text = result.content.find(content => content.type === "text")?.text ?? "";
				jobs = parseJobs(text);
				if (!jobs.length && text !== "No background jobs.") {
					compatible = false;
					refreshUpstreamWidget?.();
				}
				if (jobs.some(job => job.status === "running")) refreshTimer ??= setInterval(() => void refresh(), 1000);
				else { clearInterval(refreshTimer); refreshTimer = undefined; }
				publish();
				redrawViewer?.();
			})
			.catch(() => {
				clearInterval(refreshTimer);
				refreshTimer = undefined;
				compatible = false;
				jobs = [];
				if (ctx === uiContext) { publish(); refreshUpstreamWidget?.(); }
			})
			.finally(() => { pending = undefined; });
		return pending;
	}

	async function show(args: string, ctx: ExtensionContext) {
		if (!ctx.hasUI || ctx.mode !== "tui" || viewerOpen || !compatible) return;
		viewerOpen = true;
		try {
			await refresh();
			if (!jobs.length) return ctx.ui.notify(compatible ? "No background jobs yet" : "Background task display unavailable. Use /bg to open the upstream viewer.", "info");
			const wanted = args.trim().toLowerCase().replace(/^(\d+)$/, "bg$1");
			if (wanted && !jobs.some(job => job.id === wanted)) return ctx.ui.notify(`No background job ${wanted}`, "warning");
			publish();
			await ctx.ui.custom<void>((tui, theme, keys, done) => {
				let selected = wanted;
				let detail = Boolean(wanted);
				let rendered: Job[] = [];
				let backRow = -1;
				let output = "";
				let outputJob = "";
				const draw = () => tui.requestRender();
				const list = () => {
					const latest = [...jobs].reverse();
					const items = [...latest.filter(job => job.status === "running"), ...latest.filter(job => job.status !== "running").slice(0, 10)];
					const requested = latest.find(job => job.id === selected);
					if (detail && requested && !items.includes(requested)) items.push(requested);
					return items;
				};
				const readOutput = async () => {
					const id = selected;
					if (!detail || !id || !statusTool) return draw();
					const job = jobs.find(item => item.id === id);
					if (!job) return;
					try {
						const result = await statusTool.execute("background-ui-output", { id, lines: 20 }, undefined, undefined, ctx as Parameters<Tool["execute"]>[4]);
						const text = result.content.find(content => content.type === "text")?.text ?? "";
						const separator = `\n  log: ${job.log}\n`;
						const index = text.indexOf(separator);
						if (detail && selected === id && index >= 0) { output = text.slice(index + separator.length); outputJob = id; }
					} catch { /* keep the last readable output */ }
					draw();
				};
				const open = (job?: Job) => {
					if (job) selected = job.id;
					detail = Boolean(job);
					void readOutput();
					draw();
				};
				const stop = async (job: Job) => {
					if (job.status !== "running" || !killTool) return;
					try {
						await killTool.execute("background-ui-stop", { id: job.id }, undefined, undefined, ctx as Parameters<Tool["execute"]>[4]);
						await refresh();
					} catch (error) { ctx.ui.notify(String(error), "error"); }
				};
				redrawViewer = () => void readOutput();
				if (detail) void readOutput();
				return {
					invalidate() {},
					handleInput(data: string) {
						if (keys.matches(data, "tui.select.cancel") || matchesKey(data, "q")) return done();
						const items = list();
						const index = Math.max(0, items.findIndex(job => job.id === selected));
						const job = items[index];
						if (matchesKey(data, Key.left)) return detail ? open() : done();
						if (job && matchesKey(data, "x")) return void stop(job);
						if (keys.matches(data, "tui.select.confirm")) return detail ? done() : open(job);
						if (detail) { if (matchesKey(data, Key.space)) done(); return; }
						const step = keys.matches(data, "tui.select.up") ? -1 : keys.matches(data, "tui.select.down") ? 1 : 0;
						if (step && job) { selected = items[Math.max(0, Math.min(index + step, items.length - 1))].id; draw(); }
					},
					handleMouse(event: TuiMouseEvent) {
						if (event.type !== "click" || event.button !== "left") return;
						if (detail) {
							if (event.y !== backRow || event.x >= visibleWidth("  ← Back")) return;
							open();
						} else {
							const job = rendered[event.y - 1];
							if (!job) return;
							open(job);
						}
						return { handled: true };
					},
					render(width: number) {
						const rows = Math.max(1, Math.min(20, Math.floor(tui.terminal.rows / 2) - 4));
						const items = list();
						const index = Math.max(0, items.findIndex(job => job.id === selected));
						const job = items[index];
						if (job) selected = job.id;
						const stopHint = job?.status === "running" ? " · x stop" : "";
						let lines: string[];
						if (detail && job) {
							const log = outputJob === job.id && output && output !== "(no output)" ? output.split("\n").slice(-rows).map(line => `   ${clean(line)}`) : [theme.fg("dim", "   No output yet")];
							lines = [theme.fg("accent", ` Shell ${job.id} · ${job.status} · ${job.elapsed}`), theme.fg("toolTitle", ` $ ${clean(job.command.replace(/\n/g, " "))}`), ...log,
								theme.fg("dim", `  ← Back · Esc/Enter/Space close${stopHint}`), theme.fg("dim", `  ${job.log}`)];
							backRow = lines.length - 2;
						} else {
							const first = Math.max(0, index - rows + 1);
							rendered = items.slice(first, first + rows);
							lines = [theme.fg("accent", ` Background jobs · ${jobs.filter(item => item.status === "running").length} running`),
								...rendered.map(item => theme.fg("accent", item.id === selected ? " › " : "   ") + theme.fg("muted", `${item.id} · ${item.status} · ${item.elapsed}`) + theme.fg("toolTitle", `  ${clean(item.command.split("\n")[0])}`)),
								theme.fg("dim", `  ${items.length > 1 ? "↑/↓ select · " : ""}Enter view · Esc close${stopHint}`)];
						}
						return lines.map(line => truncateToWidth(line, width));
					},
				};
			});
		} finally {
			redrawViewer = undefined;
			viewerOpen = false;
			publish();
		}
	}

	pi.registerCommand("tasks", { description: "Open the background shell task list", handler: (args, ctx) => compatible && ctx.mode === "tui" ? show(args, ctx) : upstreamCommand!.handler(args, ctx) });
	pi.registerShortcut("f8", { description: "Open background shell jobs", handler: ctx => show("", ctx) });
	pi.on("session_start", (_event, ctx) => { if (ctx.mode === "tui") uiContext = ctx; });
	pi.events.on("pi-background:open-jobs", () => { if (uiContext) void show("", uiContext); });
	pi.on("tool_execution_end", (event) => {
		if (["bg_run", "bg_kill", "bash"].includes(event.toolName)) return refresh();
	});
	pi.on("message_end", (event) => {
		if (event.message.role === "custom" && event.message.customType === "background-job") return refresh();
	});
	pi.on("input", async (event, ctx) => {
		const id = event.text.trim().match(/^\/(bg\d+)$/i)?.[1];
		if (!id || !compatible || ctx.mode !== "tui" || !jobs.some(job => job.id === id.toLowerCase())) return;
		await show(id, ctx);
		return { action: "handled" };
	});
	pi.on("session_shutdown", () => { clearInterval(refreshTimer); uiContext = undefined; });
}
