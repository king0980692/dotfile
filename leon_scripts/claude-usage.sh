#!/usr/bin/env bash
# Claude plan usage for the starship prompt and the Claude Code statusline:
#   5h━━40%──── ↻2h|7d ▰▰▰▰▰▱▱ 79% ↻14h|F:83%
# The fill and the number take the limit's severity colour; the rest is dim.
#
# Numbers come from the endpoint Claude Code's /usage reads (undocumented, may
# change), authenticated with Claude Code's own OAuth token. The prompt never
# waits on the network: it renders the cached JSON, and a cache older than
# CLAUDE_USAGE_TTL seconds kicks off a detached refresh for the next prompt.
#
#   claude-usage.sh           print the gauges (ANSI colours; starship wraps them)
#   claude-usage.sh --refresh fetch now (blocking)

cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage
json=$cache_dir/usage.json
stamp=$cache_dir/last-attempt
ttl=${CLAUDE_USAGE_TTL:-60}
width=${CLAUDE_USAGE_WIDTH:-6}   # gauge cells, not counting the number
creds=$HOME/.claude/.credentials.json

refresh() {
	mkdir -p "$cache_dir"
	exec 9>"$cache_dir/lock"
	flock -n 9 || return
	touch "$stamp"
	local token tmp
	token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null) || return
	[ -n "$token" ] || return
	tmp=$(mktemp "$cache_dir/usage.XXXXXX")
	if curl -sf --max-time 10 -o "$tmp" https://api.anthropic.com/api/oauth/usage \
		-H "Authorization: Bearer $token" -H "anthropic-beta: oauth-2025-04-20" &&
		jq -e '.five_hour' "$tmp" >/dev/null 2>&1; then
		mv "$tmp" "$json"
	else
		rm -f "$tmp"
	fi
}

case $1 in --refresh) refresh; exit ;; esac

# Stale (or never fetched): refresh in the background, fully detached so the
# prompt doesn't wait on it. Throttled by the last attempt, not the last
# success, so an expired token doesn't retry on every prompt.
if [ ! -e "$stamp" ] || [ $(($(date +%s) - $(stat -c %Y "$stamp"))) -ge "$ttl" ]; then
	setsid "$0" --refresh </dev/null >/dev/null 2>&1 &
fi

[ -r "$json" ] || exit 0

jq -rj --argjson width "$width" '
	def ts: .[0:19] + "Z" | fromdateiso8601;
	# A window whose reset has passed holds old numbers: show it as unknown.
	def live: . != null and .utilization != null and .resets_at != null
		and (.resets_at | ts) > now;
	# Resets land a hair before the minute (16:59:59.9), so round to the nearest.
	def clock: . + 30 | strflocaltime("%-I:%M%p") | ascii_downcase;     # 8:10pm
	def dayclock: (. + 30 | strflocaltime("%a")) + " " + clock;          # Thu 1:00am
	def c($n): "\u001b[\($n)m";
	def colour: if . >= 85 then "1;38;5;196" elif . >= 70 then "38;5;208"
		elif . >= 50 then "38;5;3" elif . >= 30 then "39" else "32" end;
	def rep($n; $s): if $n > 0 then [range($n)] | map($s) | add else "" end;
	def gauge($label; $p):
		if $p == null then c("38;5;8") + $label + rep($width + 3; "─") + c(0)
		else ($p | round) as $p
		| ([$p * $width / 100 | round, $width] | min) as $fill
		| c($p | colour) + $label + rep($fill; "━") + "\($p)%"
		  + c("38;5;8") + rep($width - $fill; "─") + c(0) end;

	# Time left until $t, in hours (↻3h) or, under an hour, minutes (↻45m).
	def countdown($t): (($t - now) / 3600) as $left
		| c("38;5;8") + " ↻"
		  + (if $left < 1 then "\($left * 60 | floor)m" else "\($left | floor)h" end);

	# 5h gauge, plus a countdown to the reset once it is 30% used.
	def session($w):
		($w | if live then .utilization else null end) as $p
		| gauge("5h"; $p)
		  + if $p != null and $p >= 30
		    then countdown($w.resets_at | ts) + c(0)
		    else "" end;

	# 7d as one segment per day of the window, each worth 1/7 of the weekly
	# allowance: ▰ is used (a day counts once at least half of it is), a yellow
	# ▱ is allowance from days already gone that went unused, a grey ▱ is the
	# days still ahead. Used segments are green below an even pace, orange
	# ahead of it. The segment for today — where usage should reach by tonight to
	# keep pace — is blue, filled or not. Once 50% is used a countdown to the reset
	# follows in hours (↻14h); otherwise the reset time shows on the last day.
	def week($w):
		if ($w | live | not) then c("38;5;8") + "7d ▱▱▱▱▱▱▱" + c(0)
		else $w.utilization as $u
		| ($w.resets_at | ts) as $end
		| ((now - ($end - 604800)) / 86400) as $el
		| (if $u >= 95 then "1;38;5;196" elif $u > $el * 100 / 7 then "38;5;208"
		   else "32" end) as $col
		| ($el | floor) as $today
		| ([range(7) | . as $i
		    | (if $u * 7 / 100 - $i >= 0.5 then "▰" else "▱" end) as $g
		    | if $i == $today then c("1;38;5;39") + $g
		      elif $g == "▰" then c($col) + $g
		      elif $i < $today then c("38;5;3") + $g
		      else c("38;5;8") + $g end] | add) as $cells
		| (if $u >= 50 then countdown($end)
		   elif 7 - $el < 1 then c("38;5;8") + " ↻" + ($end | dayclock)
		   else "" end) as $tail
		| c($col) + "7d " + $cells + " " + c($col) + "\($u | round)%" + $tail + c(0)
		end;

	# Per-model weekly limit as just the number, coloured by how much is used
	# (same thresholds as the bar gauges):  F:83%
	def model_week($l):
		($l.scope.model.display_name // "?" | .[0:1]) as $label
		| if $l.percent == null or $l.resets_at == null
		     or ($l.resets_at | ts) <= now
		  then c("38;5;8") + $label + ":?" + c(0)
		  else ($l.percent | round) as $p
		  | c($p | colour) + $label + ":\($p)%" + c(0)
		  end;

	(.limits // []) as $limits
	# Each gauge fails on its own: an odd API answer for one window must not
	# blank the whole line (it once did, for both starship and the statusline).
	| [ (try session(.five_hour) catch (stderr | empty)),
	    (try week(.seven_day) catch (stderr | empty)),
	    ( $limits[] | select(.kind == "weekly_scoped")
	      | try model_week(.)
	        catch (stderr | empty) )
	  ] | join(c("39") + "|" + c(0))
' "$json" 2>>"$cache_dir/errors.log"
