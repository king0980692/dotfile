//! herdr-goto — a Rust re-implementation of herdr's built-in "Go to" navigator
//! (the `goto` keybinding). Shows machine > workspace > pane as a foldable
//! tree, with fuzzy search, agent-status filters, MRU "last workspace" jump and
//! an optional live preview of the selected pane; Enter focuses the selection.
//!
//! Data
//!   * Local server: `session.snapshot` over the unix socket, then a watcher
//!     thread keeps an `events.subscribe` connection open and re-fetches the
//!     snapshot on every event (plus a slow fallback poll), so the tree is live.
//!   * Saved SSH machines: last snapshot cached under ~/.cache/herdr/goto/ is
//!     shown immediately (marked "cached"); a thread per machine refreshes via
//!     `herdr --machine <name> api snapshot` and keeps polling while open.
//!   * Git branches for local workspaces are resolved in the background.
//!   * Worktrees: `worktree.list` per local repo (background, throttled). Open
//!     worktrees mark their workspace with ⎇; closed ones are listed under the
//!     repo's first workspace and Enter opens them (`worktree.open --focus`).
//!   * Preview: `pane.read` (socket) / `herdr --machine X pane read` (remote)
//!     from a worker thread, debounced on selection changes.
//!   * MRU: ~/.cache/herdr/goto/recency ("machine\tworkspace_id", newest
//!     first), stamped on launch and on every focus. Local ids are mirrored to
//!     ~/.cache/herdr/workspace-recency for the fzf switcher script.
//!
//! Focus: local via socket `workspace.focus` / `tab.focus` / `pane.focus`;
//! remote via `herdr --machine <name> workspace|tab focus` (the local TUI has
//! no API to switch its machine view, so remote focus only moves that server's
//! own focus).

use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::{self, BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::Command;
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use fuzzy_matcher::skim::SkimMatcherV2;
use fuzzy_matcher::FuzzyMatcher;
use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Cell, Clear, Paragraph, Row as TRow, Table, TableState};
use serde_json::{json, Value};

const REMOTE_POLL: Duration = Duration::from_secs(10);
const LOCAL_FALLBACK_POLL: Duration = Duration::from_secs(3);
const PREVIEW_DEBOUNCE: Duration = Duration::from_millis(120);
const PREVIEW_REFRESH: Duration = Duration::from_secs(2);
const RECENCY_MAX: usize = 200;

// ---------------------------------------------------------------- model

#[derive(Clone, Debug)]
struct Pane {
    pane_id: String,
    tab_id: String,
    tab_number: u64,
    title: String,
    agent: Option<String>,
    status: String,
    cwd: String,
    focused: bool,
}

#[derive(Clone, Debug)]
struct Workspace {
    workspace_id: String,
    number: u64,
    label: String,
    cwd: String, // cwd of the first pane; key for the branch cache
    panes: Vec<Pane>,
}

#[derive(Clone, Debug)]
struct Worktree {
    path: String,
    branch: String,
    linked: bool,
    open_ws: Option<String>, // workspace id if herdr has it open
    prunable: bool,
}

#[derive(Clone, Debug)]
struct Repo {
    name: String,
    worktrees: Vec<Worktree>,
}

#[derive(Clone, Debug)]
enum Load {
    Loading,
    Ready,
    Failed(String),
}

#[derive(Clone, Debug)]
struct Machine {
    name: String,
    remote: bool,
    load: Load,
    stale: bool, // data came from the on-disk cache, not a live fetch
    workspaces: Vec<Workspace>,
    focused_workspace: String,
    focused_pane: String,
}

impl Machine {
    fn placeholder(name: &str) -> Machine {
        Machine {
            name: name.to_string(),
            remote: true,
            load: Load::Loading,
            stale: false,
            workspaces: vec![],
            focused_workspace: String::new(),
            focused_pane: String::new(),
        }
    }
    fn pane_count(&self) -> usize {
        self.workspaces.iter().map(|w| w.panes.len()).sum()
    }
    fn pane_ids(&self) -> Vec<String> {
        self.workspaces.iter().flat_map(|w| w.panes.iter().map(|p| p.pane_id.clone())).collect()
    }
}

fn parse_snapshot(snap: &Value, name: &str, remote: bool) -> Machine {
    let s = |v: &Value, k: &str| v.get(k).and_then(Value::as_str).unwrap_or("").to_string();
    let n = |v: &Value, k: &str| v.get(k).and_then(Value::as_u64).unwrap_or(0);

    let mut tab_numbers: HashMap<String, u64> = HashMap::new();
    for t in snap.get("tabs").and_then(Value::as_array).into_iter().flatten() {
        tab_numbers.insert(s(t, "tab_id"), n(t, "number"));
    }

    let mut panes_by_ws: HashMap<String, Vec<Pane>> = HashMap::new();
    for p in snap.get("panes").and_then(Value::as_array).into_iter().flatten() {
        let agent = p.get("agent").and_then(Value::as_str).map(str::to_string);
        let raw_status = s(p, "agent_status");
        let status = if agent.is_some() {
            if raw_status.is_empty() { "unknown".into() } else { raw_status }
        } else {
            "shell".into()
        };
        let title = ["terminal_title_stripped", "label", "terminal_title"]
            .iter()
            .map(|k| s(p, k))
            .find(|t| !t.trim().is_empty())
            .unwrap_or_else(|| "terminal".into());
        let tab_id = s(p, "tab_id");
        let pane = Pane {
            pane_id: s(p, "pane_id"),
            tab_number: *tab_numbers.get(&tab_id).unwrap_or(&0),
            tab_id,
            title,
            agent,
            status,
            cwd: s(p, "cwd"),
            focused: p.get("focused").and_then(Value::as_bool).unwrap_or(false),
        };
        panes_by_ws.entry(s(p, "workspace_id")).or_default().push(pane);
    }

    let mut workspaces: Vec<Workspace> = snap
        .get("workspaces")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .map(|w| {
            let id = s(w, "workspace_id");
            let mut panes = panes_by_ws.remove(&id).unwrap_or_default();
            panes.sort_by_key(|p| (p.tab_number, pane_ordinal(&p.pane_id)));
            Workspace {
                workspace_id: id,
                number: n(w, "number"),
                label: s(w, "label"),
                cwd: panes.first().map(|p| p.cwd.clone()).unwrap_or_default(),
                panes,
            }
        })
        .collect();
    workspaces.sort_by_key(|w| w.number);

    Machine {
        name: name.to_string(),
        remote,
        load: Load::Ready,
        stale: false,
        workspaces,
        focused_workspace: s(snap, "focused_workspace_id"),
        focused_pane: s(snap, "focused_pane_id"),
    }
}

/// "w5:p12" -> 12, for stable ordering inside a tab.
fn pane_ordinal(id: &str) -> u64 {
    id.rsplit(['p', ':']).next().and_then(|x| x.parse().ok()).unwrap_or(0)
}

fn git_branch(cwd: &str) -> Option<String> {
    Command::new("git")
        .args(["-C", cwd, "symbolic-ref", "--short", "-q", "HEAD"])
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .filter(|s| !s.is_empty())
}

// ---------------------------------------------------------------- herdr I/O

fn home() -> String { std::env::var("HOME").unwrap_or_default() }

fn socket_path() -> String {
    std::env::var("HERDR_SOCKET_PATH").unwrap_or_else(|_| {
        let base = std::env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{}/.config", home()));
        format!("{base}/herdr/herdr.sock")
    })
}

fn cache_root() -> PathBuf {
    let base = std::env::var("XDG_CACHE_HOME").unwrap_or_else(|_| format!("{}/.cache", home()));
    PathBuf::from(base).join("herdr")
}

fn cache_dir() -> PathBuf { cache_root().join("goto") }

fn parse_response(line: &str) -> Result<Value, String> {
    let v: Value = serde_json::from_str(line).map_err(|e| format!("json: {e}"))?;
    if let Some(err) = v.get("error") {
        return Err(err.get("message").and_then(Value::as_str).unwrap_or("error").to_string());
    }
    Ok(v.get("result").cloned().unwrap_or(Value::Null))
}

fn socket_call(method: &str, params: Value) -> Result<Value, String> {
    let mut stream = UnixStream::connect(socket_path()).map_err(|e| format!("connect: {e}"))?;
    stream.set_read_timeout(Some(Duration::from_secs(5))).ok();
    let req = json!({"id": "goto", "method": method, "params": params});
    stream.write_all(format!("{req}\n").as_bytes()).map_err(|e| format!("write: {e}"))?;
    let mut line = String::new();
    BufReader::new(stream).read_line(&mut line).map_err(|e| format!("read: {e}"))?;
    parse_response(&line)
}

