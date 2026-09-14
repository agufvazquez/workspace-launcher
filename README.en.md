# workspace-launcher

🌐 [Español](README.md)

A script that opens VS Code and a terminal for each service in your stack
(frontend, backend, whatever), configured via a JSON file. Meant to avoid
retyping the same startup commands every time.

Detects at runtime whether it's running on **WSL**, **native Linux**, or
**macOS** and adapts how it opens the terminal window accordingly.

## Requirements

- `bash`
- [`jq`](https://jqlang.org/) (`sudo apt install jq` / `brew install jq`)
- VS Code's `code` CLI on your PATH (`code --install-shell-command` from
  VS Code if you don't have it)
- WSL: `cmd.exe` and `wsl.exe` reachable (available by default)
- Native Linux: some terminal emulator installed (gnome-terminal,
  konsole, xfce4-terminal, alacritty, kitty, or xterm)
- macOS: `osascript` (available by default) and Terminal.app

## Installation

```bash
git clone <this-repo> ~/workspace-launcher
cd ~/workspace-launcher
cp config.example.json config.json
chmod +x workspace-launcher.sh
```

Edit `config.json` with your own projects (see schema below). This file
is in `.gitignore`.

## Usage

```bash
# start every service in config.json
./workspace-launcher.sh

# start only the given services (by "name")
./workspace-launcher.sh my-frontend

# list configured service names
./workspace-launcher.sh --list
```

Tip: add an alias in your `.zshrc`/`.bashrc`:

```bash
alias start="~/workspace-launcher/workspace-launcher.sh"
```

## `config.json` schema

```jsonc
{
  // command used to open the editor (default: "code")
  "editor_cmd": "code",

  // terminal emulator to use on native Linux, or "auto" to
  // autodetect (default: "auto")
  "linux_terminal": "auto",

  "services": [
    {
      "name": "my-frontend",          // unique id, used on the CLI
      "dir": "~/projects/my-frontend",// project directory (supports ~)
      "shell": "zsh",                 // shell to use in the terminal (default: bash)
      "setup": ["nvm use 20"],        // commands to run before "run" (optional)
      "run": "yarn start",            // main command to run
      "editor": true,                 // open VS Code on dir (default: true)
      "terminal": true                // open a terminal running "run" (default: true)
    }
  ]
}
```

The matching `~/.<shell>rc` (`~/.zshrc`, `~/.bashrc`, etc.) is sourced
automatically before running `setup` and `run`, so there's no need to
repeat it in `setup`.

## How platform support works

- **WSL**: detected via `/proc/version` or `$WSL_DISTRO_NAME`. Opens the
  terminal with `cmd.exe /c start "" wsl.exe -e <shell> <launcher>`.
- **Native Linux**: detected via `uname -s`. Autodetects the first
  available terminal emulator from a known list, or uses whatever you
  set in `linux_terminal`.
- **macOS**: detected via `uname -s`. Opens a new Terminal.app window
  with `osascript` and runs the launcher there.

## How it works internally

For each service, it generates a temporary launcher script at
`/tmp/workspace-launcher_<name>.sh` that sources your rc file, `cd`s
into the directory, runs `setup` + `run`, and leaves the shell open at
the end (`exec $shell`). It then opens the editor and the terminal
according to the detected platform.

## Tests

```bash
./tests/test_macos.sh
```

Mocks `uname`, `grep`, and `osascript` to validate platform detection
and the Terminal.app command it builds, without needing to run on
macOS.
