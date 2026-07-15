#!/usr/bin/env bash

set -euo pipefail

PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

GUM_BIN="$(command -v gum 2>/dev/null || true)"
if [ -z "$GUM_BIN" ] && [ -x "$HOME/.local/share/mise/installs/gum/0.17.0/gum_0.17.0_Linux_x86_64/gum" ]; then
    GUM_BIN="$HOME/.local/share/mise/installs/gum/0.17.0/gum_0.17.0_Linux_x86_64/gum"
fi

FETCH_BIN=""
for cmd in fastfetch neofetch screenfetch; do
    if command -v "$cmd" >/dev/null 2>&1; then
        FETCH_BIN="$cmd"
        break
    fi
done

ACCENT="212"
MUTED="245"
PANEL_BG="#11111b"

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

first_line() {
    while IFS= read -r line; do
        printf '%s\n' "$line"
        return 0
    done
    return 1
}

trim() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

join_lines() {
    local out=""
    local line
    for line in "$@"; do
        [ -n "$line" ] || continue
        if [ -n "$out" ]; then
            out+=$'\n'
        fi
        out+="$line"
    done
    printf '%s' "$out"
}

truncate_text() {
    local text="$1"
    local max_len="${2:-88}"
    if [ "${#text}" -le "$max_len" ]; then
        printf '%s' "$text"
    else
        printf '%s...' "${text:0:$((max_len - 3))}"
    fi
}

section_plain() {
    local title="$1"
    local body="$2"
    printf '\n[%s]\n%s\n' "$title" "$body"
}

section() {
    local title="$1"
    local body="$2"
    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" join --vertical \
            "$("$GUM_BIN" style --align right --bold --foreground "$ACCENT" "$title")" \
            "$("$GUM_BIN" style --align right --foreground 252 "$body")"
    else
        section_plain "$title" "$body"
    fi
}

title() {
    local text="$1"
    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" style --align right --bold --foreground "$ACCENT" "$text"
    else
        printf '%s\n' "$text"
    fi
}

get_os_name() {
    if [ -r /etc/os-release ]; then
        while IFS='=' read -r key value; do
            if [ "$key" = "PRETTY_NAME" ]; then
                value="${value#\"}"
                value="${value%\"}"
                printf '%s\n' "$value"
                return 0
            fi
        done < /etc/os-release
    fi
    uname -s
}

get_cpu_model() {
    if [ -r /proc/cpuinfo ]; then
        while IFS=':' read -r key value; do
            if [ "$key" = "model name" ]; then
                trim "$value"
                printf '\n'
                return 0
            fi
        done < /proc/cpuinfo
    fi
    uname -p 2>/dev/null || printf 'unknown\n'
}

get_uptime() {
    if has_cmd uptime; then
        uptime -p 2>/dev/null | sed 's/^up //'
        return 0
    fi
    if [ -r /proc/uptime ]; then
        local seconds
        IFS=' ' read -r seconds _ < /proc/uptime
        seconds=${seconds%.*}
        printf '%sh\n' "$((seconds / 3600))"
        return 0
    fi
    printf 'unknown\n'
}

get_load() {
    if [ -r /proc/loadavg ]; then
        local a b c _
        read -r a b c _ < /proc/loadavg
        printf '%s %s %s\n' "$a" "$b" "$c"
        return 0
    fi
    printf 'n/a\n'
}

get_ram_summary() {
    if has_cmd free; then
        local total used avail
        total="$(free -h | awk '/^Mem:/ {print $2}')"
        used="$(free -h | awk '/^Mem:/ {print $3}')"
        avail="$(free -h | awk '/^Mem:/ {print $7}')"
        printf '%s used / %s total (avail %s)\n' "$used" "$total" "$avail"
        return 0
    fi
    printf 'n/a\n'
}

get_root_disk() {
    if has_cmd df; then
        df -h / | awk 'NR==2 {printf "%s used / %s total (%s free) on %s\n", $3, $2, $4, $1}'
        return 0
    fi
    printf 'n/a\n'
}

