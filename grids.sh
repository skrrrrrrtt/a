#!/bin/bash
# ==========================================
# MASS AUTO GRID + WATCHDOG + WEBHOOK v5
# 2x2 Mini Size + Status Monitor + Private Servers
# ==========================================

# --- CONFIG ---
ACTIVITY="com.roblox.client.startup.ActivitySplash"
PLACE_ID="8737899170"
WEBHOOK_URL="https://discord.com/api/webhooks/1496005544647987330/dkysna5X4YSxyZQKcRRfaCIgJesRUvvBge5Kt8I43oIuLeLTZlacSMdxLpvvx8mkjq6u"
DELAY=5
JOIN_DELAY=20
WATCHDOG_INTERVAL=15
MAX_REJOIN=5
JOIN_RETRY=2
COLS=3
ROWS=3
STATUS_INTERVAL=30
MAX_CLONES=0  # max clones to use (0 = use all detected)

# --- PRIVATE SERVER CONFIG ---
JOIN_PRIVATE_SERVER=true  # set to false to join public servers

# Private server codes (each instance gets a different one)
PRIVATE_SERVER_CODES=(
    "e928b6e1f3d64242941cb13ffc1e30be"
    "4e847b874a13bd408a2286955bb36da1"
    "8ec5f4eaa779bc4f8437a8815fcbc7de"
    "59813dfd838c3843b04f6224079cd46e"
    "27ef4f96beb78f40aaa6a218bb509f36"
    "d53ebd47be65a442a5dd10e7c4d12168"
    "ceda9456ea12f94fa452132c4c14ca1e"
    "07ab9864ec9ab64caae21562e8c8b3cc"
    "9abb6b52ea705b4799d051021b43719a"
    "41ace4e6525bb447aab74d2d75c91080"
    "a0f37dc52b0ea74099bb330cd9168f32"
    "7c40dddbbf8b8b40a48190c6088d0058"
    "0043166a9f891c409df650f9280b48db"
    "03e7c562571fe54786b84260109ad8cc"
    "fb3831992470a14ab131f2240aab8531"
    "948611883826a245b9396ae9847e136f"
    "f9502371fc96c24bad76cc2156a5cc46"
    "5da0499d73983449971779c5aac38f78"
    "08ebb598f3fd214092a2604705d77452"
    "3436c5ad62616d46b6ee9b978caac5a8"
    "7c6a22a916d5ec479d63942396192b16"
    "7cd0b9dd66acb642aa5b5dec1a14de69"
)

STATUS_MSG_ID=""
declare -a LAUNCH_TIMES

# --- UTILS ---
log_info() { printf "\r%b\n" "$1"; }

send_webhook() {
    local title="$1" local desc="$2" local color="$3"
    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"embeds\": [{
                \"title\": \"$title\",
                \"description\": \"$desc\",
                \"color\": $color,
                \"footer\": { \"text\": \"AutoGrid Watchdog • $(date '+%H:%M:%S')\" }
            }]
        }" > /dev/null 2>&1
}

is_running() {
    su -c "pidof $1" > /dev/null 2>&1
}

# ==========================================
# STATUS MONITOR WEBHOOK (AUTO-UPDATE)
# ==========================================

send_status_initial() {
    local payload="$1"
    local response
    response=$(curl -s -X POST "${WEBHOOK_URL}?wait=true" \
        -H "Content-Type: application/json" \
        -d "$payload")
    STATUS_MSG_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
}

edit_status_msg() {
    local payload="$1"
    if [ -n "$STATUS_MSG_ID" ]; then
        curl -s -X PATCH "${WEBHOOK_URL}/messages/${STATUS_MSG_ID}" \
            -H "Content-Type: application/json" \
            -d "$payload" > /dev/null 2>&1
    fi
}

get_pid() {
    su -c "pidof $1" 2>/dev/null | awk '{print $1}'
}

