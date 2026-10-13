#!/bin/bash
# shellcheck disable=SC2016  # Literal shell syntax is intentional test data.
# Offline regression tests. The fixture never reads the developer's mainline settings.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/mainline-tests.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo" "$fixture/bin" "$fixture/home" "$fixture/work"
cp -R "$root/bin" "$root/lib" "$root/config" "$root/templates" "$fixture/repo/"
export MAINLINE_HOME="$fixture/home"
export MAINLINE_CONFIG="$MAINLINE_HOME/config.env" MAINLINE_CREDENTIALS="$MAINLINE_HOME/credentials.env"
unset ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID MAINLINE_APPS || true
cli="$fixture/repo/bin/mainline"
helpers="$fixture/repo/tools/MainlineTools/.build/release"
mkdir -p "$helpers" "$fixture/repo/tools/MainlineTools/Sources"
touch "$fixture/repo/tools/MainlineTools/Package.swift"
cat > "$helpers/appicon" <<'STUB'
#!/bin/bash
mkdir -p "$(dirname "$2")"
touch "$2"
STUB
cat > "$helpers/asc" <<'STUB'
#!/bin/bash
if [ "$1" = bundle-id ]; then exit 1; fi
if [ "$1" = app ]; then echo should-not-be-looked-up >> "$MAINLINE_HOME/lookup"; echo 123; fi
STUB
chmod +x "$helpers/asc" "$helpers/appicon"
touch "$helpers/.mainline-built"
cat > "$fixture/bin/xcodegen" <<'STUB'
#!/bin/bash
mkdir -p "$APP_NAME.xcodeproj"
echo '// generated fixture' > "$APP_NAME.xcodeproj/project.pbxproj"
STUB
cat > "$fixture/bin/xcrun" <<'STUB'
#!/bin/bash
if [ "${1:-}" = simctl ]; then
  cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-9":[{"name":"iPhone Test","udid":"older"}],"com.apple.CoreSimulator.SimRuntime.iOS-26-10":[{"name":"iPhone Test","udid":"newer"}]}}