fn herdr_bin() -> String {
    std::env::var("HERDR_BIN_PATH").unwrap_or_else(|_| "herdr".into())
}

fn herdr_cmd(machine: Option<&str>, args: &[&str]) -> Result<String, String> {
    let mut c = Command::new(herdr_bin());
    if let Some(m) = machine { c.arg("--machine").arg(m); }
    let out = c.args(args).output().map_err(|e| e.to_string())?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(err.lines().next().unwrap_or("failed").to_string());
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn load_local() -> Result<Machine, String> {
    let r = socket_call("session.snapshot", json!({}))?;
    let snap = r.get("snapshot").ok_or("no snapshot in response")?;
    Ok(parse_snapshot(snap, "Local", false))
}

/// `herdr machine list` -> names of enabled saved machines (TSV, name is col 2).
fn list_machines() -> Vec<String> {
    let Ok(out) = herdr_cmd(None, &["machine", "list"]) else { return vec![] };
    out.lines()
        .filter_map(|l| {
            let f: Vec<&str> = l.split('\t').collect();
            let enabled = f.get(4).map_or(true, |e| *e != "disabled");
            (f.len() >= 2 && enabled).then(|| f[1].to_string())
        })
        .collect()
}

/// Fetch a remote snapshot; returns the raw snapshot JSON so it can be cached.
fn fetch_remote_snapshot(name: &str) -> Result<Value, String> {
    let out = herdr_cmd(Some(name), &["api", "snapshot"])?;
    let v: Value = serde_json::from_str(&out).map_err(|e| e.to_string())?;
    v.pointer("/result/snapshot").cloned().ok_or_else(|| "no snapshot".to_string())
}

fn focus_pane(m: &Machine, ws: &Workspace, pane: &Pane) -> Result<(), String> {
    if m.remote {
        herdr_cmd(Some(&m.name), &["workspace", "focus", &ws.workspace_id])?;
        herdr_cmd(Some(&m.name), &["tab", "focus", &pane.tab_id])?;
    } else {
        socket_call("workspace.focus", json!({"workspace_id": ws.workspace_id}))?;
        socket_call("tab.focus", json!({"tab_id": pane.tab_id}))?;
        socket_call("pane.focus", json!({"pane_id": pane.pane_id}))?;
    }
    Ok(())
}

fn focus_workspace(m: &Machine, ws: &Workspace) -> Result<(), String> {
    if m.remote {
        herdr_cmd(Some(&m.name), &["workspace", "focus", &ws.workspace_id])?;
    } else {
        socket_call("workspace.focus", json!({"workspace_id": ws.workspace_id}))?;
    }
    Ok(())
}

/// `worktree.list` for one local workspace -> (repo_key, Repo). Errors (not a
/// git repo, untrusted, ...) are simply skipped.
fn fetch_worktrees(workspace_id: &str) -> Option<(String, Repo)> {
    let r = socket_call("worktree.list", json!({"workspace_id": workspace_id})).ok()?;
    let s = |v: &Value, k: &str| v.get(k).and_then(Value::as_str).unwrap_or("").to_string();
    let src = r.get("source")?;
    let key = s(src, "repo_key");
    if key.is_empty() { return None; }
    let worktrees = r.get("worktrees").and_then(Value::as_array).into_iter().flatten().map(|w| Worktree {
        path: s(w, "path"),
        branch: { let b = s(w, "branch"); if b.is_empty() { "(detached)".into() } else { b } },
        linked: w.get("is_linked_worktree").and_then(Value::as_bool).unwrap_or(false),
        open_ws: w.get("open_workspace_id").and_then(Value::as_str).map(str::to_string),
        prunable: w.get("is_prunable").and_then(Value::as_bool).unwrap_or(false),
    }).collect();
    Some((key, Repo { name: s(src, "repo_name"), worktrees }))
}

/// Open an existing worktree as a (focused) workspace; returns the new
/// workspace id when the server reports it.
fn open_worktree(path: &str) -> Result<Option<String>, String> {
    let r = socket_call("worktree.open", json!({"path": path, "focus": true}))?;
    Ok(["/workspace/workspace_id", "/workspace_id"].iter()
        .find_map(|p| r.pointer(p).and_then(Value::as_str).map(str::to_string)))
}

fn fetch_preview(machine: &str, remote: bool, pane_id: &str, lines: usize) -> Result<String, String> {
    let lines = lines.max(1);
    if remote {
        herdr_cmd(Some(machine), &["pane", "read", pane_id, "--source", "recent", "--lines", &lines.to_string()])
    } else {
        let r = socket_call("pane.read", json!({"pane_id": pane_id, "source": "recent", "lines": lines}))?;
        Ok(r.pointer("/read/text").and_then(Value::as_str).unwrap_or("").to_string())
    }
}

// ---------------------------------------------------------------- recency (MRU)

#[derive(Clone, PartialEq, Eq, Debug)]
struct WsRef { machine: String, ws: String }

fn recency_path() -> PathBuf { cache_dir().join("recency") }

fn load_recency() -> Vec<WsRef> {
    fs::read_to_string(recency_path()).unwrap_or_default()
        .lines()
        .filter_map(|l| {
            let (m, w) = l.split_once('\t')?;
            Some(WsRef { machine: m.to_string(), ws: w.to_string() })
        })
        .collect()
}

/// Move `r` to the top of the recency log (dedup, capped) and persist it.
fn stamp_recency(list: &mut Vec<WsRef>, r: WsRef) {
    list.retain(|x| *x != r);
    list.insert(0, r.clone());
    list.truncate(RECENCY_MAX);
    if fs::create_dir_all(cache_dir()).is_ok() {
        let body: String = list.iter().map(|x| format!("{}\t{}\n", x.machine, x.ws)).collect();
        let _ = fs::write(recency_path(), body);
    }
    // keep the fzf switcher script's log in step for local workspaces
    if r.machine == "Local" {
        let p = cache_root().join("workspace-recency");
        let mut ids: Vec<String> = fs::read_to_string(&p).unwrap_or_default()
            .lines().filter(|l| !l.is_empty() && *l != r.ws).map(str::to_string).collect();
        ids.insert(0, r.ws.clone());
        ids.truncate(RECENCY_MAX);
        let _ = fs::write(&p, ids.join("\n") + "\n");
    }
}

fn prefs_path() -> PathBuf { cache_dir().join("preview") }
fn filter_path() -> PathBuf { cache_dir().join("filter") }
fn load_filter_pref() -> Filter {
    fs::read_to_string(filter_path()).ok().and_then(|s| Filter::from_label(s.trim())).unwrap_or(Filter::All)
}
fn save_filter_pref(f: Filter) {
    if fs::create_dir_all(cache_dir()).is_ok() { let _ = fs::write(filter_path(), format!("{}\n", f.label())); }
}
fn load_preview_pref() -> bool { fs::read_to_string(prefs_path()).map(|s| s.trim() == "1").unwrap_or(false) }
fn save_preview_pref(on: bool) {
    if fs::create_dir_all(cache_dir()).is_ok() { let _ = fs::write(prefs_path(), if on { "1\n" } else { "0\n" }); }
}

// ---------------------------------------------------------------- background workers

enum Msg {
    Local(Machine),
    Remote { name: String, result: Result<Machine, String>, stale: bool },
    Branches(HashMap<String, Option<String>>),
    Live(bool),
    Preview { key: String, text: Result<String, String> },
    Worktrees { repos: HashMap<String, Repo>, ws_repo: HashMap<String, String> },
}

/// (workspace_id, cwd) of every local workspace, sent after each local snapshot.
type WtReq = Vec<(String, String)>;

struct PreviewReq { key: String, machine: String, remote: bool, pane_id: String, lines: usize }

/// Keeps the local tree live: subscribe to structural events plus per-pane
/// agent-status events, re-fetch the snapshot on each event, and poll slowly as
/// a safety net. Reconnects (with a fresh pane list) whenever panes come or go.
fn local_watcher(tx: mpsc::Sender<Msg>) {
    const STRUCTURAL: &[&str] = &[
        "workspace.created", "workspace.updated", "workspace.renamed", "workspace.moved",
        "workspace.reordered", "workspace.closed", "workspace.focused", "workspace.metadata_updated",
        "tab.created", "tab.closed", "tab.focused", "tab.renamed", "tab.moved",
        "pane.created", "pane.closed", "pane.updated", "pane.focused", "pane.moved",
        "pane.exited", "pane.agent_detected",
    ];
    let mut pane_ids: Vec<String> = vec![];
    loop {
        let subs: Vec<Value> = STRUCTURAL
            .iter()
            .map(|t| json!({"type": t}))
            .chain(pane_ids.iter().map(|id| json!({"type": "pane.agent_status_changed", "pane_id": id})))
            .collect();
        let conn = UnixStream::connect(socket_path()).ok().and_then(|mut s| {
            let req = json!({"id": "goto-sub", "method": "events.subscribe", "params": {"subscriptions": subs}});
            s.write_all(format!("{req}\n").as_bytes()).ok()?;
            s.set_read_timeout(Some(Duration::from_millis(250))).ok();
            let mut r = BufReader::new(s);
            let mut line = String::new();
            r.read_line(&mut line).ok()?;
            parse_response(&line).ok().map(|_| r)
        });
        let Some(mut reader) = conn else {
            let _ = tx.send(Msg::Live(false));
            thread::sleep(Duration::from_secs(1));
            if let Ok(m) = load_local() {
                pane_ids = m.pane_ids();
                if tx.send(Msg::Local(m)).is_err() { return; }
            }
            continue;
        };
        let _ = tx.send(Msg::Live(true));

        let mut last = Instant::now();
        let mut dirty = true; // refresh right after (re)subscribing
        let mut resubscribe = false;
        loop {
            let mut line = String::new();
            match reader.read_line(&mut line) {
                Ok(0) => break, // server closed the stream: reconnect
                Ok(_) => {
                    dirty = true;
                    let ev = serde_json::from_str::<Value>(&line).ok();
                    let kind = ev.as_ref().and_then(|v| v.get("event")).and_then(Value::as_str).unwrap_or("");
                    if matches!(kind, "pane_created" | "pane_closed" | "pane_agent_detected" | "workspace_closed") {
                        resubscribe = true;
                    }
                    thread::sleep(Duration::from_millis(40)); // coalesce bursts
                    continue;
                }
                Err(e) if matches!(e.kind(), io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut) => {}
                Err(_) => break,
            }
            if dirty || last.elapsed() > LOCAL_FALLBACK_POLL {
                match load_local() {
                    Ok(m) => {
                        let ids = m.pane_ids();
                        if ids != pane_ids { pane_ids = ids; resubscribe = true; }
                        if tx.send(Msg::Local(m)).is_err() { return; }
                    }
                    Err(_) => break,
                }
                last = Instant::now();
                dirty = false;
                if resubscribe { break; }
            }
        }
    }
}

/// One per saved machine: cached snapshot first, then live fetches on a timer.
fn remote_watcher(name: String, tx: mpsc::Sender<Msg>) {
    let cache = cache_dir().join(format!("{name}.json"));
    if let Ok(bytes) = fs::read(&cache) {
        if let Ok(snap) = serde_json::from_slice::<Value>(&bytes) {
            let mut m = parse_snapshot(&snap, &name, true);
            m.stale = true;
            if tx.send(Msg::Remote { name: name.clone(), result: Ok(m), stale: true }).is_err() { return; }
        }
    }
    loop {
        let result = fetch_remote_snapshot(&name).map(|snap| {
            if fs::create_dir_all(cache_dir()).is_ok() {
                let tmp = cache.with_extension("json.tmp");
                if fs::write(&tmp, snap.to_string()).is_ok() { let _ = fs::rename(&tmp, &cache); }
            }
            parse_snapshot(&snap, &name, true)
        });
        if tx.send(Msg::Remote { name: name.clone(), result, stale: false }).is_err() { return; }
        thread::sleep(REMOTE_POLL);
    }
}

/// Resolves worktrees for local repos. One `worktree.list` per distinct cwd;
/// re-runs only when the workspace set changes or every 10s (external
/// `git worktree add` shows up on the next pass).
fn worktree_worker(rx: mpsc::Receiver<WtReq>, tx: mpsc::Sender<Msg>) {
    let mut last_cwds: Vec<String> = vec![];
    let mut last_at: Option<Instant> = None;
    while let Ok(mut req) = rx.recv() {
        while let Ok(newer) = rx.try_recv() { req = newer; }
        let mut by_cwd: HashMap<String, String> = HashMap::new(); // cwd -> one ws id
        for (ws, cwd) in &req { if !cwd.is_empty() { by_cwd.entry(cwd.clone()).or_insert_with(|| ws.clone()); } }
        let mut cwds: Vec<String> = by_cwd.keys().cloned().collect();
        cwds.sort();
        if cwds == last_cwds && last_at.map_or(false, |t| t.elapsed() < REMOTE_POLL) { continue; }
        let mut repos: HashMap<String, Repo> = HashMap::new();
        let mut ws_repo: HashMap<String, String> = HashMap::new();
        let mut cwd_repo: HashMap<String, String> = HashMap::new();
        for (cwd, ws) in &by_cwd {
            if let Some((key, repo)) = fetch_worktrees(ws) {
                cwd_repo.insert(cwd.clone(), key.clone());
                repos.insert(key, repo);
            }
        }
        for (ws, cwd) in &req { if let Some(k) = cwd_repo.get(cwd) { ws_repo.insert(ws.clone(), k.clone()); } }
        last_cwds = cwds;
        last_at = Some(Instant::now());
        if tx.send(Msg::Worktrees { repos, ws_repo }).is_err() { return; }
    }
}

/// Serves preview requests; always works on the newest request only.
fn preview_worker(rx: mpsc::Receiver<PreviewReq>, tx: mpsc::Sender<Msg>) {
    while let Ok(mut req) = rx.recv() {
        while let Ok(newer) = rx.try_recv() { req = newer; }
        let text = fetch_preview(&req.machine, req.remote, &req.pane_id, req.lines);
        if tx.send(Msg::Preview { key: req.key, text }).is_err() { return; }
    }
}

// ---------------------------------------------------------------- view model

#[derive(Clone, Copy, PartialEq, Eq)]
enum Filter { All, Blocked, Working, Idle, Done }

impl Filter {
    fn label(self) -> &'static str {
        match self {
            Filter::All => "all",
            Filter::Blocked => "blocked",
            Filter::Working => "working",
            Filter::Idle => "idle",
            Filter::Done => "done",
        }
    }
    fn from_label(s: &str) -> Option<Filter> {
        [Filter::All, Filter::Blocked, Filter::Working, Filter::Idle, Filter::Done].into_iter().find(|f| f.label() == s)
    }
    fn accepts(self, p: &Pane) -> bool {
        match self {
            Filter::All => true,
            Filter::Blocked => p.status == "blocked",
            Filter::Working => p.status == "working",
            Filter::Idle => p.status == "idle",
            Filter::Done => p.status == "done",
        }
    }
}