get_gpu_summary() {
    if has_cmd nvidia-smi; then
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | while IFS=',' read -r name temp util used total; do
            printf '%s | %sC | util %s%% | mem %s/%s MiB\n' "$(trim "$name")" "$(trim "$temp")" "$(trim "$util")" "$(trim "$used")" "$(trim "$total")"
        done
        return 0
    fi
    if has_cmd lspci; then
        lspci | grep -E 'VGA|3D|Display' | first_line || true
        return 0
    fi
    printf 'No GPU tool detected\n'
}

get_local_ip() {
    if has_cmd ip; then
        ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}'
        return 0
    fi
    hostname -I 2>/dev/null | awk '{print $1}'
}

get_default_route() {
    if has_cmd ip; then
        ip route 2>/dev/null | awk '/^default/ {print; exit}'
        return 0
    fi
    printf 'n/a\n'
}

get_public_ip() {
    if [ -x "$HOME/.config/tmux/external_ip.sh" ]; then
        timeout 3s "$HOME/.config/tmux/external_ip.sh" 2>/dev/null || true
        return 0
    fi
    printf 'n/a\n'
}

get_tmux_identity() {
    if [ -n "${TMUX:-}" ] && has_cmd tmux; then
        printf 'session=%s client=%s window=%s pane=%s\n' \
            "$(tmux display-message -p '#S')" \
            "$(tmux display-message -p '#{client_name}')" \
            "$(tmux display-message -p '#I:#W')" \
            "$(tmux display-message -p '#P')" | while IFS= read -r line; do
                truncate_text "$line" 72
                printf '\n'
            done
        return 0
    fi
    printf 'outside tmux\n'
}

get_ip_brief() {
    if has_cmd ip; then
        ip -brief address show up 2>/dev/null
        return 0
    fi
    printf 'n/a\n'
}

get_ss_summary() {
    if has_cmd ss; then
        local tcp udp listen
        tcp="$(ss -H -tan 2>/dev/null | wc -l | tr -d ' ')"
        udp="$(ss -H -uan 2>/dev/null | wc -l | tr -d ' ')"
        listen="$(ss -H -ltn 2>/dev/null | wc -l | tr -d ' ')"
        printf 'tcp=%s udp=%s listening=%s\n' "$tcp" "$udp" "$listen"
        return 0
    fi
    printf 'n/a\n'
}

top_processes() {
    local count=0
    if ! has_cmd ps; then
        printf 'ps unavailable\n'
        return 0
    fi

    while IFS= read -r line; do
        printf '%s\n' "$line"
        count=$((count + 1))
        [ "$count" -ge 8 ] && break
    done < <(ps -eo pid,comm,%cpu,%mem --sort=-%cpu)
}

render_header() {
    local header="Local Status Dashboard"
    local subtitle="Click-driven tmux popup for quick host inspection"
    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" join --vertical \
            "$(title "$header")" \
            "$("$GUM_BIN" style --align right --foreground "$MUTED" "$subtitle")"
    else
        printf '%s\n%s\n' "$header" "$subtitle"
    fi
}

render_overview() {
    local left right
    left="$(join_lines \
        "Host      : $(hostname)" \
        "OS        : $(get_os_name)" \
        "Kernel    : $(uname -r)" \
        "Uptime    : $(get_uptime)" \
        "Time      : $(date '+%Y-%m-%d %H:%M:%S %Z')" \
        "Tmux      : $(get_tmux_identity)")"

    right="$(join_lines \
        "CPU       : $(truncate_text "$(get_cpu_model)" 72)" \
        "RAM       : $(get_ram_summary)" \
        "Disk      : $(get_root_disk)" \
        "GPU       : $(truncate_text "$(get_gpu_summary | first_line || true)" 72)" \
        "Local IP  : $(get_local_ip)" \
        "Public IP : $(get_public_ip)" \
        "Load      : $(get_load)")"

    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" join --vertical \
            "$(render_header)" \
            "$(section 'Overview' "$left")" \
            "$(section 'Live' "$right")"
    else
        printf '%s\n' "$(render_header)"
        section_plain 'Overview' "$left"
        section_plain 'Live' "$right"
    fi
}

render_network() {
    local summary details
    summary="$(join_lines \
        "Primary IP : $(get_local_ip)" \
        "Public IP  : $(get_public_ip)" \
        "Route      : $(truncate_text "$(get_default_route)" 72)" \
        "Sockets    : $(get_ss_summary)")"
    details="$(get_ip_brief)"

    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" join --vertical \
            "$(render_header)" \
            "$(section 'Network Summary' "$summary")" \
            "$(section 'Interfaces' "$details")"
    else
        printf '%s\n' "$(render_header)"
        section_plain 'Network Summary' "$summary"
        section_plain 'Interfaces' "$details"
    fi
}

