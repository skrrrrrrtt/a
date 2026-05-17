is there like a code for optimizing the phone in here or na
#!/bin/bash

========================================== MASS AUTO GRID + WATCHDOG + WEBHOOK v5 — 2x2 Mini Size + Status Monitor ========================================== --- CONFIG --- 

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

MAX_CLONES=0 # max clones to use (0 = use all detected)

STATUS_MSG_ID=""

declare -a LAUNCH_TIMES

--- UTILS --- 

log_info() { printf "\r%b\n" "$1"; }

send_webhook() {

local title="$1" local desc="$2" local color="$3" curl -s -X POST "$WEBHOOK_URL" \ -H "Content-Type: application/json" \ -d "{ \"embeds\": [{ \"title\": \"$title\", \"description\": \"$desc\", \"color\": $color, \"footer\": { \"text\": \"AutoGrid Watchdog • $(date '+%H:%M:%S')\" } }] }" > /dev/null 2>&1 

}

is_running() {

su -c "pidof $1" > /dev/null 2>&1 

}

========================================== STATUS MONITOR WEBHOOK (AUTO-UPDATE) ========================================== Send initial status embed, capture message ID 

send_status_initial() {

local payload="$1" local response response=$(curl -s -X POST "${WEBHOOK_URL}?wait=true" \ -H "Content-Type: application/json" \ -d "$payload") STATUS_MSG_ID=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4) 

}

Edit existing status message 

edit_status_msg() {

local payload="$1" if [ -n "$STATUS_MSG_ID" ]; then curl -s -X PATCH "${WEBHOOK_URL}/messages/${STATUS_MSG_ID}" \ -H "Content-Type: application/json" \ -d "$payload" > /dev/null 2>&1 fi 

}

Get PID of a package 

get_pid() {

su -c "pidof $1" 2>/dev/null | awk '{print $1}' 

}

Get memory usage in MB from /proc 

get_mem_mb() {

local pid="$1" if [ -n "$pid" ] && [ "$pid" != "" ]; then local kb kb=$(su -c "cat /proc/$pid/status 2>/dev/null" | grep "VmRSS:" | awk '{print $2}') if [ -n "$kb" ]; then echo "$((kb / 1024))" else echo "0" fi else echo "0" fi 

}

Format seconds to HH:MM:SS 

format_uptime() {

local secs="$1" printf "%02d:%02d:%02d" $((secs/3600)) $(((secs%3600)/60)) $((secs%60)) 

}

Get system CPU usage % 

get_sys_cpu() {

su -c "cat /proc/stat 2>/dev/null" | head -1 | awk '{ user=$2; nice=$3; sys=$4; idle=$5; iow=$6; irq=$7; sirq=$8; total = user + nice + sys + idle + iow + irq + sirq; if (total > 0) printf "%d", ((total - idle) * 100 / total); else print "0"; }' 2>/dev/null || echo "0" 

}

Get system memory info 

get_sys_mem() {

su -c "cat /proc/meminfo 2>/dev/null" | awk ' /^MemTotal:/ { total=$2 } /^MemAvailable:/ { avail=$2 } /^MemFree:/ { free=$2 } /^Buffers:/ { buf=$2 } /^Cached:/ { cache=$2 } END { if (avail == 0) avail = free + buf + cache; used = total - avail; if (total > 0) pct = int(used * 100 / total); else pct = 0; printf "%.1f|%.1f|%d", used/1048576, total/1048576, pct; } ' 2>/dev/null || echo "0.0|0.0|0" 

}

Get app data size in MB 

get_app_size_mb() {

local pkg="$1" local size_kb size_kb=$(su -c "du -s /data/data/$pkg 2>/dev/null" | awk '{print $1}') if [ -n "$size_kb" ]; then echo "$((size_kb / 1024))" else echo "?" fi 

}

========================================== BUILD STATUS EMBED ========================================== 