#[derive(Clone)]
enum Row {
    Machine { m: usize, collapsed: bool },
    Workspace { m: usize, w: usize, collapsed: bool, shown: usize },
    /// `last`: last pane in its workspace (tree glyph). `hits`: matched char
    /// indices into the search label (flat search mode only).
    Pane { m: usize, w: usize, p: usize, last: bool, hits: Vec<usize> },
    /// A worktree of workspace `w`'s repo that herdr has not opened yet.
    Worktree { m: usize, w: usize, repo: String, i: usize, last: bool, hits: Vec<usize> },
}

/// "gx10 · QM › " / "QM › " — context shown before the title in search mode;
/// the fuzzy match runs over prefix + title so workspace names count too.
fn pane_prefix(m: &Machine, w: &Workspace) -> String {
    if m.remote { format!("{} · {} › ", m.name, w.label) } else { format!("{} › ", w.label) }
}

struct Preview {
    on: bool,
    cache: HashMap<String, (Instant, Result<String, String>)>,
    sent: Option<(String, Instant)>,
    changed_at: Instant,
    lines: usize,
}

struct App {
    machines: Vec<Machine>,
    branches: HashMap<String, Option<String>>, // cwd -> branch
    branches_pending: HashSet<String>,
    matcher: SkimMatcherV2,
    live: bool,
    query: String,
    searching: bool,  // insert (search) mode vs normal mode
    help: bool,       // `?` overlay
    pending: Option<char>, // first key of `gg` / `z?`
    page_rows: usize, // visible rows in the tree, set by draw()
    filter: Filter,
    collapsed: HashSet<String>, // row keys of folded machines / workspaces
    rows: Vec<Row>,
    selected: Option<usize>,
    table: TableState,
    message: Option<String>,
    recency: Vec<WsRef>,
    alternate: Option<WsRef>, // the "last" workspace for ' / Tab
    initial_pending: bool,    // alternate not visible yet (machine still loading)
    user_moved: bool,         // cursor touched by the user; stop auto-placement
    preview: Preview,
    repos: HashMap<String, Repo>,       // repo_key -> worktrees
    ws_repo: HashMap<String, String>,   // local workspace id -> repo_key
    wtx: mpsc::Sender<WtReq>,
}

impl App {
    fn worktree(&self, repo: &str, i: usize) -> &Worktree { &self.repos[repo].worktrees[i] }

