#!/usr/bin/env bash
# workspace-launcher: abre VS Code y una terminal por cada servicio definido
# en config.json. Detecta en tiempo de ejecución si corre sobre WSL o Linux
# nativo y adapta cómo abre la terminal.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"

usage() {
  cat <<EOF
Uso: $(basename "$0") [servicio ...] | --list

Sin argumentos levanta todos los servicios de config.json.
Pasando nombres levanta solo esos servicios (deben existir en config.json).
--list muestra los nombres de servicios configurados.
EOF
}

if [[ ! -f "$CONFIG_FILE" ]]; then
  if [[ -f "$SCRIPT_DIR/config.example.json" ]]; then
    echo "No se encontró config.json. Copiá config.example.json y editalo:" >&2
    echo "  cp \"$SCRIPT_DIR/config.example.json\" \"$SCRIPT_DIR/config.json\"" >&2
  else
    echo "No se encontró config.json ni config.example.json en $SCRIPT_DIR" >&2
  fi
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Este script necesita 'jq' instalado (sudo apt install jq / brew install jq)." >&2
  exit 1
fi

EDITOR_CMD="$(jq -r '.editor_cmd // "code"' "$CONFIG_FILE")"
LINUX_TERMINAL_CFG="$(jq -r '.linux_terminal // "auto"' "$CONFIG_FILE")"

# --- Detección de plataforma ---
detect_platform() {
  if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    echo "wsl"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "linux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

PLATFORM="$(detect_platform)"

expand_path() {
  local p="$1"
  echo "${p/#\~/$HOME}"
}

pick_linux_terminal() {
  if [[ "$LINUX_TERMINAL_CFG" != "auto" ]]; then
    echo "$LINUX_TERMINAL_CFG"
    return
  fi
  for term in x-terminal-emulator gnome-terminal konsole xfce4-terminal alacritty kitty xterm; do
    if command -v "$term" &>/dev/null; then
      echo "$term"
      return
    fi
  done
  echo ""
}

launch_terminal_linux() {
  local launcher="$1"
  local term
  term="$(pick_linux_terminal)"
  if [[ -z "$term" ]]; then
    echo "No se encontró un emulador de terminal soportado. Configurá 'linux_terminal' en config.json." >&2
    return 1
  fi
  case "$term" in
    gnome-terminal) gnome-terminal -- "$launcher" & ;;
    konsole) konsole -e "$launcher" & ;;
    xfce4-terminal) xfce4-terminal --command="$launcher" & ;;
    alacritty) alacritty -e "$launcher" & ;;
    kitty) kitty "$launcher" & ;;
    xterm) xterm -e "$launcher" & ;;
    x-terminal-emulator) x-terminal-emulator -e "$launcher" & ;;
    *) "$term" -e "$launcher" & ;;
  esac
}

launch_terminal_wsl() {
  local launcher="$1" shell="$2"
  cmd.exe /c start "" wsl.exe -e "$shell" "$launcher"
}

build_launcher() {
  local name="$1" dir="$2" shell="$3" run="$4" setup_json="$5"
  local launcher_path="/tmp/workspace-launcher_${name}.sh"

  {
    echo "#!/usr/bin/env $shell"
    if [[ -f "$HOME/.${shell}rc" ]]; then
      echo "source \"$HOME/.${shell}rc\""
    fi
    echo "cd \"$dir\""
    jq -r '.[]' <<<"$setup_json"
    echo "$run"
    echo "exec $shell"
  } >"$launcher_path"

  chmod +x "$launcher_path"
  echo "$launcher_path"
}

start_service() {
  local service_json="$1"
  local name dir shell run editor terminal setup

  name="$(jq -r '.name' <<<"$service_json")"
  dir="$(expand_path "$(jq -r '.dir' <<<"$service_json")")"
  shell="$(jq -r '.shell // "bash"' <<<"$service_json")"
  run="$(jq -r '.run' <<<"$service_json")"
  editor="$(jq -r '.editor // true' <<<"$service_json")"
  terminal="$(jq -r '.terminal // true' <<<"$service_json")"
  setup="$(jq -c '.setup // []' <<<"$service_json")"

  if [[ ! -d "$dir" ]]; then
    echo "[$name] directorio no existe: $dir (salteo)" >&2
    return
  fi

  echo "[$name] plataforma=$PLATFORM dir=$dir"

  if [[ "$editor" == "true" ]]; then
    "$EDITOR_CMD" "$dir"
  fi

  if [[ "$terminal" == "true" ]]; then
    local launcher
    launcher="$(build_launcher "$name" "$dir" "$shell" "$run" "$setup")"
    case "$PLATFORM" in
      wsl) launch_terminal_wsl "$launcher" "$shell" ;;
      linux) launch_terminal_linux "$launcher" ;;
      *) echo "[$name] plataforma '$PLATFORM' no soportada todavía." >&2 ;;
    esac
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

mapfile -t ALL_NAMES < <(jq -r '.services[].name' "$CONFIG_FILE")

if [[ "${1:-}" == "--list" ]]; then
  printf '%s\n' "${ALL_NAMES[@]}"
  exit 0
fi

if [[ $# -gt 0 ]]; then
  SELECTED=("$@")
else
  SELECTED=("${ALL_NAMES[@]}")
fi

for name in "${SELECTED[@]}"; do
  service_json="$(jq -c --arg n "$name" '.services[] | select(.name == $n)' "$CONFIG_FILE")"
  if [[ -z "$service_json" ]]; then
    echo "Servicio '$name' no encontrado en config.json" >&2
    continue
  fi
  start_service "$service_json"
done