render_system() {
    local system hardware
    system="$(join_lines \
        "Hostname   : $(hostname)" \
        "Distro     : $(get_os_name)" \
        "Kernel     : $(truncate_text "$(uname -srmo)" 72)" \
        "Uptime     : $(get_uptime)" \
        "Load       : $(get_load)" \
        "Shell      : ${SHELL:-unknown}")"
    hardware="$(join_lines \
        "CPU        : $(truncate_text "$(get_cpu_model)" 72)" \
        "RAM        : $(get_ram_summary)" \
        "Disk       : $(get_root_disk)" \
        "GPU        : $(truncate_text "$(get_gpu_summary | first_line || true)" 72)")"

    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" join --vertical \
            "$(render_header)" \
            "$(section 'System' "$system")" \
            "$(section 'Hardware' "$hardware")"
    else
        printf '%s\n' "$(render_header)"
        section_plain 'System' "$system"
        section_plain 'Hardware' "$hardware"
    fi
}

render_processes() {
    local details
    details="$(top_processes)"

    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" join --vertical \
            "$(render_header)" \
            "$(section 'Top CPU Processes' "$details")"
    else
        printf '%s\n' "$(render_header)"
        section_plain 'Top CPU Processes' "$details"
    fi
}

render_fetch_page() {
    clear
    if [ -n "$FETCH_BIN" ]; then
        if [ -n "$GUM_BIN" ]; then
            "$GUM_BIN" style --foreground "$MUTED" "Press q to leave this page."
            "$GUM_BIN" pager < <(timeout 5s "$FETCH_BIN" 2>/dev/null || printf '%s\n' "$FETCH_BIN failed")
        else
            timeout 5s "$FETCH_BIN" 2>/dev/null || printf '%s\n' "$FETCH_BIN failed"
            printf '\nPress Enter to continue...'
            read -r _
        fi
    else
        if [ -n "$GUM_BIN" ]; then
            "$GUM_BIN" style --foreground 203 'No fastfetch-like tool found. Install fastfetch for the full visual page.'
            "$GUM_BIN" input --prompt '' --placeholder 'Press Enter to go back' >/dev/null
        else
            printf 'No fastfetch-like tool found. Install fastfetch for the full visual page.\n'
            printf 'Press Enter to continue...'
            read -r _
        fi
    fi
}

choose_page() {
    if [ -n "$GUM_BIN" ]; then
        "$GUM_BIN" choose \
            --cursor.foreground "$ACCENT" \
            --selected.foreground "$ACCENT" \
            --header 'Select a panel' \
            'Overview' \
            'Network' \
            'System' \
            'Processes' \
            'Fastfetch' \
            'Refresh' \
            'Close'
    else
        printf 'Overview\nNetwork\nSystem\nProcesses\nFastfetch\nRefresh\nClose\n'
    fi
}

plain_menu() {
    printf '\n[1] Overview\n[2] Network\n[3] System\n[4] Processes\n[5] Fastfetch\n[6] Refresh\n[7] Close\n> '
    read -r answer
    case "$answer" in
        1) printf 'Overview\n' ;;
        2) printf 'Network\n' ;;
        3) printf 'System\n' ;;
        4) printf 'Processes\n' ;;
        5) printf 'Fastfetch\n' ;;
        6) printf 'Refresh\n' ;;
        *) printf 'Close\n' ;;
    esac
}

main() {
    local page="Overview"
    local next
    while true; do
        clear
        case "$page" in
            Overview) render_overview ;;
            Network) render_network ;;
            System) render_system ;;
            Processes) render_processes ;;
            Fastfetch)
                render_fetch_page
                page="Overview"
                continue
                ;;
            *) render_overview ;;
        esac

        if [ -n "$GUM_BIN" ]; then
            next="$(choose_page || true)"
        else
            next="$(plain_menu)"
        fi

        case "$next" in
            ''|Close) exit 0 ;;
            Refresh) continue ;;
            *) page="$next" ;;
        esac
    done
}

main "$@"