    /// The worktree entry backing a local workspace, if it is a linked worktree.
    fn linked_worktree_of(&self, m: &Machine, w: &Workspace) -> Option<&Worktree> {
        if m.remote { return None; }
        let repo = self.repos.get(self.ws_repo.get(&w.workspace_id)?)?;
        repo.worktrees.iter().find(|t| t.linked && t.open_ws.as_deref() == Some(&w.workspace_id))
    }

    /// Closed worktrees to list under workspace (m, w): only under the first
    /// workspace of that repo, so each worktree shows once.
    fn closed_worktrees_for(&self, m: usize, w: usize) -> Option<(String, Vec<usize>)> {
        let machine = &self.machines[m];
        if machine.remote { return None; }
        let key = self.ws_repo.get(&machine.workspaces[w].workspace_id)?;
        let first = machine.workspaces.iter().position(|x| self.ws_repo.get(&x.workspace_id) == Some(key))?;
        if first != w { return None; }
        let idx: Vec<usize> = self.repos.get(key)?.worktrees.iter().enumerate()
            .filter(|(_, t)| t.open_ws.is_none())
            .map(|(i, _)| i).collect();
        (!idx.is_empty()).then(|| (key.clone(), idx))
    }

    /// Status filter is remembered across launches (~/.cache/herdr/goto/filter).
    fn set_filter(&mut self, f: Filter) {
        self.filter = f;
        save_filter_pref(f);
        self.rebuild();
    }

    fn request_worktrees(&self) {
        let req: WtReq = self.machines.iter().filter(|m| !m.remote)
            .flat_map(|m| m.workspaces.iter().map(|w| (w.workspace_id.clone(), w.cwd.clone())))
            .collect();
        let _ = self.wtx.send(req);
    }

    // ---- keys identifying rows across rebuilds
    fn machine_key(&self, m: usize) -> String { format!("m:{}", self.machines[m].name) }
    fn ws_key(&self, m: usize, w: usize) -> String {
        format!("w:{}/{}", self.machines[m].name, self.machines[m].workspaces[w].workspace_id)
    }
    fn row_key(&self, r: &Row) -> String {
        match r {
            Row::Machine { m, .. } => self.machine_key(*m),
            Row::Workspace { m, w, .. } => self.ws_key(*m, *w),
            Row::Pane { m, w, p, .. } => {
                format!("p:{}/{}", self.machines[*m].name, self.machines[*m].workspaces[*w].panes[*p].pane_id)
            }
            Row::Worktree { repo, i, .. } => format!("t:{}/{}", repo, self.worktree(repo, *i).path),
        }
    }

    fn rebuild(&mut self) {
        let prev = self.selected.and_then(|i| self.rows.get(i)).map(|r| self.row_key(r));
        self.rows = if self.query.is_empty() { self.tree_rows() } else { self.search_rows() };
        self.selected = prev
            .and_then(|k| self.rows.iter().position(|r| self.row_key(r) == k))
            .or_else(|| (!self.rows.is_empty()).then_some(0));
        self.table.select(self.selected);
    }

    /// Normal view: machine > workspace > pane, filtered by status, foldable.
    fn tree_rows(&self) -> Vec<Row> {
        let mut rows = vec![];
        for (mi, m) in self.machines.iter().enumerate() {
            let m_collapsed = self.collapsed.contains(&self.machine_key(mi));
            let mut ws_rows: Vec<Row> = vec![];
            for (wi, w) in m.workspaces.iter().enumerate() {
                let visible: Vec<usize> = w.panes.iter().enumerate()
                    .filter(|(_, p)| self.filter.accepts(p))
                    .map(|(i, _)| i)
                    .collect();
                if visible.is_empty() && self.filter != Filter::All { continue; }
                let collapsed = self.collapsed.contains(&self.ws_key(mi, wi));
                ws_rows.push(Row::Workspace { m: mi, w: wi, collapsed, shown: visible.len() });
                if collapsed { continue; }
                let closed = if self.filter == Filter::All { self.closed_worktrees_for(mi, wi) } else { None };
                let n = visible.len();
                for (k, pi) in visible.into_iter().enumerate() {
                    ws_rows.push(Row::Pane { m: mi, w: wi, p: pi, last: k + 1 == n && closed.is_none(), hits: vec![] });
                }
                if let Some((repo, idx)) = closed {
                    let n = idx.len();
                    for (k, i) in idx.into_iter().enumerate() {
                        ws_rows.push(Row::Worktree { m: mi, w: wi, repo: repo.clone(), i, last: k + 1 == n, hits: vec![] });
                    }
                }
            }
            if !ws_rows.is_empty() || self.filter == Filter::All || !matches!(m.load, Load::Ready) {
                rows.push(Row::Machine { m: mi, collapsed: m_collapsed });
                if !m_collapsed { rows.extend(ws_rows); }
            }
        }
        rows
    }

    /// Search view: a flat list of panes ranked by fuzzy score. The label the
    /// user sees (workspace › title) is what gets matched, so highlights line
    /// up; agent kind / status are a secondary, unhighlighted match.
    fn search_rows(&self) -> Vec<Row> {
        let q = self.query.as_str();
        let mut hits: Vec<(i64, usize, Row)> = vec![];
        for (mi, m) in self.machines.iter().enumerate() {
            for (wi, w) in m.workspaces.iter().enumerate() {
                for (pi, p) in w.panes.iter().enumerate() {
                    if !self.filter.accepts(p) { continue; }
                    let label = format!("{}{}", pane_prefix(m, w), p.title);
                    let scored = self.matcher.fuzzy_indices(&label, q).or_else(|| {
                        let meta = format!("{} {}", p.agent.as_deref().unwrap_or("terminal"), p.status);
                        self.matcher.fuzzy_match(&meta, q).map(|s| (s / 2, vec![]))
                    });
                    if let Some((score, idx)) = scored {
                        let order = hits.len();
                        hits.push((score, order, Row::Pane { m: mi, w: wi, p: pi, last: true, hits: idx }));
                    }
                }
                if let Some((repo, idx)) = self.closed_worktrees_for(mi, wi) {
                    for i in idx {
                        let t = self.worktree(&repo, i);
                        let label = format!("{}⎇ {}", pane_prefix(m, w), t.branch);
                        if let Some((score, h)) = self.matcher.fuzzy_indices(&label, q) {
                            let order = hits.len();
                            hits.push((score, order, Row::Worktree { m: mi, w: wi, repo: repo.clone(), i, last: true, hits: h }));
                        }
                    }
                }
            }
        }
        hits.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
        hits.into_iter().map(|(_, _, r)| r).collect()
    }

    // ---- selection helpers
    fn select(&mut self, i: Option<usize>) {
        self.selected = i.filter(|&i| i < self.rows.len());
        self.table.select(self.selected);
    }

    fn position_of_key(&self, key: &str) -> Option<usize> {
        self.rows.iter().position(|r| self.row_key(r) == key)
    }

    /// Row of the pane currently focused in the local herdr session.
    fn focused_pane_row(&self) -> Option<usize> {
        let local = self.machines.iter().find(|m| !m.remote)?;
        self.position_of_key(&format!("p:{}/{}", local.name, local.focused_pane))
    }

    /// First row belonging to workspace `r`: its first pane, or the header if
    /// folded / empty.
    fn workspace_entry_row(&self, r: &WsRef) -> Option<usize> {
        let (mi, m) = self.machines.iter().enumerate().find(|(_, m)| m.name == r.machine)?;
        let wi = m.workspaces.iter().position(|w| w.workspace_id == r.ws)?;
        let header = self.position_of_key(&self.ws_key(mi, wi))?;
        match self.rows.get(header + 1) {
            Some(Row::Pane { m: pm, w: pw, .. }) if *pm == mi && *pw == wi => Some(header + 1),
            _ => Some(header),
        }
    }

    /// Land on the last-used workspace, or on the focused pane until that
    /// workspace's machine has loaded (retried from `apply`).
    fn select_initial(&mut self) {
        if self.user_moved { self.initial_pending = false; return; }
        let alt = self.alternate.clone().and_then(|a| self.workspace_entry_row(&a));
        self.initial_pending = alt.is_none() && self.alternate.as_ref().map_or(false, |a| {
            self.machines.iter().any(|m| m.name == a.machine && !matches!(m.load, Load::Failed(_)))
        });
        let i = alt.or_else(|| self.focused_pane_row());
        if i.is_some() { self.select(i); }
    }

    /// ' / Tab: bounce between the last-used workspace and where focus is now.
    fn jump_alternate(&mut self) {
        let Some(alt) = self.alternate.clone() else { self.message = Some("no previous workspace".into()); return; };
        let in_alt = matches!(self.current_ws(), Some(r) if r == alt);
        let target = if in_alt { self.focused_pane_row() } else { self.workspace_entry_row(&alt) };
        match target {
            Some(i) => self.select(Some(i)),
            None => self.message = Some("previous workspace is not visible".into()),
        }
    }

