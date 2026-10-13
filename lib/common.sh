# shellcheck shell=bash disable=SC2034  # variables set here are used by bin/mainline
# Shared helpers for bin/mainline. Sourced, not executed.
# Must stay compatible with macOS's stock bash 3.2 (no associative arrays, no mapfile, no readlink -f).

# ---------- output ----------
if [ -t 2 ]; then
  _B=$'\033[1m'; _R=$'\033[31m'; _G=$'\033[32m'; _Y=$'\033[33m'; _C=$'\033[36m'; _N=$'\033[0m'
else
  _B=""; _R=""; _G=""; _Y=""; _C=""; _N=""
fi
step() { printf '%s==>%s %s%s%s\n' "$_C" "$_N" "$_B" "$*" "$_N" >&2; }
info() { printf '    %s\n' "$*" >&2; }
ok()   { printf '    %s✓%s %s\n' "$_G" "$_N" "$*" >&2; }
warn() { printf '    %s!%s %s\n' "$_Y" "$_N" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$_R" "$_N" "$1" >&2; exit "${2:-1}"; }

# rel <path>: the path relative to the current directory when it's inside it, for shorter output.
rel() {
  case "$1" in
    "$PWD") echo "." ;;
    "$PWD"/*) echo "${1#"$PWD"/}" ;;
    *) echo "$1" ;;
  esac
}

# ---------- paths ----------
# Resolve symlinks by hand so `ln -s …/bin/mainline /usr/local/bin/mainline` works.
_mainline_source="${BASH_SOURCE[0]}"
while [ -h "$_mainline_source" ]; do
  _mainline_dir="$(cd -P "$(dirname "$_mainline_source")" && pwd)"
  _mainline_source="$(readlink "$_mainline_source")"
  case "$_mainline_source" in /*) ;; *) _mainline_source="$_mainline_dir/$_mainline_source" ;; esac
done
MAINLINE_ROOT="$(cd -P "$(dirname "$_mainline_source")/.." && pwd)"
unset _mainline_source _mainline_dir

TOOLS_PKG="$MAINLINE_ROOT/tools/MainlineTools"
TOOLS_BIN="$TOOLS_PKG/.build/release"
MAINLINE_HOME="${MAINLINE_HOME:-$HOME/.mainline}"
CONFIG_FILE="${MAINLINE_CONFIG:-$MAINLINE_HOME/config.env}"
CREDENTIALS_FILE="${MAINLINE_CREDENTIALS:-$MAINLINE_HOME/credentials.env}"

# ---------- config ----------
# Later files win: mainline's defaults → your account settings → your API credentials → (later) the app's app.env.
load_config() {
  set -a
  # shellcheck disable=SC1091
  . "$MAINLINE_ROOT/config/defaults.env"
  # shellcheck disable=SC1090
  [ ! -f "$CONFIG_FILE" ] || . "$CONFIG_FILE"
  # shellcheck disable=SC1090
  [ ! -f "$CREDENTIALS_FILE" ] || . "$CREDENTIALS_FILE"
  set +a
  if [ -n "${ASC_KEY_PATH:-}" ]; then
    ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
    export ASC_KEY_PATH
  fi
}

have_credentials() {
  [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ] && [ -f "${ASC_KEY_PATH:-/nonexistent}" ]
}

require_credentials() {
  have_credentials || die "App Store Connect API credentials missing. Run \`mainline setup\` (see docs/setup.md)." 78
  [ -n "${DEVELOPMENT_TEAM:-}" ] || die "DEVELOPMENT_TEAM is not set. Run \`mainline setup --team <TEAM_ID>\`." 78
}

# find_app <name-or-path> → prints the app's directory (one containing app.env), or nothing.
# A name is looked up in ./<name>, ./apps/<name>, $MAINLINE_APPS/<name>, then mainline's examples/.
# No argument means the current directory.
find_app() {
  local arg="${1:-.}" candidate
  case "$arg" in
    */*|.|..) if [ -f "$arg/app.env" ]; then (cd "$arg" && pwd); fi; return 0 ;;
  esac
  for candidate in "$PWD/$arg" "$PWD/apps/$arg" ${MAINLINE_APPS:+"$MAINLINE_APPS/$arg"} "$MAINLINE_ROOT/examples/$arg"; do
    if [ -f "$candidate/app.env" ]; then (cd "$candidate" && pwd); return 0; fi
  done
}

