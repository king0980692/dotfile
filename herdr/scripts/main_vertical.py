#!/usr/bin/env python3
# herdr equivalent of your tmux M-n:
#   split-window -h ; select-layout main-vertical   (main-pane-width 55%)
#
# Adds a pane and keeps the tab in a main-vertical arrangement: one big MAIN
# pane on the left (55%), every other pane evenly stacked in the right column.
# Non-destructive — only `pane split` (+ `layout.set_split_ratio`), never the
# pane-spawning layout.apply.
#
# Bound via [[keys.command]] type="shell" on alt+n. Targets the focused tab.
import json, os, socket, subprocess

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
MAIN = 0.55

def rpc(method, params, rid="mv"):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(SOCK)
    s.sendall((json.dumps({"id": rid, "method": method, "params": params}) + "\n").encode())
    buf = b""; s.settimeout(4)
    try:
        while b"\n" not in buf:
            c = s.recv(65536)
            if not c:
                break
            buf += c
    finally:
        s.close()
    return json.loads(buf.decode(errors="replace").split("\n", 1)[0])

def sh(*a):
    return subprocess.run(["herdr", *a], capture_output=True, text=True)

def focused_tab():
    if os.environ.get("HERDR_TAB_ID"):
        return os.environ["HERDR_TAB_ID"]
    ws = json.loads(sh("workspace", "list").stdout)["result"]["workspaces"]
    for w in ws:
        if w.get("focused"):
            return w["active_tab_id"]
    return ws[0]["active_tab_id"] if ws else None

def export(tab):
    return rpc("layout.export", {"tab_id": tab})["result"]["layout"]

def leaves(node, out):
    if node["type"] == "pane":
        out.append(node)
    else:
        leaves(node["first"], out); leaves(node["second"], out)

def cwd_of(node, pid):
    found = [None]
    def walk(n):
        if n["type"] == "pane":
            if n["pane_id"] == pid:
                found[0] = n.get("cwd")
        else:
            walk(n["first"]); walk(n["second"])
    walk(node)
    return found[0]

def bottom_leaf(node):        # deepest 'second' pane (bottom of a down-column)
    while node["type"] == "split":
        node = node["second"]
    return node["pane_id"]

def is_main_vertical(root):
    if root.get("type") != "split" or root.get("direction") != "right":
        return False
    n = root["second"]
    while n["type"] == "split":
        if n["direction"] != "down":
            return False
        n = n["second"]
    return True

def split(target, direction, cwd, ratio=None):
    a = ["pane", "split", "--pane", target, "--direction", direction, "--focus"]
    if ratio is not None:
        a += ["--ratio", str(ratio)]
    if cwd:
        a += ["--cwd", cwd]
    sh(*a)

def main():
    tab = focused_tab()
    if not tab:
        return
    lay = export(tab); root = lay["root"]; foc = lay["focused_pane_id"]
    cwd = cwd_of(root, foc)
    panes = []; leaves(root, panes)

    if len(panes) == 1:
        split(panes[0]["pane_id"], "right", cwd, ratio=MAIN)
    elif is_main_vertical(root):
        col = root["second"]
        target = bottom_leaf(col) if col["type"] == "split" else col["pane_id"]
        split(target, "down", cwd)
        # rebalance: main width = MAIN, right column evenly stacked
        rpc("layout.set_split_ratio", {"tab_id": tab, "path": [], "ratio": MAIN})
        col2 = export(tab)["root"]["second"]
        cnt = []; leaves(col2, cnt); k = len(cnt)
        path = [True]
        for d in range(k - 1):
            rpc("layout.set_split_ratio", {"tab_id": tab, "path": path[:], "ratio": round(1.0 / (k - d), 4)})
            path.append(True)
    else:
        # Not main-vertical and >1 pane: herdr can't re-flow existing panes,
        # so just add below the focused pane (keeps your panes; no conversion).
        split(foc, "down", cwd)

if __name__ == "__main__":
    main()