    fn move_sel(&mut self, delta: i32) {
        if self.rows.is_empty() { self.select(None); return; }
        let len = self.rows.len() as i32;
        let cur = self.selected.unwrap_or(0) as i32;
        self.select(Some((((cur + delta) % len + len) % len) as usize));
    }

    fn page(&mut self, delta: i32) {
        if self.rows.is_empty() { return; }
        let cur = self.selected.unwrap_or(0) as i32;
        self.select(Some((cur + delta).clamp(0, self.rows.len() as i32 - 1) as usize));
    }

    /// H / M / L: top, middle, bottom of the visible viewport.
    fn select_viewport(&mut self, which: char) {
        if self.rows.is_empty() { return; }
        let top = self.table.offset();
        let bottom = (top + self.page_rows).saturating_sub(1).min(self.rows.len() - 1);
        self.select(Some(match which { 'H' => top, 'L' => bottom, _ => (top + bottom) / 2 }));
    }

    fn select_edge(&mut self, first: bool) {
        if self.rows.is_empty() { return; }
        self.select(Some(if first { 0 } else { self.rows.len() - 1 }));
    }

    /// [ / ]: previous / next workspace header.
    fn move_workspace(&mut self, delta: i32) {
        let ws_rows: Vec<usize> = self.rows.iter().enumerate()
            .filter(|(_, r)| matches!(r, Row::Workspace { .. }))
            .map(|(i, _)| i).collect();
        if ws_rows.is_empty() { return; }
        let sel = self.selected.unwrap_or(0);
        let next = if delta > 0 {
            ws_rows.iter().copied().find(|&i| i > sel).unwrap_or(ws_rows[0])
        } else {
            ws_rows.iter().copied().filter(|&i| i < sel).last().unwrap_or(*ws_rows.last().unwrap())
        };
        self.select(Some(next));
    }

    // ---- folding
    fn toggle_fold(&mut self, key: String) {
        if !self.collapsed.remove(&key) { self.collapsed.insert(key); }
        self.rebuild();
    }

    fn fold_key_at(&self, i: usize) -> Option<String> {
        match self.rows.get(i)? {
            Row::Machine { m, .. } => Some(self.machine_key(*m)),
            Row::Workspace { m, w, .. } | Row::Pane { m, w, .. } | Row::Worktree { m, w, .. } => Some(self.ws_key(*m, *w)),
        }
    }

    /// h: pane -> its workspace header; open header -> fold; folded workspace
    /// -> its machine row.
    fn tree_left(&mut self) {
        let Some(i) = self.selected else { return };
        match self.rows[i].clone() {
            Row::Pane { m, w, .. } | Row::Worktree { m, w, .. } => { let k = self.ws_key(m, w); self.select(self.position_of_key(&k)); }
            Row::Workspace { m, w, collapsed: false, .. } => self.toggle_fold(self.ws_key(m, w)),
            Row::Workspace { m, collapsed: true, .. } => { let k = self.machine_key(m); self.select(self.position_of_key(&k)); }
            Row::Machine { m, collapsed: false } => self.toggle_fold(self.machine_key(m)),
            Row::Machine { .. } => {}
        }
    }

    /// l: folded header -> unfold; open header -> first child.
    fn tree_right(&mut self) {
        let Some(i) = self.selected else { return };
        match self.rows[i].clone() {
            Row::Workspace { m, w, collapsed: true, .. } => self.toggle_fold(self.ws_key(m, w)),
            Row::Machine { m, collapsed: true } => self.toggle_fold(self.machine_key(m)),
            Row::Workspace { .. } | Row::Machine { .. } => { if i + 1 < self.rows.len() { self.select(Some(i + 1)); } }
            Row::Pane { .. } | Row::Worktree { .. } => {}
        }
    }

    fn fold_all(&mut self, collapse: bool) {
        self.collapsed.clear();
        if collapse {
            for (mi, m) in self.machines.iter().enumerate() {
                for wi in 0..m.workspaces.len() { self.collapsed.insert(self.ws_key(mi, wi)); }
            }
        }
        // land on the workspace header of whatever was selected
        let key = self.selected.and_then(|i| self.fold_key_at(i));
        self.rebuild();
        if let Some(k) = key { if let Some(i) = self.position_of_key(&k) { self.select(Some(i)); } }
    }

    fn z_command(&mut self, c: char) {
        let Some(i) = self.selected else { return };
        match c {
            'a' | 'o' | 'c' => {
                let Some(k) = self.fold_key_at(i) else { return };
                let is_closed = self.collapsed.contains(&k);
                match c {
                    'a' => self.toggle_fold(k.clone()),
                    'o' if is_closed => self.toggle_fold(k.clone()),
                    'c' if !is_closed => self.toggle_fold(k.clone()),
                    _ => return,
                }
                if let Some(j) = self.position_of_key(&k) { if matches!(self.rows[j], Row::Workspace { collapsed: true, .. } | Row::Machine { collapsed: true, .. }) { self.select(Some(j)); } }
            }
            'M' => self.fold_all(true),
            'R' => self.fold_all(false),
            _ => {}
        }
    }

    // ---- current selection
    fn current_pane(&self) -> Option<(&Machine, &Workspace, &Pane)> {
        match self.selected.and_then(|i| self.rows.get(i)) {
            Some(Row::Pane { m, w, p, .. }) => {
                let m = &self.machines[*m];
                let w = &m.workspaces[*w];
                Some((m, w, &w.panes[*p]))
            }
            _ => None,
        }
    }

    fn current_ws(&self) -> Option<WsRef> {
        match self.selected.and_then(|i| self.rows.get(i))? {
            Row::Workspace { m, w, .. } | Row::Pane { m, w, .. } | Row::Worktree { m, w, .. } => Some(WsRef {
                machine: self.machines[*m].name.clone(),
                ws: self.machines[*m].workspaces[*w].workspace_id.clone(),
            }),
            Row::Machine { .. } => None,
        }
    }

    fn total_panes(&self) -> usize {
        self.machines.iter().map(Machine::pane_count).sum()
    }

    // ---- background plumbing
    fn request_branches(&mut self, tx: &mpsc::Sender<Msg>) {
        let todo: Vec<String> = self.machines.iter()
            .filter(|m| !m.remote)
            .flat_map(|m| m.workspaces.iter().map(|w| w.cwd.clone()))
            .filter(|c| !c.is_empty() && !self.branches.contains_key(c) && !self.branches_pending.contains(c))
            .collect::<HashSet<_>>()
            .into_iter()
            .collect();
        if todo.is_empty() { return; }
        self.branches_pending.extend(todo.iter().cloned());
        let tx = tx.clone();
        thread::spawn(move || {
            let map: HashMap<String, Option<String>> = todo.into_iter().map(|c| { let b = git_branch(&c); (c, b) }).collect();
            let _ = tx.send(Msg::Branches(map));
        });
    }

    /// Ask the preview worker for the selected pane when the selection changed
    /// (debounced) or the cached text is getting old.
    fn pump_preview(&mut self, ptx: &mpsc::Sender<PreviewReq>) {
        if !self.preview.on { return; }
        let Some((m, _, p)) = self.current_pane() else { return };
        let key = format!("{}/{}", m.name, p.pane_id);
        let req = PreviewReq { key: key.clone(), machine: m.name.clone(), remote: m.remote, pane_id: p.pane_id.clone(), lines: self.preview.lines };
        let fresh_enough = self.preview.cache.get(&key).map_or(false, |(t, _)| t.elapsed() < PREVIEW_REFRESH);
        let already_sent = self.preview.sent.as_ref().map_or(false, |(k, t)| *k == key && t.elapsed() < PREVIEW_REFRESH);
        if already_sent || fresh_enough { return; }
        if self.preview.changed_at.elapsed() < PREVIEW_DEBOUNCE && !self.preview.cache.contains_key(&key) { return; }
        let _ = ptx.send(req);
        self.preview.sent = Some((key, Instant::now()));
    }