build_status_payload() {

local now now=$(date +%s) local online_count=0 local desc="" for i in "${!PACKAGES[@]}"; do local pkg="${PACKAGES[$i]}" local pid pid=$(get_pid "$pkg") local status_icon status_text mem_mb uptime_str app_size if [ -n "$pid" ] && [ "$pid" != "" ]; then status_icon="🟢" status_text="IN-GAME" online_count=$((online_count + 1)) mem_mb=$(get_mem_mb "$pid") local launch_t=${LAUNCH_TIMES[$i]:-$now} local elapsed=$((now - launch_t)) uptime_str=$(format_uptime $elapsed) else status_icon="🔴" status_text="OFFLINE" mem_mb="0" uptime_str="00:00:00" fi app_size=$(get_app_size_mb "$pkg") # Build per-clone block desc="${desc}${status_icon} **${pkg}**\\n" desc="${desc}📁 ${app_size} MB • 🧠 ${mem_mb} MB RAM\\n" desc="${desc}⏱️ \`${uptime_str}\`\\n" desc="${desc}${status_text}\\n" desc="${desc}━━━━━━━━━━━━━━━━━━━━━━\\n" done # System resources local sys_cpu sys_cpu=$(get_sys_cpu) local mem_info mem_info=$(get_sys_mem) local mem_used mem_total mem_pct mem_used=$(echo "$mem_info" | cut -d'|' -f1) mem_total=$(echo "$mem_info" | cut -d'|' -f2) mem_pct=$(echo "$mem_info" | cut -d'|' -f3) desc="${desc}\\n**🖥️ System Resources**\\n" desc="${desc}CPU: \`${sys_cpu}%\` used\\n" desc="${desc}Memory: \`${mem_used} GB / ${mem_total} GB (${mem_pct}% used)\`\\n" # Summary desc="${desc}\\n**📋 Summary**\\n" desc="${desc}Total Packages: **${#PACKAGES[@]}**\\n" desc="${desc}Status: 🟢 **${online_count}** / 🔴 **$((${#PACKAGES[@]} - online_count))**\\n" desc="${desc}Last update: \`$(date '+%H:%M:%S')\`\\n" # Color: green if all online, yellow if partial, red if none local color=65280 if [ "$online_count" -eq 0 ]; then color=16711680 elif [ "$online_count" -lt "${#PACKAGES[@]}" ]; then color=16776960 fi cat <<EOF 

{

"embeds": [{ "title": "📦 Package Status Monitor", "description": "${desc}", "color": ${color}, "footer": { "text": "AutoGrid v5 • Auto-Rejoin" } }] 

}

EOF

}

========================================== STATUS UPDATE LOOP (background) ========================================== 

status_loop() {

sleep 5 local payload payload=$(build_status_payload) send_status_initial "$payload" log_info "[STATUS] Monitor message sent (ID: $STATUS_MSG_ID)" while true; do sleep $STATUS_INTERVAL payload=$(build_status_payload) edit_status_msg "$payload" log_info "[STATUS] Updated $(date '+%H:%M:%S')" done 

}

========================================== AUTO DETECT PACKAGES ========================================== 