get_mem_mb() {
    local pid="$1"
    if [ -n "$pid" ] && [ "$pid" != "" ]; then
        local kb
        kb=$(su -c "cat /proc/$pid/status 2>/dev/null" | grep "VmRSS:" | awk '{print $2}')
        if [ -n "$kb" ]; then
            echo "$((kb / 1024))"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

format_uptime() {
    local secs="$1"
    printf "%02d:%02d:%02d" $((secs/3600)) $(((secs%3600)/60)) $((secs%60))
}

get_sys_cpu() {
    su -c "cat /proc/stat 2>/dev/null" | head -1 | awk '{
        user=$2; nice=$3; sys=$4; idle=$5; iow=$6; irq=$7; sirq=$8;
        total = user + nice + sys + idle + iow + irq + sirq;
        if (total > 0) printf "%d", ((total - idle) * 100 / total);
        else print "0";
    }' 2>/dev/null || echo "0"
}

get_sys_mem() {
    su -c "cat /proc/meminfo 2>/dev/null" | awk '
        /^MemTotal:/    { total=$2 }
        /^MemAvailable:/ { avail=$2 }
        /^MemFree:/     { free=$2 }
        /^Buffers:/     { buf=$2 }
        /^Cached:/      { cache=$2 }
        END {
            if (avail == 0) avail = free + buf + cache;
            used = total - avail;
            if (total > 0) pct = int(used * 100 / total); else pct = 0;
            printf "%.1f|%.1f|%d", used/1048576, total/1048576, pct;
        }
    ' 2>/dev/null || echo "0.0|0.0|0"
}

get_app_size_mb() {
    local pkg="$1"
    local size_kb
    size_kb=$(su -c "du -s /data/data/$pkg 2>/dev/null" | awk '{print $1}')
    if [ -n "$size_kb" ]; then
        echo "$((size_kb / 1024))"
    else
        echo "?"
    fi
}

# ==========================================
# BUILD STATUS EMBED
# ==========================================

