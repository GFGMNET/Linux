#!/usr/bin/env bash
# ap-update.sh - updates an installed PC.
#
#   ap-update.sh --auto          weekly, started by archprofiles-update.timer
#   ap-update.sh --interactive   the "Update" icon (runs in a terminal window)
#
# Steps:
#   1. safety checks (automatic mode only skips, interactive mode asks):
#        - Arch news since the last update (may need a manual step)
#        - laptop running on battery
#   2. newest profiles from the Git repository (profile-apply --pull)
#   3. installs what is new in this PC's profiles, updates all packages,
#      AUR packages and Flatpak apps (profile-apply)
#   4. tells the logged-in users the result (notification), incl.
#      "please restart" after a kernel update
#   5. automatic mode only: virus scan of /home with ClamAV (if installed);
#      found files are reported, never deleted
#
# Shutdown/sleep is blocked while it runs, so an update is never cut off.
# Log: /var/log/archprofiles/update.log

main() {
  set -uo pipefail
  local mode=${1:---interactive}
  local self lib
  self=$(readlink -f "${BASH_SOURCE[0]}")
  lib=$(dirname "$self")
  # shellcheck source=common.sh
  source "$lib/common.sh"

  local state=/var/lib/archprofiles
  local stamp=$state/last-update
  local logdir=/var/log/archprofiles
  local news_url=https://archlinux.org/feeds/news/
  local applied=$state/applied-profiles.txt
  local interactive=0
  [[ $mode == --interactive ]] && interactive=1

  case $mode in
    --auto|--interactive) ;;
    -h|--help) sed -n '2,20p' "$self" | sed 's/^# \{0,1\}//'; return 0 ;;
    *) ap_err "Unknown option $mode"; return 2 ;;
  esac

  if [[ $EUID -ne 0 ]]; then
    if (( interactive )); then
      echo "Administrator password needed to install updates."
      exec sudo "$self" "$mode"
    fi
    ap_err "Must run as root."; return 1
  fi

  mkdir -p "$state" "$logdir"
  exec > >(tee -a "$logdir/update.log") 2>&1
  echo
  ap_log "Update started $(date '+%F %T') ($mode)"

  # only one update at a time
  exec 9>/run/archprofiles-update.lock
  if ! flock -n 9; then
    ap_warn "Another update is already running."
    (( interactive )) && pause_end
    return 0
  fi

  # first run: count from the installation, not from the beginning of time
  [[ -f $stamp ]] || date +%s > "$stamp"

  # --- safety checks ----------------------------------------------------
  if (( ! interactive )) && on_battery; then
    ap_log "Running on battery - skipped, will try again next time."
    return 0
  fi

  if ! wait_online; then
    ap_warn "No internet connection - update skipped."
    (( interactive )) || notify "Update skipped" "No internet connection. It will try again next week, or click Update."
    (( interactive )) && pause_end
    return 0
  fi

  local news
  news=$(news_since "$(cat "$stamp")")
  if [[ -n $news ]]; then
    ap_warn "Arch Linux has published news since the last update:"
    printf '%s\n' "$news" | sed 's/^/     - /'
    echo "     Read it at https://archlinux.org/news/ - it may describe a manual step."
    if (( interactive )); then
      local answer
      read -rp "Have you read the news and want to continue? [y/N] " answer </dev/tty
      [[ ${answer,,} == y* ]] || { ap_log "Cancelled."; pause_end; return 0; }
    else
      notify "Update paused - please check" \
        "Arch Linux published news that may need a manual step. Read https://archlinux.org/news/ and then click the Update icon."
      ap_log "Automatic update skipped because of the news."
      return 0
    fi
  fi

  # --- update -----------------------------------------------------------
  local -a profiles=()
  [[ -f $applied ]] && mapfile -t profiles < <(grep -v '^_base$' "$applied" | sed '/^$/d')

  local rc=0 problems=""
  # each profile-apply run rewrites last-problems.txt, so collect after each
  step() {
    rm -f "$logdir/last-problems.txt"
    run_inhibited "$lib/profile-apply.sh" "$@" || rc=1
    [[ -s $logdir/last-problems.txt ]] && problems+="$(tr '\n' ' ' < "$logdir/last-problems.txt")"
    return 0
  }
  step --pull
  if (( ${#profiles[@]} )); then
    step "${profiles[@]}"
  else
    step _base --no-base
  fi
  step --update

  # --- result -----------------------------------------------------------
  local restart=0
  [[ -d /usr/lib/modules/$(uname -r) ]] || restart=1

  if (( rc == 0 )) && [[ -z $problems ]]; then
    date +%s > "$stamp"
    ap_ok "Update finished."
    if (( restart )); then
      notify "Updates installed - please restart" "A new Linux kernel was installed. Restart the PC soon."
    else
      (( interactive )) || notify "Updates installed" "Your PC is up to date."
    fi
  else
    date +%s > "$stamp"
    ap_warn "Update finished with problems: ${problems:-see log}"
    notify "Update finished with problems" "Some items could not be updated. Details: /var/log/archprofiles/update.log"
  fi
  (( restart )) && ap_warn "A new kernel was installed - please restart the PC."
  (( interactive )) || virus_scan
  (( interactive )) && pause_end
  return 0
}

# weekly ClamAV scan of the users' files; reports, never deletes
virus_scan() {
  command -v clamscan &>/dev/null || return 0
  if ! compgen -G '/var/lib/clamav/*.c[lv]d' >/dev/null; then
    ap_warn "Virus scan skipped: virus definitions not downloaded yet."
    return 0
  fi
  local report=/var/log/archprofiles/virus-scan.log rc
  ap_log "Virus scan of /home (low priority)"
  nice -n 19 ionice -c3 clamscan --recursive --infected --no-summary \
    --max-filesize=200M --max-scansize=400M \
    --exclude-dir='/\.cache/' --exclude-dir='/\.local/share/Steam/' \
    --exclude-dir='/\.local/share/Trash/' --exclude-dir='/\.var/app/[^/]+/cache/' \
    /home > "$report.new" 2>/dev/null
  rc=$?
  { echo "# Virus scan $(date '+%F %T') - exit code $rc (0 = clean, 1 = found)"; cat "$report.new"; } > "$report"
  rm -f "$report.new"
  local found
  found=$(grep -c 'FOUND$' "$report" || true)
  if (( found > 0 )); then
    ap_warn "Virus scan: $found infected file(s) - see $report"
    notify "Virus warning: $found infected file(s)" \
      "The weekly scan found infected files. Nothing was deleted. Details: $report or open ClamTk."
  elif (( rc == 0 )); then
    ap_ok "Virus scan: no threats found."
  else
    ap_warn "Virus scan could not complete (exit code $rc) - see $report"
  fi
}

# true when a laptop runs on battery (no mains power connected)
on_battery() {
  local ps type have_battery=0 mains_online=0 have_mains=0
  for ps in /sys/class/power_supply/*; do
    [[ -r $ps/type ]] || continue
    type=$(<"$ps/type")
    case $type in
      Battery) have_battery=1 ;;
      Mains)   have_mains=1; [[ $(cat "$ps/online" 2>/dev/null) == 1 ]] && mains_online=1 ;;
    esac
  done
  (( have_battery && have_mains && ! mains_online ))
}

wait_online() {
  local _
  for _ in $(seq 1 60); do
    ping -c1 -W2 archlinux.org &>/dev/null && return 0
    sleep 5
  done
  return 1
}

# news_since EPOCH -> titles of Arch news published after EPOCH (one per line)
news_since() {
  local since=$1 feed
  feed=$(curl -fsS --max-time 30 "$news_url" 2>/dev/null) || return 0
  awk 'BEGIN { RS="<item>" } NR > 1 {
         t = $0; sub(/.*<title>/, "", t); sub(/<\/title>.*/, "", t)
         d = $0; sub(/.*<pubDate>/, "", d); sub(/<\/pubDate>.*/, "", d)
         gsub(/\n/, " ", t); print d "\t" t
       }' <<<"$feed" |
  while IFS=$'\t' read -r d t; do
    local when
    when=$(date -d "$d" +%s 2>/dev/null) || continue
    (( when > since )) && printf '%s\n' "$t"
  done
}

# runs a command while blocking shutdown and sleep
run_inhibited() {
  # use the blocker only when logind answers (not in a chroot or container)
  if command -v systemd-inhibit &>/dev/null && systemd-inhibit --list &>/dev/null; then
    systemd-inhibit --what=shutdown:sleep --who="Update" \
      --why="Installing updates - please wait" --mode=block "$@"
  else
    "$@"
  fi
}

# notify TITLE TEXT -> desktop notification for every logged-in user
notify() {
  local title=$1 text=$2 dir uid user
  command -v notify-send &>/dev/null || return 0
  for dir in /run/user/*; do
    uid=${dir##*/}
    [[ $uid =~ ^[0-9]+$ ]] && (( uid >= 1000 )) || continue
    [[ -S $dir/bus ]] || continue
    user=$(id -nu "$uid" 2>/dev/null) || continue
    runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$dir/bus" \
      notify-send -a Update -i system-software-update "$title" "$text" 2>/dev/null || true
  done
}

pause_end() {
  echo
  read -rp "Press Enter to close this window." _ </dev/tty || true
}

# the whole file is read before anything runs, so the script can safely
# update itself (profile-apply --pull) while it is running
main "$@"
exit $?
