--- scp-back: pull the hovered / selected files back to the machine this ssh
--- session came from.
---
--- Builds `scp -r user@host:'path' … .` (leon_scripts/scp-back.sh works out
--- the host from SSH_CONNECTION, so no per-client setup) and puts it on the
--- *client's* clipboard via OSC 52, which herdr forwards to the outer terminal.
--- Paste it into a terminal on that machine to fetch the files.
---
--- It copies a command rather than pushing the files because this box cannot
--- reach the client on its own: that would need an sshd plus a reverse tunnel
--- on every machine that connects in.

-- In yazi 26 `selected` yields File objects, not Urls; `.path` is the local
-- filesystem path (what the built-in plugins use too).
local get_paths = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, f in pairs(tab.selected) do
		paths[#paths + 1] = tostring(f.path)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.path)
	end
	return paths
end)

local function notify(content, level)
	ya.notify { title = "scp-back", content = content, level = level or "info", timeout = 5 }
end

return {
	entry = function()
		local paths = get_paths()
		if #paths == 0 then
			return notify("Nothing hovered or selected.", "warn")
		end

		local out, err = Command(os.getenv("HOME") .. "/.config/leon_scripts/scp-back.sh")
			:arg(paths)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:output()
		if not out then
			return notify("Failed to run scp-back.sh: " .. tostring(err), "error")
		end
		if not out.status.success then
			return notify("Not in an ssh session — there is no machine to send back to.", "warn")
		end

		ya.clipboard((out.stdout:gsub("%s+$", "")))
		notify(
			string.format(
				"scp command for %d item%s copied to your local clipboard — paste it in a terminal there.",
				#paths,
				#paths == 1 and "" or "s"
			)
		)
	end,
}
