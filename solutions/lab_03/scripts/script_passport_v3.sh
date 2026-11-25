#!/bin/bash

# Проверяет наличие прав
check_privileges() {
	if (( EUID != 0 )); then
		die "Access denied (no permission)"
	fi
	return 0
}

# Завершает скрипт с указанной ошибкой
die() {
	local message="${1:-Unknown error}"
	echo "[ERROR] $message" >&2
	exit 1
}

# Проверяет наличие программ. Принимает список список аргументов
check_tool() {
	local missing=()
	local prog
	for prog in "$@"; do
		if ! which "$prog" &>/dev/null; then
		missing+=("$prog")
		fi
	done
	if (( ${#missing[@]} > 0 )); then
		echo "[ERROR] Missing programs: ${missing[*]}" >&2
		echo "[ERROR] Install them using apt install" >&2
		exit 1
	fi
}

# Пишет содержимое блока в отчет
write_section() {
	local header="$1"
	local tmp_file="$2"
	local filename="$3"
	if [[ ! -r "$tmp_file" ]]; then
		die "Source file not found or unreadable: $tmp_file"
	fi
	{
		echo "======================================"
		echo "$header"
		echo "======================================"
		sed 's/^/  /' "$tmp_file"
	} >> "$filename"
}

log_run() {
	local timestamp=$(date '+%d.%m.%Y %H:%M:%S')
	echo "$timestamp (МСК) | $SCRIPT_VERSION" >> "$REPORT_FILE"
}

usage() {
	cat <<-EOF
		Usage: $(basename "$0") [-h] [report_file]

		Collects information about the system and writes a report.

		Options:
		  -h, --help		show this manual and exit
		
		Arguments:
		  report_file		path to the output file. default: /home/lecel/PASSPORT/inventory.txt

		Examples:
		  $(basename "$0")                    report to PASSPORT/inventory.txt
		  $(basename "$0") my_report.txt      report to my_report.txt
		  $(basename "$0") -h                 this help
	EOF
}

cleanup() {
	find "$TMP_DIR" -name "*.tmp" -delete 2>/dev/null
}




if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi
check_privileges

#variables
readonly SCRIPT_VERSION="v3"
readonly PASSPORT_DIR="/home/lecel/PASSPORT"
readonly DEFAULT_INVENTORY="$PASSPORT_DIR/inventory.txt"
INVENTORY_FILE="${1:-$DEFAULT_INVENTORY}"
readonly PASSPORT_FILE="$PASSPORT_DIR/passport.txt"
readonly REPORT_FILE="$PASSPORT_DIR/log/report.log"
readonly TMP_DIR="$PASSPORT_DIR/tmp"

commands=(uname nproc lscpu dmidecode lspci sed getent id chage lastlog2 column)
readonly commands
check_tool "${commands[@]}"

mkdir -p "$PASSPORT_DIR/log" "$PASSPORT_DIR/tmp"
: > "$PASSPORT_FILE"
: > "$INVENTORY_FILE"

# collect info
{
  echo "date: $(date '+%d.%m.%Y')"
} > "$TMP_DIR/launch.tmp"
{
	echo "hostname: $(hostname)"
	echo "username: $(whoami)" 
} > "$TMP_DIR/host.tmp"
{
  echo "working directory: $(pwd)"
  echo "files:"
  ls -A
} > "$TMP_DIR/directory.tmp"
{
  echo "name: $(uname -s)"
  echo "release: $(uname -r)"
  echo "architecture: $(uname -m)"
} > "$TMP_DIR/kernel.tmp"
{
  echo "name: $(cat /etc/os-release | grep '^NAME' | sed 's/^NAME=//' | sed 's/"//g')"
  echo "version: $(cat /etc/os-release | grep '^VERSION=' | sed 's/^VERSION=//' | sed 's/"//g')"
} > "$TMP_DIR/os.tmp"
{
  echo "name: $(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: *//')"
  echo "mhz: $(grep -m1 'cpu MHz' /proc/cpuinfo | sed 's/.*: *//')"
  echo "cores: $(nproc)"
  echo "$(lscpu | grep -E '^L[123]' | sed 's/  */ /g')"
} > "$TMP_DIR/proc.tmp"
{
  echo "total size: $(grep '^MemTotal:' /proc/meminfo | sed 's/.*: *//')"
} > "$TMP_DIR/memory.tmp"
{
  echo "motherboard: $(sudo dmidecode -s baseboard-product-name)"
  echo "BIOS version: $(sudo dmidecode -s bios-version)"
  echo "BIOS release date: $(sudo dmidecode -s bios-release-date)"
} > "$TMP_DIR/motherboard.tmp"
{
  echo "$(lspci 2>/dev/null)"
} > "$TMP_DIR/dev.tmp"
{
  getent passwd | while IFS=: read -r name _ uid _ _ _ _; do
    if [[ "$uid" -eq 0 ]] || [[ "$uid" -ge 1000 ]]; then
      {
        echo "Name: $name"
        echo "UID: $uid"
        echo "Groups: $(id -nG "$name" 2>/dev/null)"
        echo "Last login: $(lastlog2 -u "$name" 2>/dev/null | tail -n 1 | sed -E 's/^[^ ]+[ ]+//; s/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[ ]+//; s/[ ]+/ /g')"
        echo "Password changed: $(chage -l "$name" 2>/dev/null | grep 'Last password change' | cut -d: -f2 | xargs)"
        echo ""
      }
    fi
  done
} > "$TMP_DIR/users.tmp"
{
  for param in permitrootlogin port logingracetime maxauthtries passwordauthentication pubkeyauthentication; do
    value=$(sshd -T 2>/dev/null | grep "^$param " | awk '{print $2}')
    if grep -q "^$(echo $param | sed 's/./\U&/')" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
      echo "$param: $value (custom)"
    else
      echo "$param: $value (default)"
    fi
  done
} > "$TMP_DIR/sshd.tmp"
{
  ps -eo pid,ppid,user,%mem,comm --sort=-%mem | head -n 6
} > "$TMP_DIR/topproc.tmp"
{
  empty_pass=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
  uid_zero=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd 2>/dev/null)
  
  if [[ -z "$empty_pass" ]] && [[ -z "$uid_zero" ]]; then
    echo "None"
  else
    [[ -n "$empty_pass" ]] && echo "Users with empty password: $empty_pass"
    [[ -n "$uid_zero" ]] && echo "Users with UID 0 (except root): $uid_zero"
  fi
} > "$TMP_DIR/suspicious.tmp"
{
  find /usr/bin /usr/sbin -perm -4000 2>/dev/null
} > "$TMP_DIR/suid.tmp"


# passport
write_section "Host info" "$TMP_DIR/host.tmp" "$PASSPORT_FILE"
write_section "Files info" "$TMP_DIR/directory.tmp" "$PASSPORT_FILE"
write_section "Launch date" "$TMP_DIR/launch.tmp" "$PASSPORT_FILE"

# inventory
write_section "Kernel" "$TMP_DIR/kernel.tmp" "$INVENTORY_FILE"
write_section "OS" "$TMP_DIR/os.tmp" "$INVENTORY_FILE"
write_section "Procesor" "$TMP_DIR/proc.tmp" "$INVENTORY_FILE"
write_section "Memory" "$TMP_DIR/memory.tmp" "$INVENTORY_FILE"
write_section "Motherboard" "$TMP_DIR/motherboard.tmp" "$INVENTORY_FILE"
write_section "PCI Devices" "$TMP_DIR/dev.tmp" "$INVENTORY_FILE"
write_section "Users" "$TMP_DIR/users.tmp" "$INVENTORY_FILE"
write_section "SSHD parameters" "$TMP_DIR/sshd.tmp" "$INVENTORY_FILE"
write_section "Top 5 processes by memory" "$TMP_DIR/topproc.tmp" "$INVENTORY_FILE"
write_section "Suspicious accounts" "$TMP_DIR/suspicious.tmp" "$INVENTORY_FILE"
write_section "SUID files" "$TMP_DIR/suid.tmp" "$INVENTORY_FILE"

cleanup
log_run