JSON
elif [ "${1:-} ${2:-} ${3:-}" = "devicectl list devices" ]; then cat "$MAINLINE_HOME/devices.json"
else exit 1; fi
STUB
printf '#!/bin/bash\nexit 1\n' > "$fixture/bin/xcodebuild"
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
cd "$fixture/work"
checks=0
expect_exit() {
  local expected="$1" actual=0; shift
  /bin/bash "$cli" "$@" >"$fixture/stdout" 2>"$fixture/stderr" || actual=$?
  if [ "$actual" != "$expected" ]; then
    cat "$fixture/stderr" >&2
    echo "FAIL: $* returned $actual, expected $expected" >&2; exit 1
  fi
  checks=$((checks + 1))
}
for option in --team --prefix --tester --key --key-id --issuer; do expect_exit 64 setup "$option"; done
for option in --name --symbol --from --to --dir; do expect_exit 64 new demo "$option"; done
expect_exit 64 run --wait
expect_exit 64 run --wait -1
expect_exit 64 test --only
expect_exit 64 new demo --from '#nope'
expect_exit 64 new demo --name $'Two\nLines'
[ ! -e demo ]
expect_exit 0 setup --prefix com.example.tests --issuer old-issuer
expect_exit 0 setup --issuer ''
# shellcheck disable=SC1090
. "$MAINLINE_CREDENTIALS"
[ -z "$ASC_ISSUER_ID" ]
# Deliberate shell metacharacters must round-trip without being executed.
value='o'\''tester"$(touch injected)`touch injected2`\@example.com'
expect_exit 0 setup --tester "$value"
# shellcheck disable=SC1090
. "$MAINLINE_CONFIG"
[ "$TESTER_EMAILS" = "$value" ] && [ ! -e injected ] && [ ! -e injected2 ]
expect_exit 0 setup --tester 'replacement@example.com'
# shellcheck disable=SC1090
. "$MAINLINE_CONFIG"
[ "$TESTER_EMAILS" = replacement@example.com ]
name='It'\''s My "Quotes" $HOME $(touch injected) `touch injected2` \(literal)'
expect_exit 0 new quoted --name "$name"
# shellcheck disable=SC1091
. quoted/app.env
[ "$DISPLAY_NAME" = "$name" ] && [ "$ASC_APP_NAME" = "$name" ]
[ ! -e injected ] && [ ! -e injected2 ]
grep -F 'It'\''s My \"Quotes\" $HOME $(touch injected) `touch injected2` \\(literal)' quoted/Sources/ContentView.swift >/dev/null
# app.env stays readable: single-quoted values, the template's comments kept.
grep -q "^DISPLAY_NAME='It'.*# name shown under the home-screen icon$" quoted/app.env
[ ! -s "$fixture/stdout" ]
expect_exit 64 new quoted
# Accents fold into the Swift target name; a name with no Latin letters falls back to the slug.
expect_exit 0 new creme --name 'Crème Brûlée Straße'
grep -q '^APP_NAME=CremeBruleeStrasse ' creme/app.env
expect_exit 0 new tokyo-trip --name '東京'
grep -q '^APP_NAME=TokyoTrip ' tokyo-trip/app.env
# Failure inside command substitution must stop before app lookup or build/upload.
printf 'ASC_KEY_ID=TESTKEY\nASC_KEY_PATH=%q\nDEVELOPMENT_TEAM=ABCDE12345\n' "$fixture/key.p8" > "$MAINLINE_CREDENTIALS"
touch "$fixture/key.p8"
expect_exit 1 ship quoted
[ ! -e "$MAINLINE_HOME/lookup" ]
# run --device: which phone, and when the human has to step in (exit 11).
phone() { # phone <name> <pairing> <tunnel> <developer mode>
  printf '{"identifier":"id-%s","hardwareProperties":{"reality":"physical","platform":"iOS","udid":"udid-%s"},"deviceProperties":{"name":"%s","developerModeStatus":"%s"},"connectionProperties":{"pairingState":"%s","tunnelState":"%s"}}' \
    "$1" "$1" "$1" "$4" "$2" "$3"
}
devices() { local IFS=,; printf '{"result":{"devices":[%s]}}' "$*" > "$MAINLINE_HOME/devices.json"; }
simulated='{"identifier":"sim","hardwareProperties":{"reality":"simulated","platform":"iOS","udid":"sim"},"deviceProperties":{"name":"iPhone 17 Pro"},"connectionProperties":{"pairingState":"paired","tunnelState":"connected"}}'
devices "$simulated"
expect_exit 11 run quoted --device
devices "$simulated" "$(phone Away paired unavailable enabled)" "$(phone New unpaired disconnected enabled)"
expect_exit 11 run quoted --device
grep -q 'Away (paired, not reachable)' "$fixture/stderr" && grep -q 'New (not paired)' "$fixture/stderr"
devices "$(phone Mine paired disconnected disabled)"
expect_exit 11 run quoted --device
grep -q 'Developer Mode is off on Mine' "$fixture/stderr"
devices "$(phone One paired connected enabled)" "$(phone Two paired disconnected enabled)"
expect_exit 64 run quoted --device
expect_exit 11 run quoted --device=Three
expect_exit 1 run quoted --device=Two     # picked; the stub xcodebuild then fails the build
grep -q 'Building .* for Two' "$fixture/stderr"
echo "DEVICE_NAME=udid-One" >> "$MAINLINE_CONFIG"
expect_exit 1 run quoted --device
grep -q 'Building .* for One' "$fixture/stderr"
expect_exit 64 run quoted --device --show
expect_exit 64 run quoted --device=
# shellcheck disable=SC1091
. "$root/lib/common.sh"
SIMULATOR_NAME='iPhone Test'
[ "$(simulator_udid)" = newer ]
# Private settings stay private even under a permissive caller umask.
[ "$(find "$MAINLINE_HOME" -name '*.env' -perm -004 | wc -l | tr -d ' ')" = 0 ]
printf 'Passed %s CLI checks, plus quoting, registration failure, permissions, and simulator and phone selection.\n' "$checks"
