#!/usr/bin/env bash
# Tests para el soporte de macOS de workspace-launcher.sh.
# No requieren estar corriendo en macOS: mockean `uname`, `grep` y
# `osascript` con binarios falsos puestos primero en el PATH.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_DIR="$(dirname -- "$SCRIPT_DIR")"

FAILED=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc (esperado: '$expected', obtenido: '$actual')"
    FAILED=1
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ok - $desc"
  else
    echo "FAIL - $desc (no se encontró '$needle' en: $haystack)"
    FAILED=1
  fi
}

MOCK_BIN="$(mktemp -d)"
OSASCRIPT_LOG="$(mktemp)"
trap 'rm -rf "$MOCK_BIN" "$OSASCRIPT_LOG"' EXIT

cat >"$MOCK_BIN/uname" <<'EOF'
#!/usr/bin/env bash
echo "Darwin"
EOF

cat >"$MOCK_BIN/grep" <<'EOF'
#!/usr/bin/env bash
# Simula un /proc/version que no menciona "microsoft" (i.e. no-WSL).
exit 1
EOF

cat >"$MOCK_BIN/osascript" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$OSASCRIPT_LOG"
EOF

chmod +x "$MOCK_BIN"/uname "$MOCK_BIN"/grep "$MOCK_BIN"/osascript

export PATH="$MOCK_BIN:$PATH"
unset WSL_DISTRO_NAME 2>/dev/null || true

# shellcheck source=/dev/null
source "$REPO_DIR/workspace-launcher.sh"

assert_eq "detect_platform detecta macOS cuando uname=Darwin y no hay indicios de WSL" \
  "macos" "$(detect_platform)"

launch_terminal_macos "/tmp/workspace-launcher_demo \"raro\".sh"

CALLS="$(cat "$OSASCRIPT_LOG")"
assert_contains "launch_terminal_macos invoca a Terminal.app" "$CALLS" 'tell application "Terminal" to do script'
assert_contains "launch_terminal_macos activa Terminal.app" "$CALLS" 'tell application "Terminal" to activate'
assert_contains "launch_terminal_macos escapa comillas del launcher" "$CALLS" '\"raro\"'

if [[ "$FAILED" -eq 0 ]]; then
  echo "Todos los tests pasaron."
else
  echo "Hay tests fallidos."
fi
exit "$FAILED"