detect_packages() {

log_info "=========================================" log_info " SCANNING ROBLOX PACKAGES... " log_info "=========================================" mapfile -t PACKAGES < <( su -c "pm list packages 2>/dev/null" \ | grep "com\.roblox\.clien" \ | grep -v "^package:com\.roblox\.client$" \ | sed 's/package://g' \ | sort ) if [ ${#PACKAGES[@]} -eq 0 ]; then mapfile -t PACKAGES < <( pm list packages 2>/dev/null \ | grep "com\.roblox\.clien" \ | grep -v "^package:com\.roblox\.client$" \ | sed 's/package://g' \ | sort ) fi if [ ${#PACKAGES[@]} -eq 0 ]; then log_info "[ERROR] Tidak ada Roblox clone terdeteksi!" exit 1 fi # Trim to MAX_CLONES if set if [ "$MAX_CLONES" -gt 0 ] && [ ${#PACKAGES[@]} -gt $MAX_CLONES ]; then log_info "Limiting to $MAX_CLONES clones (${#PACKAGES[@]} detected)" PACKAGES=("${PACKAGES[@]:0:$MAX_CLONES}") fi log_info "Using ${#PACKAGES[@]} clone package(s):" for p in "${PACKAGES[@]}"; do log_info " > $p" done log_info "=========================================" 

}

========================================== LAUNCH + GRID POSITION (2x2 MINI) ========================================== 

launch_clone() {

local pkg="$1" local i="$2" local PREF="/data/data/$pkg/shared_prefs/${pkg}_preferences.xml" local row=$((i / COLS)) local col=$((i % COLS)) local L=$((col * GW)) local T=$(((row * GH) + OFFSET_TOP)) local R=$(((col + 1) * GW)) local B=$(((row + 1) * GH + OFFSET_TOP)) log_info " Grid pos: L=$L T=$T R=$R B=$B" # Force stop first su -c "am force-stop $pkg" > /dev/null 2>&1 sleep 3 # Reset perm + write position if su -c "[ -f '$PREF' ]" 2>/dev/null; then su -c "chmod 666 '$PREF'" > /dev/null 2>&1 su -c "sed -i 's/name=\"app_cloner_current_window_left\" value=\"[^\"]*\"/name=\"app_cloner_current_window_left\" value=\"$L\"/g' '$PREF'" > /dev/null 2>&1 su -c "sed -i 's/name=\"app_cloner_current_window_top\" value=\"[^\"]*\"/name=\"app_cloner_current_window_top\" value=\"$T\"/g' '$PREF'" > /dev/null 2>&1 su -c "sed -i 's/name=\"app_cloner_current_window_right\" value=\"[^\"]*\"/name=\"app_cloner_current_window_right\" value=\"$R\"/g' '$PREF'" > /dev/null 2>&1 su -c "sed -i 's/name=\"app_cloner_current_window_bottom\" value=\"[^\"]*\"/name=\"app_cloner_current_window_bottom\" value=\"$B\"/g' '$PREF'" > /dev/null 2>&1 su -c "chmod 444 '$PREF'" > /dev/null 2>&1 log_info " Pref written OK" else log_info " [WARN] Pref file not found: $PREF" fi su -c "am start --user 0 -n $pkg/$ACTIVITY" > /dev/null 2>&1 # Track launch time for uptime calculation LAUNCH_TIMES[$i]=$(date +%s) 

}

========================================== JOIN WITH RETRY ========================================== 

join_game() {

local pkg="$1" for ((r=1; r<=JOIN_RETRY; r++)); do su -c "am start --user 0 -a android.intent.action.VIEW \ -d 'roblox://experiences/start?placeId=$PLACE_ID' \ -p $pkg" > /dev/null 2>&1 sleep 5 if is_running "$pkg"; then return 0 fi done return 1 

}

--- SCREEN SETUP (2x2 MINI) --- 

SCREEN_SIZE=$(su -c "wm size" | awk '{print $3}')

W_RAW=$(echo $SCREEN_SIZE | cut -d'x' -f1)

H_RAW=$(echo $SCREEN_SIZE | cut -d'x' -f2)

[ $W_RAW -lt $H_RAW ] && SW=$H_RAW || SW=$W_RAW

[ $W_RAW -lt $H_RAW ] && SH=$W_RAW || SH=$H_RAW

OFFSET_TOP=60

GW=200 # window width — change this to resize

GH=200 # window height — change this to resize

log_info "Screen: SW=$SW SH=$SH | Cell: GW=$GW GH=$GH"

========================================== PRE-RESET ALL PREF PERMISSIONS ========================================== 

pre_reset_perms() {

log_info "Resetting pref permissions..." for pkg in "${PACKAGES[@]}"; do PREF="/data/data/$pkg/shared_prefs/${pkg}_preferences.xml" su -c "[ -f '$PREF' ] && chmod 666 '$PREF'" > /dev/null 2>&1 done log_info "Done." 

}

========================================== MAIN ========================================== 

detect_packages

TOTAL=${#PACKAGES[@]}

declare -a REJOIN_COUNT

for i in "${!PACKAGES[@]}"; do

REJOIN_COUNT[$i]=0 LAUNCH_TIMES[$i]=$(date +%s) 

done

pre_reset_perms

send_webhook "🚀 Session Dimulai" "Auto-detected $TOTAL clone(s)" 65280

========================================== LAUNCH + JOIN (PER CLONE) ========================================== 

for i in "${!PACKAGES[@]}"; do

PKG=${PACKAGES[$i]} log_info "[$((i+1))/$TOTAL] Launch: $PKG" launch_clone "$PKG" "$i" log_info " Waiting ${JOIN_DELAY}s..." sleep $JOIN_DELAY log_info " Joining..." if join_game "$PKG"; then log_info " SUCCESS" else log_info " FAILED (will rely on watchdog)" fi sleep $DELAY 

done

log_info "========================================="

log_info " SEMUA CLONE AKTIF — WATCHDOG ON "

log_info "========================================="

send_webhook "✅ Semua Clone Aktif" "$TOTAL clone(s) running" 65280

========================================== START STATUS MONITOR (background) ========================================== 

status_loop &

STATUS_PID=$!

log_info "[STATUS] Monitor started (PID: $STATUS_PID)"

Cleanup on exit 

trap "kill $STATUS_PID 2>/dev/null" EXIT

========================================== WATCHDOG ========================================== 

while true; do

sleep $WATCHDOG_INTERVAL for i in "${!PACKAGES[@]}"; do PKG=${PACKAGES[$i]} [ "${REJOIN_COUNT[$i]}" -ge "$MAX_REJOIN" ] && continue if ! is_running "$PKG"; then REJOIN_COUNT[$i]=$(( ${REJOIN_COUNT[$i]} + 1 )) ATTEMPT=${REJOIN_COUNT[$i]} log_info "[WATCHDOG] $PKG MATI — Attempt $ATTEMPT" launch_clone "$PKG" "$i" sleep $JOIN_DELAY if join_game "$PKG"; then log_info "[WATCHDOG] $PKG BACK ONLINE" else log_info "[WATCHDOG] FAILED $ATTEMPT" fi fi done 

done