# load_app <name-or-path> → sets APP_DIR, APP_SLUG, APP_REF, BUILD_DIR and everything in app.env
load_app() {
  APP_DIR="$(find_app "${1:-}")"
  if [ -z "$APP_DIR" ]; then
    [ -n "${1:-}" ] || die "no app here. Pass an app name or path, or cd into an app folder (one with app.env)" 64
    die "no app named '$1' (looked for $1/, apps/$1/ and mainline's examples/$1/, each with an app.env)" 64
  fi
  APP_SLUG="$(basename "$APP_DIR")"
  APP_REF="${1:-.}"   # how to name the app in suggested commands
  set -a
  # shellcheck disable=SC1091
  . "$APP_DIR/app.env"
  set +a
  BUILD_DIR="$APP_DIR/build"
  DERIVED_DATA="$BUILD_DIR/DerivedData"
  LOG_DIR="$BUILD_DIR/logs"
  mkdir -p "$LOG_DIR"
  XCODEPROJ="$APP_DIR/$APP_NAME.xcodeproj"
}

# ---------- helper tools (Swift package) ----------
ensure_tools() {
  local newest_src
  local stamp="$TOOLS_BIN/.mainline-built"
  newest_src="$(find "$TOOLS_PKG/Sources" "$TOOLS_PKG/Package.swift" -newer "$stamp" 2>/dev/null | head -1 || true)"
  if [ ! -f "$stamp" ] || [ ! -x "$TOOLS_BIN/asc" ] || [ ! -x "$TOOLS_BIN/appicon" ] || [ -n "$newest_src" ]; then
    step "Building mainline's helper tools (first run only)"
    mkdir -p "$TOOLS_PKG/.build"
    local log="$TOOLS_PKG/.build/mainline-tools-build.log"
    swift build -c release --package-path "$TOOLS_PKG" >"$log" 2>&1 \
      || { tail -30 "$log" >&2; die "failed to build helper tools (log: $log)"; }
    touch "$stamp"
  fi
}

asc() {
  ensure_tools
  "$TOOLS_BIN/asc" "$@"
}

appicon() {
  ensure_tools
  "$TOOLS_BIN/appicon" "$@"
}

# ---------- xcodebuild ----------
# run_logged <log-name> <command...>
# Runs a command with full output in <app>/build/logs/<log-name>.log and prints only
# the interesting lines on failure, which keeps agent transcripts small.
run_logged() {
  local name="$1"; shift
  local log="$LOG_DIR/$name.log"
  info "log: $(rel "$log")"
  local status=0
  "$@" >"$log" 2>&1 || status=$?
  [ "$status" != 0 ] || return 0
  warn "$name failed (exit $status). Relevant output:"
  # Skip xcodebuild's timestamped internal plug-in chatter; keep compiler/test/signing errors.
  { grep -E "error:|failed|FAILED|✘|Failing tests|ERROR" "$log" \
      | grep -vE "^note:|^[0-9]{4}-[0-9]{2}-[0-9]{2} .*xcodebuild\[|^Details:|DVTPlugIn" \
      | awk '!seen[$0]++' | head -40
    echo "    --- last 15 lines ---"
    tail -15 "$log"; } | sed 's/^/    /' >&2
  return "$status"
}