build_status_payload() {
    local now
    now=$(date +%s)
    local online_count=0
    local desc=""

    for i in "${!PACKAGES[@]}"; do
        local pkg="${PACKAGES[$i]}"
        local pid
        pid=$(get_pid "$pkg")
        local status_icon status_text mem_mb uptime_str app_size

        if [ -n "$pid" ] && [ "$pid" != "" ]; then
            status_icon="🟢"
            status_text="IN-GAME"
            online_count=$((online_count + 1))
            mem_mb=$(get_mem_mb "$pid")
            local launch_t=${LAUNCH_TIMES[$i]:-$now}
            local elapsed=$((now - launch_t))
            uptime_str=$(format_uptime $elapsed)
        else
            status_icon="🔴"
            status_text="OFFLINE"
            mem_mb="0"
            uptime_str="00:00:00"
        fi

        app_size=$(get_app_size_mb "$pkg")
        
        # Show which private server this instance is using
        local server_info=""
        if [ "$JOIN_PRIVATE_SERVER" = true ]; then
            local ps_index=$((i % ${#PRIVATE_SERVER_CODES[@]}))
            local ps_code="${PRIVATE_SERVER_CODES[$ps_index]}"
            server_info="🔐 PS: \`${ps_code:0:8}...\`\n"
        fi
        
        desc="${desc}${status_icon} **${pkg}**\n"
        desc="${desc}${server_info}"
        desc="${desc}📁 ${app_size} MB • 🧠 ${mem_mb} MB RAM\n"
        desc="${desc}⏱️ \`${uptime_str}\`\n"
        desc="${desc}${status_text}\n"
        desc="${desc}━━━━━━━━━━━━━━━━━━━━━━\n"
    done

    local sys_cpu
    sys_cpu=$(get_sys_cpu)
    local mem_info
    mem_info=$(get_sys_mem)
    local mem_used mem_total mem_pct
    mem_used=$(echo "$mem_info" | cut -d'|' -f1)
    mem_total=$(echo "$mem_info" | cut -d'|' -f2)
    mem_pct=$(echo "$mem_info"   | cut -d'|' -f3)

    local mode_text="Public Servers"
    if [ "$JOIN_PRIVATE_SERVER" = true ]; then
        mode_text="Private Servers"
    fi

    desc="${desc}\n**🖥️ System Resources**\n"
    desc="${desc}CPU: \`${sys_cpu}%\` used\n"
    desc="${desc}Memory: \`${mem_used} GB / ${mem_total} GB (${mem_pct}% used)\`\n"
    desc="${desc}\n**📋 Summary**\n"
    desc="${desc}Mode: **${mode_text}**\n"
    desc="${desc}Total Packages: **${#PACKAGES[@]}**\n"
    desc="${desc}Status: 🟢 **${online_count}** / 🔴 **$((${#PACKAGES[@]} - online_count))**\n"
    desc="${desc}Last update: \`$(date '+%H:%M:%S')\`\n"

    local color=65280
    if [ "$online_count" -eq 0 ]; then
        color=16711680
    elif [ "$online_count" -lt "${#PACKAGES[@]}" ]; then
        color=16776960
    fi

    cat <<EOF
{
    "embeds": [{
        "title": "📦 Package Status Monitor",
        "description": "${desc}",
        "color": ${color},
        "footer": { "text": "AutoGrid v5 • Auto-Rejoin" }
    }]
}
EOF
}

# ==========================================
# STATUS UPDATE LOOP (background)
# ==========================================

status_loop() {
    sleep 5
    local payload
    payload=$(build_status_payload)
    send_status_initial "$payload"
    log_info "[STATUS] Monitor message sent (ID: $STATUS_MSG_ID)"
    while true; do
        sleep $STATUS_INTERVAL
        payload=$(build_status_payload)
        edit_status_msg "$payload"
        log_info "[STATUS] Updated $(date '+%H:%M:%S')"
    done
}

# ==========================================
# AUTO DETECT PACKAGES
# ==========================================

detect_packages() {
    log_info "========================================="
    log_info " SCANNING ROBLOX PACKAGES...             "
    log_info "========================================="

    mapfile -t PACKAGES < <(
        su -c "pm list packages 2>/dev/null" \
        | grep "com\.roblox\.clien" \
        | grep -v "^package:com\.roblox\.client$" \
        | sed 's/package://g' \
        | sort
    )

    if [ ${#PACKAGES[@]} -eq 0 ]; then
        mapfile -t PACKAGES < <(
            pm list packages 2>/dev/null \
            | grep "com\.roblox\.clien" \
            | grep -v "^package:com\.roblox\.client$" \
            | sed 's/package://g' \
            | sort
        )
    fi

    if [ ${#PACKAGES[@]} -eq 0 ]; then
        log_info "[ERROR] Tidak ada Roblox clone terdeteksi!"
        exit 1
    fi

    if [ "$MAX_CLONES" -gt 0 ] && [ ${#PACKAGES[@]} -gt $MAX_CLONES ]; then
        log_info "Limiting to $MAX_CLONES clones (${#PACKAGES[@]} detected)"
        PACKAGES=("${PACKAGES[@]:0:$MAX_CLONES}")
    fi

    log_info "Using ${#PACKAGES[@]} clone package(s):"
    for p in "${PACKAGES[@]}"; do
        log_info "  > $p"
    done
    
    if [ "$JOIN_PRIVATE_SERVER" = true ]; then
        log_info ""
        log_info "🔐 PRIVATE SERVER MODE ENABLED"
        log_info "Each instance will join a different private server:"
        for i in "${!PACKAGES[@]}"; do
            local ps_index=$((i % ${#PRIVATE_SERVER_CODES[@]}))
            local ps_code="${PRIVATE_SERVER_CODES[$ps_index]}"
            log_info "  Instance $((i+1)) → ${ps_code}"
        done
    else
        log_info ""
        log_info "🌐 PUBLIC SERVER MODE"
    fi
    
    log_info "========================================="
}

# ==========================================
# LAUNCH + GRID POSITION
# ==========================================

launch_clone() {
    local pkg="$1"
    local i="$2"
    local PREF="/data/data/$pkg/shared_prefs/${pkg}_preferences.xml"
    local row=$((i / COLS))
    local col=$((i % COLS))
    local L=$((col * GW))
    local T=$(((row * GH) + OFFSET_TOP))
    local R=$(((col + 1) * GW))
    local B=$(((row + 1) * GH + OFFSET_TOP))

    log_info "  Grid pos: L=$L T=$T R=$R B=$B"
    su -c "am force-stop $pkg" > /dev/null 2>&1
    sleep 3

    if su -c "[ -f '$PREF' ]" 2>/dev/null; then
        su -c "chmod 666 '$PREF'" > /dev/null 2>&1
        su -c "sed -i 's/name=\"app_cloner_current_window_left\" value=\"[^\"]*\"/name=\"app_cloner_current_window_left\" value=\"$L\"/g' '$PREF'" > /dev/null 2>&1
        su -c "sed -i 's/name=\"app_cloner_current_window_top\" value=\"[^\"]*\"/name=\"app_cloner_current_window_top\" value=\"$T\"/g' '$PREF'" > /dev/null 2>&1
        su -c "sed -i 's/name=\"app_cloner_current_window_right\" value=\"[^\"]*\"/name=\"app_cloner_current_window_right\" value=\"$R\"/g' '$PREF'" > /dev/null 2>&1
        su -c "sed -i 's/name=\"app_cloner_current_window_bottom\" value=\"[^\"]*\"/name=\"app_cloner_current_window_bottom\" value=\"$B\"/g' '$PREF'" > /dev/null 2>&1
        su -c "chmod 444 '$PREF'" > /dev/null 2>&1
        log_info "  Pref written OK"
    else
        log_info "  [WARN] Pref file not found: $PREF"
    fi

    su -c "am start --user 0 -n $pkg/$ACTIVITY" > /dev/null 2>&1
    LAUNCH_TIMES[$i]=$(date +%s)
}

# ==========================================
# JOIN WITH RETRY (FIXED Private Server)
# ==========================================

join_game() {
    local pkg="$1"
    local instance_index="$2"
    
    if [ "$JOIN_PRIVATE_SERVER" = true ]; then
        # Get the private server code for this instance
        local ps_index=$((instance_index % ${#PRIVATE_SERVER_CODES[@]}))
        local ps_code="${PRIVATE_SERVER_CODES[$ps_index]}"
        log_info "  Using private server: ${ps_code:0:12}..."
        
        # Try multiple deep link formats
        for ((r=1; r<=JOIN_RETRY; r++)); do
            # Format 1: placeId with linkCode (most common)
            su -c "am start --user 0 -a android.intent.action.VIEW \
                -d 'roblox://placeId=$PLACE_ID&linkCode=$ps_code' \
                -p $pkg" > /dev/null 2>&1
            sleep 3
            if is_running "$pkg"; then
                return 0
            fi
            
            # Format 2: experiences path with linkCode
            su -c "am start --user 0 -a android.intent.action.VIEW \
                -d 'roblox://experiences/start?placeId=$PLACE_ID&linkCode=$ps_code' \
                -p $pkg" > /dev/null 2>&1
            sleep 3
            if is_running "$pkg"; then
                return 0
            fi
        done
    else
        # Public server
        log_info "  Joining public server..."
        for ((r=1; r<=JOIN_RETRY; r++)); do
            su -c "am start --user 0 -a android.intent.action.VIEW \
                -d 'roblox://experiences/start?placeId=$PLACE_ID' \
                -p $pkg" > /dev/null 2>&1
            sleep 5
            if is_running "$pkg"; then
                return 0
            fi
        done
    fi
    
    return 1
}

# ==========================================
# SCREEN SETUP
# ==========================================

SCREEN_SIZE=$(su -c "wm size" | awk '{print $3}')
W_RAW=$(echo $SCREEN_SIZE | cut -d'x' -f1)
H_RAW=$(echo $SCREEN_SIZE | cut -d'x' -f2)
[ $W_RAW -lt $H_RAW ] && SW=$H_RAW || SW=$W_RAW
[ $W_RAW -lt $H_RAW ] && SH=$W_RAW || SH=$H_RAW

OFFSET_TOP=60
GW=200  # window width  — change to resize
GH=200  # window height — change to resize

log_info "Screen: SW=$SW SH=$SH | Cell: GW=$GW GH=$GH"

# ==========================================
# PRE-RESET ALL PREF PERMISSIONS
# ==========================================

pre_reset_perms() {
    log_info "Resetting pref permissions..."
    for pkg in "${PACKAGES[@]}"; do
        PREF="/data/data/$pkg/shared_prefs/${pkg}_preferences.xml"
        su -c "[ -f '$PREF' ] && chmod 666 '$PREF'" > /dev/null 2>&1
    done
    log_info "Done."
}

# ==========================================
# MAIN
# ==========================================

detect_packages

TOTAL=${#PACKAGES[@]}
declare -a REJOIN_COUNT

for i in "${!PACKAGES[@]}"; do
    REJOIN_COUNT[$i]=0
    LAUNCH_TIMES[$i]=$(date +%s)
done

pre_reset_perms

# Send startup webhook with mode info
local mode_msg="Public Servers"
if [ "$JOIN_PRIVATE_SERVER" = true ]; then
    mode_msg="Private Servers (${#PRIVATE_SERVER_CODES[@]} available)"
fi
send_webhook "🚀 Session Dimulai" "Auto-detected $TOTAL clone(s)\nMode: $mode_msg" 65280

# ==========================================
# LAUNCH + JOIN (PER CLONE)
# ==========================================

for i in "${!PACKAGES[@]}"; do
    PKG=${PACKAGES[$i]}
    log_info "[$((i+1))/$TOTAL] Launch: $PKG"
    launch_clone "$PKG" "$i"
    log_info "  Waiting ${JOIN_DELAY}s..."
    sleep $JOIN_DELAY
    log_info "  Joining..."
    if join_game "$PKG" "$i"; then
        log_info "  SUCCESS"
    else
        log_info "  FAILED (will rely on watchdog)"
    fi
    sleep $DELAY
done

log_info "========================================="
log_info " SEMUA CLONE AKTIF — WATCHDOG ON         "
log_info "========================================="
send_webhook "✅ Semua Clone Aktif" "$TOTAL clone(s) running" 65280

# ==========================================
# START STATUS MONITOR (background)
# ==========================================

status_loop &
STATUS_PID=$!
log_info "[STATUS] Monitor started (PID: $STATUS_PID)"

trap "kill $STATUS_PID 2>/dev/null" EXIT

# ==========================================
# WATCHDOG
# ==========================================

while true; do
    sleep $WATCHDOG_INTERVAL
    for i in "${!PACKAGES[@]}"; do
        PKG=${PACKAGES[$i]}
        [ "${REJOIN_COUNT[$i]}" -ge "$MAX_REJOIN" ] && continue
        if ! is_running "$PKG"; then
            REJOIN_COUNT[$i]=$(( ${REJOIN_COUNT[$i]} + 1 ))
            ATTEMPT=${REJOIN_COUNT[$i]}
            log_info "[WATCHDOG] $PKG MATI — Attempt $ATTEMPT"
            launch_clone "$PKG" "$i"
            sleep $JOIN_DELAY
            if join_game "$PKG" "$i"; then
                log_info "[WATCHDOG] $PKG BACK ONLINE"
            else
                log_info "[WATCHDOG] FAILED $ATTEMPT"
            fi
        fi
    done
done