    fn apply(&mut self, msg: Msg, tx: &mpsc::Sender<Msg>) {
        match msg {
            Msg::Local(m) => {
                if let Some(slot) = self.machines.iter_mut().find(|x| !x.remote) { *slot = m; }
                self.request_branches(tx);
                self.request_worktrees();
                self.rebuild();
            }
            Msg::Remote { name, result, stale } => {
                if let Some(slot) = self.machines.iter_mut().find(|x| x.name == name) {
                    match result {
                        // never let a cached snapshot overwrite live data
                        Ok(_) if stale && !slot.stale && matches!(slot.load, Load::Ready) => {}
                        Ok(m) => *slot = m,
                        Err(e) => slot.load = Load::Failed(e),
                    }
                }
                self.rebuild();
                if self.initial_pending { self.select_initial(); }
            }
            Msg::Branches(map) => {
                for k in map.keys() { self.branches_pending.remove(k); }
                self.branches.extend(map);
            }
            Msg::Live(on) => self.live = on,
            Msg::Preview { key, text } => { self.preview.cache.insert(key, (Instant::now(), text)); }
            Msg::Worktrees { repos, ws_repo } => { self.repos = repos; self.ws_repo = ws_repo; self.rebuild(); }
        }
    }
}

// ---------------------------------------------------------------- rendering

fn status_style(status: &str) -> Style {
    match status {
        "working" => Style::new().fg(Color::Yellow),
        "blocked" => Style::new().fg(Color::Red).bold(),
        "done" => Style::new().fg(Color::Green),
        _ => Style::new().fg(Color::DarkGray),
    }
}

/// Render `text` char by char, highlighting the chars whose index is in `hits`.
/// Chars before `prefix_chars` get the dim style (search-mode context).
fn highlighted(text: &str, hits: &[usize], prefix_chars: usize, base: Style, dim: Style) -> Vec<Span<'static>> {
    let hl = Style::new().fg(Color::Cyan).bold();
    let mut spans: Vec<Span> = vec![];
    let mut buf = String::new();
    let mut cur: Option<Style> = None;
    for (i, ch) in text.chars().enumerate() {
        let st = if hits.binary_search(&i).is_ok() { hl } else if i < prefix_chars { dim } else { base };
        if cur != Some(st) {
            if let Some(c) = cur { if !buf.is_empty() { spans.push(Span::styled(std::mem::take(&mut buf), c)); } }
            cur = Some(st);
        }
        buf.push(ch);
    }
    if let (Some(c), false) = (cur, buf.is_empty()) { spans.push(Span::styled(buf, c)); }
    spans
}

/// Worst agent status in a workspace, for folded headers.
fn summary_status(panes: &[Pane]) -> Option<&str> {
    ["blocked", "working", "done", "idle"].into_iter().find(|s| panes.iter().any(|p| p.status == *s))
}

fn draw(f: &mut Frame, app: &mut App) {
    // no frame: a one-cell blank margin all around instead of a titled border
    let inner = f.area().inner(Margin::new(1, 1));

    let chunks = Layout::vertical([
        Constraint::Length(1), // search
        Constraint::Length(1), // spacer
        Constraint::Min(1),    // tree (+ preview)
        Constraint::Length(3), // status + cwd + help
    ])
    .split(inner);

    let (tree_area, preview_area) = if app.preview.on && inner.width >= 80 {
        let h = Layout::horizontal([Constraint::Percentage(55), Constraint::Percentage(45)]).split(chunks[2]);
        (h[0], Some(h[1]))
    } else {
        (chunks[2], None)
    };
    app.page_rows = tree_area.height.max(1) as usize;
    app.preview.lines = preview_area.map_or(0, |a| a.height.saturating_sub(2).max(1) as usize);

    let dim = Style::new().fg(Color::DarkGray);

    // --- search line
    let live = if app.live { Span::styled("● live  ", Style::new().fg(Color::Green)) } else { Span::styled("○ polling  ", dim) };
    let count = Span::styled(format!("{} terminals", app.total_panes()), dim);
    let right = Line::from(vec![live, count]).alignment(Alignment::Right);
    let right_w = right.width() as u16 + 1;
    let filter_tag = if app.filter == Filter::All { String::new() } else { format!("[{}] ", app.filter.label()) };
    let search_spans = if app.searching || !app.query.is_empty() {
        vec![
            Span::styled("/ ", dim),
            Span::styled(filter_tag, Style::new().fg(Color::Magenta)),
            Span::raw(app.query.clone()),
            Span::styled(if app.searching { "▏" } else { "" }, Style::new().fg(Color::Gray)),
        ]
    } else {
        vec![
            Span::styled("/ ", dim),
            Span::styled(filter_tag, Style::new().fg(Color::Magenta)),
            Span::styled("search agents and terminals", dim),
        ]
    };
    let srow = Layout::horizontal([Constraint::Min(1), Constraint::Length(right_w)]).split(chunks[0]);
    f.render_widget(Paragraph::new(Line::from(search_spans)), srow[0]);
    f.render_widget(Paragraph::new(right), srow[1]);

    // --- tree / search list
    let searching_view = !app.query.is_empty();
    let alt = app.alternate.clone();
    let rows: Vec<TRow> = app
        .rows
        .iter()
        .map(|r| match r {
            Row::Machine { m: mi, collapsed } => {
                let m = &app.machines[*mi];
                let right = match (&m.load, m.remote, m.stale) {
                    (Load::Loading, _, _) => Span::styled("…", dim),
                    (Load::Failed(e), _, true) => Span::styled(format!("offline · cached  ({e})"), Style::new().fg(Color::Red)),
                    (Load::Failed(e), _, false) => Span::styled(format!("offline · {e}"), Style::new().fg(Color::Red)),
                    (Load::Ready, true, true) => Span::styled("◌ cached", dim),
                    (Load::Ready, true, false) => Span::styled("●", Style::new().fg(Color::Green)),
                    (Load::Ready, false, _) => Span::raw(""),
                };
                let arrow = if *collapsed { "▸ " } else { "▾ " };
                let name = Line::from(vec![
                    Span::styled(arrow, dim),
                    Span::styled(m.name.clone(), Style::new().bold()),
                    Span::styled(if *collapsed { format!("  ({} ws)", m.workspaces.len()) } else { String::new() }, dim),
                ]);
                TRow::new(vec![Cell::from(name), Cell::from(""), Cell::from(Line::from(right).alignment(Alignment::Right))])
            }
            Row::Workspace { m: mi, w: wi, collapsed, shown } => {
                let m = &app.machines[*mi];
                let w = &m.workspaces[*wi];
                let is_alt = alt.as_ref().map_or(false, |a| a.machine == m.name && a.ws == w.workspace_id);
                let is_focused = !m.remote && m.focused_workspace == w.workspace_id;
                let mut branch = app.branches.get(&w.cwd).cloned().flatten().unwrap_or_default();
                let linked = app.linked_worktree_of(m, w);
                if let Some(t) = linked { if branch.is_empty() { branch = t.branch.clone(); } branch = format!("⎇ {branch}"); }
                let arrow = if *collapsed { "▸ " } else { "▾ " };
                let mut name = vec![
                    Span::styled(format!("  {arrow}"), dim),
                    Span::styled(w.label.clone(), Style::new().bold()),
                ];
                if is_focused { name.push(Span::styled(" ●", Style::new().fg(Color::Green))); }
                if is_alt { name.push(Span::styled(" '", Style::new().fg(Color::Magenta))); }
                if *collapsed {
                    name.push(Span::styled(format!("  ({shown})"), dim));
                }
                let mid = if *collapsed {
                    summary_status(&w.panes).map(|s| Span::styled(s.to_string(), status_style(s))).unwrap_or_default()
                } else { Span::raw("") };
                TRow::new(vec![
                    Cell::from(Line::from(name)),
                    Cell::from(mid),
                    Cell::from(Line::from(Span::styled(branch, Style::new().bold())).alignment(Alignment::Right)),
                ])
            }
            Row::Pane { m, w, p, last, hits } => {
                let machine = &app.machines[*m];
                let ws = &machine.workspaces[*w];
                let pane = &ws.panes[*p];
                let (icon, icon_style) = if pane.agent.is_some() {
                    ("○", Style::new().fg(if pane.status == "working" { Color::Yellow } else { Color::Green }))
                } else {
                    ("·", dim)
                };
                let title_style = if pane.focused { Style::new().bold() } else { Style::new() };
                let mut spans = vec![];
                if searching_view {
                    let prefix = pane_prefix(machine, ws);
                    spans.push(Span::styled(icon, icon_style));
                    spans.push(Span::raw(" "));
                    let label = format!("{prefix}{}", pane.title);
                    spans.extend(highlighted(&label, hits, prefix.chars().count(), title_style, dim));
                } else {
                    let glyph = if *last { "└─" } else { "├─" };
                    spans.push(Span::styled(format!("    {glyph} "), dim));
                    spans.push(Span::styled(icon, icon_style));
                    spans.push(Span::raw(" "));
                    spans.push(Span::styled(pane.title.clone(), title_style));
                }
                spans.push(Span::styled(format!(" · {}", pane.tab_number), dim));
                let kind = pane.agent.clone().unwrap_or_else(|| "terminal".into());
                let kind_style = if pane.agent.is_some() { Style::new() } else { dim };
                TRow::new(vec![
                    Cell::from(Line::from(spans)),
                    Cell::from(Span::styled(kind, kind_style)),
                    Cell::from(Span::styled(pane.status.clone(), status_style(&pane.status))),
                ])
            }
            Row::Worktree { m, w, repo, i, last, hits } => {
                let t = app.worktree(repo, *i);
                let (machine, ws) = (&app.machines[*m], &app.machines[*m].workspaces[*w]);
                let mut spans = vec![];
                if searching_view {
                    let prefix = pane_prefix(machine, ws);
                    spans.push(Span::styled("▫ ", dim));
                    let label = format!("{prefix}⎇ {}", t.branch);
                    spans.extend(highlighted(&label, hits, prefix.chars().count(), dim, dim));
                } else {
                    let glyph = if *last { "└─" } else { "├─" };
                    spans.push(Span::styled(format!("    {glyph} ▫ ⎇ {}", t.branch), dim));
                }
                let short = t.path.strip_prefix(&home()).map(|r| format!("~{r}")).unwrap_or_else(|| t.path.clone());
                spans.push(Span::styled(format!("  {short}"), dim));
                let note = if t.prunable { "prunable" } else { "closed" };
                TRow::new(vec![
                    Cell::from(Line::from(spans)),
                    Cell::from(Span::styled("worktree", dim)),
                    Cell::from(Span::styled(note, dim)),
                ])
            }
        })
        .collect();

    if rows.is_empty() {
        f.render_widget(Paragraph::new(" No matching agents or terminals").style(dim), tree_area);
    } else {
        let table = Table::new(rows, [Constraint::Min(20), Constraint::Length(10), Constraint::Length(9)])
            .column_spacing(2)
            .row_highlight_style(Style::new().bg(Color::Rgb(0x8c, 0x9c, 0xd6)).fg(Color::Black).bold());
        f.render_stateful_widget(table, tree_area, &mut app.table);
    }

    // --- preview
    if let Some(parea) = preview_area {
        let (title, body): (String, Text) = match app.current_pane() {
            Some((m, _, p)) => {
                let key = format!("{}/{}", m.name, p.pane_id);
                let body = match app.preview.cache.get(&key) {
                    Some((_, Ok(text))) => {
                        let want = parea.height.saturating_sub(2) as usize;
                        let lines: Vec<&str> = text.lines().collect();
                        let start = lines.len().saturating_sub(want);
                        Text::from(lines[start..].iter().map(|l| Line::raw(l.to_string())).collect::<Vec<_>>())
                    }
                    Some((_, Err(e))) => Text::styled(format!("preview failed: {e}"), Style::new().fg(Color::Red)),
                    None => Text::styled("loading…", dim),
                };
                (format!(" {} · {} ", p.pane_id, p.title), body)
            }
            None => (" preview ".into(), Text::styled("select a pane", dim)),
        };
        let block = Block::default().borders(Borders::ALL).border_style(dim).title(title);
        f.render_widget(Paragraph::new(body).block(block), parea);
    }

    // --- footer
    let (l1, l2) = match app.selected.and_then(|i| app.rows.get(i)) {
        Some(Row::Pane { m, w, p, .. }) => {
            let (m, w) = (&app.machines[*m], &app.machines[*m].workspaces[*w]);
            let p = &w.panes[*p];
            let path = if m.remote {
                format!("{} · {} / {} / {}", m.name, w.label, p.tab_number, p.pane_id)
            } else {
                format!("{} / {} / {}", w.label, p.tab_number, p.pane_id)
            };
            (path, p.cwd.clone())
        }
        Some(Row::Workspace { m, w, .. }) => {
            let (m, w) = (&app.machines[*m], &app.machines[*m].workspaces[*w]);
            let path = if m.remote { format!("{} · {}", m.name, w.label) } else { w.label.clone() };
            (format!("{path}  ({} panes)  enter: focus workspace", w.panes.len()), w.cwd.clone())
        }
        Some(Row::Worktree { repo, i, .. }) => {
            let t = app.worktree(repo, *i);
            (format!("{} ⎇ {}  enter: open worktree as workspace", app.repos[repo].name, t.branch), t.path.clone())
        }
        Some(Row::Machine { m, .. }) => (app.machines[*m].name.clone(), String::new()),
        None => (String::new(), String::new()),
    };
    let help = app.message.clone().unwrap_or_else(|| match (app.searching, app.pending) {
        (true, _) => "-- INSERT --  type to filter · C-j/C-k rows · enter open · esc normal".into(),
        (_, Some('g')) => "g…  gg first".into(),
        (_, Some('z')) => "z…  za toggle · zo open · zc close · zM fold all · zR unfold all".into(),
        _ => "j/k · h/l fold · [ ] ws · ' last · p preview · / search · a/b/w/i/d filter · enter · q · ? keys".into(),
    });
    let footer = Layout::vertical([Constraint::Length(1); 3]).split(chunks[3]);
    f.render_widget(Paragraph::new(l1).style(Style::new().fg(Color::Gray)), footer[0]);
    f.render_widget(Paragraph::new(l2).style(dim), footer[1]);
    let help_style = if app.message.is_some() { Style::new().fg(Color::Red) } else { dim };
    f.render_widget(Paragraph::new(help).style(help_style), footer[2]);

    if app.help { draw_help(f, f.area()); }
}