# xcode_auth: sets XCODE_AUTH, the flags that let xcodebuild manage signing with the App Store Connect API key.
xcode_auth() {
  XCODE_AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID")
  [ -z "${ASC_ISSUER_ID:-}" ] || XCODE_AUTH+=(-authenticationKeyIssuerID "$ASC_ISSUER_ID")
}

# Picks a simulator UDID: SIMULATOR_NAME on the newest iOS runtime, else any iPhone.
simulator_udid() {
  local json udid
  json="$(xcrun simctl list devices available -j)"
  udid="$(echo "$json" | jq -r --arg name "${SIMULATOR_NAME:-}" '
      [.devices | to_entries[] | select(.key | test("iOS")) | .key as $rt | .value[] | . + {rt: $rt}] as $all
      | (($all | map(select(.name == $name)) | sort_by(.rt | split("iOS-")[1] | split("-") | map(tonumber)) | reverse) +
         ($all | map(select(.name | test("^iPhone"))) | sort_by(.rt | split("iOS-")[1] | split("-") | map(tonumber)) | reverse))
      | .[0].udid // empty')"
  [ -n "$udid" ] || die "no available iPhone simulator. Install an iOS runtime: xcodebuild -downloadPlatform iOS"
  echo "$udid"
}

# device_pick [name-or-id] → "<CoreDevice id>\t<UDID>\t<name>" for a paired, reachable iPhone or iPad.
# With no argument it takes the only one that's reachable. Exits 11 when no phone is ready, 64 when several are.
device_pick() {
  local want="${1:-}" json rows
  json="$(xcrun devicectl list devices --json-output - -q 2>/dev/null)" \
    || die "couldn't list devices. Try: xcrun devicectl list devices"
  rows="$(echo "$json" | jq -r '.result.devices[]
      | select(.hardwareProperties.reality == "physical" and .hardwareProperties.platform == "iOS")
      | [.identifier, (.hardwareProperties.udid // "-"), (.deviceProperties.name // "-"),
         (.connectionProperties.pairingState // "-"), (.connectionProperties.tunnelState // "-"),
         (.deviceProperties.developerModeStatus // "-")] | @tsv')"
  local id udid name pairing tunnel devmode state known="" ready="" picked="" count=0 mode="-"
  while IFS=$'\t' read -r id udid name pairing tunnel devmode; do
    [ -n "$id" ] || continue
    state="paired"
    [ "$pairing" = paired ] || state="not paired"
    [ "$tunnel" != unavailable ] || state="$state, not reachable"
    known="$known
      $name ($state)"
    if [ -n "$want" ] && [ "$want" != "$name" ] && [ "$want" != "$id" ] && [ "$want" != "$udid" ]; then continue; fi
    if [ "$state" != paired ]; then continue; fi
    count=$((count + 1))
    ready="$ready
      $name"
    picked="$id	$udid	$name"
    mode="$devmode"
  done <<EOF
$rows
EOF
  if [ "$count" = 0 ]; then
    local msg="no phone is ready"
    [ -z "$want" ] || msg="no phone named '$want' is ready"
    [ -z "$known" ] || msg="$msg. Phones this Mac knows:$known
   "
    die "$msg
    Once per phone:
      1. Connect it to this Mac with a cable, unlock it, and tap Trust.
      2. Turn on Developer Mode: Settings → Privacy & Security → Developer Mode (the phone restarts).
    After that it also works over Wi-Fi on the same network." 11
  fi
  [ "$count" = 1 ] || die "several phones are ready. Pick one with --device=<name> or DEVICE_NAME:$ready" 64
  [ "$mode" != disabled ] \
    || die "Developer Mode is off on ${picked##*	}. Turn it on in Settings → Privacy & Security → Developer Mode (the phone restarts), then run again." 11
  echo "$picked"
}

hex_component() { # hex_component "#RRGGBB" <0|1|2> → 0xRR
  local hex="${1#\#}"
  echo "0x${hex:$(( $2 * 2 )):2}"
}