const KEY_HELP: &[(&str, &str)] = &[
    ("Move", ""),
    ("j / k  ↑ / ↓", "row down / up"),
    ("C-d / C-u", "half page down / up"),
    ("C-f / C-b", "page down / up"),
    ("gg / G", "first / last row"),
    ("H / M / L", "top / middle / bottom of view"),
    ("[ / ]  ← / →", "previous / next workspace"),
    ("' ` Tab", "last-used workspace ⇄ current pane"),
    ("", ""),
    ("Tree", ""),
    ("h", "parent · fold open node"),
    ("l", "unfold · first child"),
    ("za / zo / zc", "toggle / open / close fold"),
    ("zM / zR", "fold all / unfold all"),
    ("", ""),
    ("Search & filter", ""),
    ("/", "fuzzy search (insert mode)"),
    ("  Esc", "  back to normal, keep filter"),
    ("  C-w / C-u", "  delete word / clear"),
    ("a b w i d", "all · blocked · working · idle · done"),
    ("x", "clear search and filter"),
    ("", ""),
    ("Actions", ""),
    ("Enter", "focus pane / workspace · open worktree · fold machine"),
    ("p", "toggle preview pane"),
    ("?", "this help"),
    ("q / Esc / C-c", "close"),
];

fn draw_help(f: &mut Frame, area: Rect) {
    let dim = Style::new().fg(Color::DarkGray);
    let key_w = KEY_HELP.iter().map(|(k, _)| k.chars().count()).max().unwrap_or(10) as u16;
    let lines: Vec<Line> = KEY_HELP.iter().map(|(k, d)| {
        if d.is_empty() {
            Line::from(Span::styled(k.to_string(), Style::new().fg(Color::Magenta).bold()))
        } else {
            Line::from(vec![
                Span::styled(format!("{k:<w$}", w = key_w as usize), Style::new().fg(Color::Cyan)),
                Span::styled(format!("  {d}"), Style::new()),
            ])
        }
    }).collect();
    let height = (lines.len() as u16 + 2).min(area.height);
    let width = (key_w + 2 + KEY_HELP.iter().map(|(_, d)| d.chars().count()).max().unwrap_or(20) as u16 + 4).min(area.width);
    let popup = Rect {
        x: area.x + (area.width.saturating_sub(width)) / 2,
        y: area.y + (area.height.saturating_sub(height)) / 2,
        width, height,
    };
    f.render_widget(Clear, popup);
    let block = Block::default().borders(Borders::ALL).border_style(dim)
        .title(" keys ").title_bottom(Line::from(Span::styled(" ? / esc close ", dim)).right_aligned());
    f.render_widget(Paragraph::new(lines).block(block), popup);
}

// ---------------------------------------------------------------- keys

enum Action { None, Quit, Open }

fn handle_key(app: &mut App, key: KeyEvent) -> Action {
    if key.kind != KeyEventKind::Press { return Action::None; }
    app.message = None;
    let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
    let half = (app.page_rows / 2).max(1) as i32;
    let full = app.page_rows.max(1) as i32;
    let before = app.selected;

    if app.help {
        match key.code {
            KeyCode::Char('?') | KeyCode::Esc | KeyCode::Char('q') | KeyCode::Enter => app.help = false,
            KeyCode::Char('c') if ctrl => return Action::Quit,
            _ => {}
        }
        return Action::None;
    }

    // keys shared by both modes (arrows + emacs/vim ctrl movement)
    let shared = match (key.code, ctrl) {
        (KeyCode::Up, _) | (KeyCode::Char('p'), true) | (KeyCode::Char('k'), true) => { app.move_sel(-1); true }
        (KeyCode::Down, _) | (KeyCode::Char('n'), true) | (KeyCode::Char('j'), true) => { app.move_sel(1); true }
        (KeyCode::Left, _) => { app.move_workspace(-1); true }
        (KeyCode::Right, _) => { app.move_workspace(1); true }
        (KeyCode::Char('d'), true) => { app.page(half); true }
        (KeyCode::Char('u'), true) if !app.searching => { app.page(-half); true }
        (KeyCode::Char('f'), true) => { app.page(full); true }
        (KeyCode::Char('b'), true) => { app.page(-full); true }
        (KeyCode::Enter, _) => return Action::Open,
        (KeyCode::Char('c'), true) => return Action::Quit,
        _ => false,
    };
    if shared { if app.selected != before { app.preview.changed_at = Instant::now(); app.user_moved = true; } return Action::None; }

    // ---- insert (search) mode: like vim's `/` prompt
    if app.searching {
        match key.code {
            KeyCode::Esc => app.searching = false, // back to normal, filter stays
            KeyCode::Backspace => { app.query.pop(); app.rebuild(); }
            KeyCode::Char('u') if ctrl => { app.query.clear(); app.rebuild(); }
            KeyCode::Char('w') if ctrl => {
                let trimmed = app.query.trim_end().to_string();
                let cut = trimmed.rfind(' ').map(|i| i + 1).unwrap_or(0);
                app.query.truncate(cut);
                app.rebuild();
            }
            KeyCode::Char(c) => { app.query.push(c); app.rebuild(); }
            _ => {}
        }
        if app.selected != before { app.preview.changed_at = Instant::now(); app.user_moved = true; }
        return Action::None;
    }

    // ---- normal mode
    let pending = app.pending.take();
    match (pending, key.code) {
        (Some('g'), KeyCode::Char('g')) => app.select_edge(true),
        (Some('z'), KeyCode::Char(c)) => app.z_command(c),
        (Some(_), _) => {} // unknown second key: cancel the prefix
        (None, KeyCode::Char('g')) => app.pending = Some('g'),
        (None, KeyCode::Char('z')) => app.pending = Some('z'),
        (None, KeyCode::Char('G')) => app.select_edge(false),
        (None, KeyCode::Char('j')) => app.move_sel(1),
        (None, KeyCode::Char('k')) => app.move_sel(-1),
        (None, KeyCode::Char('h')) => app.tree_left(),
        (None, KeyCode::Char('l')) => app.tree_right(),
        (None, KeyCode::Char('[') | KeyCode::Char('{')) => app.move_workspace(-1),
        (None, KeyCode::Char(']') | KeyCode::Char('}')) => app.move_workspace(1),
        (None, KeyCode::Char(c @ ('H' | 'M' | 'L'))) => app.select_viewport(c),
        (None, KeyCode::Char('\'') | KeyCode::Char('`') | KeyCode::Tab) => app.jump_alternate(),
        (None, KeyCode::Char('p')) => { app.preview.on = !app.preview.on; save_preview_pref(app.preview.on); }
        (None, KeyCode::Char('?')) => app.help = true,
        (None, KeyCode::Char('/')) => { app.query.clear(); app.searching = true; app.rebuild(); }
        (None, KeyCode::Char('x')) => { app.query.clear(); app.set_filter(Filter::All); }
        (None, KeyCode::Esc) => {
            // Esc: drop the active search first, quit when nothing is active
            if !app.query.is_empty() { app.query.clear(); app.rebuild(); } else { return Action::Quit; }
        }
        (None, KeyCode::Char('q')) => return Action::Quit,
        (None, KeyCode::Char('a')) => app.set_filter(Filter::All),
        (None, KeyCode::Char('b')) => app.set_filter(Filter::Blocked),
        (None, KeyCode::Char('w')) => app.set_filter(Filter::Working),
        (None, KeyCode::Char('i')) => app.set_filter(Filter::Idle),
        (None, KeyCode::Char('d')) => app.set_filter(Filter::Done),
        _ => {}
    }
    if app.selected != before { app.preview.changed_at = Instant::now(); app.user_moved = true; }
    Action::None
}

// ---------------------------------------------------------------- main

fn main() -> io::Result<()> {
    // local first, synchronously, so the popup opens with content
    let local = match load_local() {
        Ok(m) => m,
        Err(e) => {
            eprintln!("herdr-goto: cannot read local herdr session: {e}");
            std::process::exit(1);
        }
    };
    let remote_names = list_machines();
    let mut machines = vec![local];
    machines.extend(remote_names.iter().map(|n| Machine::placeholder(n)));

    let (tx, rx) = mpsc::channel::<Msg>();
    let (ptx, prx) = mpsc::channel::<PreviewReq>();
    let (wtx, wrx) = mpsc::channel::<WtReq>();
    {
        let tx = tx.clone();
        thread::spawn(move || local_watcher(tx));
    }
    {
        let tx = tx.clone();
        thread::spawn(move || preview_worker(prx, tx));
    }
    {
        let tx = tx.clone();
        thread::spawn(move || worktree_worker(wrx, tx));
    }
    for name in remote_names {
        let tx = tx.clone();
        thread::spawn(move || remote_watcher(name, tx));
    }

    // MRU: stamp where we are now; the entry below it is the "last" workspace
    let mut recency = load_recency();
    let here = WsRef { machine: "Local".into(), ws: machines[0].focused_workspace.clone() };
    if !here.ws.is_empty() { stamp_recency(&mut recency, here.clone()); }
    let alternate = recency.iter().find(|r| **r != here).cloned();

    let mut app = App {
        machines,
        branches: HashMap::new(),
        branches_pending: HashSet::new(),
        matcher: SkimMatcherV2::default().ignore_case(),
        live: false,
        query: String::new(),
        searching: false,
        help: false,
        pending: None,
        page_rows: 20,
        filter: load_filter_pref(),
        collapsed: HashSet::new(),
        rows: vec![],
        selected: None,
        table: TableState::default(),
        message: None,
        recency,
        alternate,
        initial_pending: false,
        user_moved: false,
        preview: Preview { on: load_preview_pref(), cache: HashMap::new(), sent: None, changed_at: Instant::now(), lines: 20 },
        repos: HashMap::new(),
        ws_repo: HashMap::new(),
        wtx,
    };
    app.request_branches(&tx);
    app.request_worktrees();
    app.rebuild();
    app.select_initial();

    let mut terminal = ratatui::init();
    let result = run(&mut terminal, &mut app, &tx, rx, &ptx);
    ratatui::restore();
    result
}

fn run(
    terminal: &mut ratatui::DefaultTerminal,
    app: &mut App,
    tx: &mpsc::Sender<Msg>,
    rx: mpsc::Receiver<Msg>,
    ptx: &mpsc::Sender<PreviewReq>,
) -> io::Result<()> {
    loop {
        while let Ok(msg) = rx.try_recv() {
            app.apply(msg, tx);
        }
        app.pump_preview(ptx);

        terminal.draw(|f| draw(f, app))?;

        if !event::poll(Duration::from_millis(100))? { continue; }
        let Event::Key(key) = event::read()? else { continue };
        match handle_key(app, key) {
            Action::None => {}
            Action::Quit => return Ok(()),
            Action::Open => {
                let Some(row) = app.selected.and_then(|i| app.rows.get(i)).cloned() else { continue };
                let result = match &row {
                    Row::Pane { m, w, p, .. } => {
                        let (m, w) = (&app.machines[*m], &app.machines[*m].workspaces[*w]);
                        focus_pane(m, w, &w.panes[*p]).map(|_| Some(WsRef { machine: m.name.clone(), ws: w.workspace_id.clone() }))
                    }
                    Row::Workspace { m, w, .. } => {
                        let (m, w) = (&app.machines[*m], &app.machines[*m].workspaces[*w]);
                        focus_workspace(m, w).map(|_| Some(WsRef { machine: m.name.clone(), ws: w.workspace_id.clone() }))
                    }
                    Row::Machine { m, .. } => { let k = app.machine_key(*m); app.toggle_fold(k); Ok(None) }
                    Row::Worktree { m, repo, i, .. } => {
                        let path = app.worktree(repo, *i).path.clone();
                        let machine = app.machines[*m].name.clone();
                        open_worktree(&path).map(|ws| ws.map(|ws| WsRef { machine, ws }))
                    }
                };
                match result {
                    Ok(Some(r)) => { stamp_recency(&mut app.recency, r); return Ok(()); }
                    Ok(None) => {}
                    Err(e) => app.message = Some(format!("focus failed: {e}")),
                }
            }
        }
    }
}
