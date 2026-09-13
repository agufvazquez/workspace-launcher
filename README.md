# workspace-launcher

🌐 [English](README.en.md)

Un script que abre VS Code y una terminal por cada servicio de tu stack
(frontend, backend, lo que sea), configurado en un JSON. Pensado para no
repetir siempre los mismos comandos de arranque.

Detecta en tiempo de ejecución si corre sobre **WSL** o **Linux nativo** y
adapta cómo abre la ventana de terminal en cada caso.

## Requisitos

- `bash`
- [`jq`](https://jqlang.org/) (`sudo apt install jq` / `brew install jq`)
- El CLI `code` de VS Code en el PATH (`code --install-shell-command` desde
  VS Code si no lo tenés)
- WSL: `cmd.exe` y `wsl.exe` accesibles (vienen por defecto)
- Linux nativo: algún emulador de terminal instalado (gnome-terminal,
  konsole, xfce4-terminal, alacritty, kitty o xterm)

## Instalación

```bash
git clone <este-repo> ~/workspace-launcher
cd ~/workspace-launcher
cp config.example.json config.json
chmod +x workspace-launcher.sh
```

Editá `config.json` con tus proyectos (ver esquema abajo). Este archivo
está en `.gitignore`.

## Uso

```bash
# levanta todos los servicios de config.json
./workspace-launcher.sh

# levanta solo los servicios indicados (por "name")
./workspace-launcher.sh my-frontend

# lista los nombres de servicios configurados
./workspace-launcher.sh --list
```

Tip: agregá un alias en tu `.zshrc`/`.bashrc`:

```bash
alias start="~/workspace-launcher/workspace-launcher.sh"
```

## Esquema de `config.json`

```jsonc
{
  // comando para abrir el editor (default: "code")
  "editor_cmd": "code",

  // emulador de terminal a usar en Linux nativo, o "auto" para
  // autodetectar (default: "auto")
  "linux_terminal": "auto",

  "services": [
    {
      "name": "my-frontend",          // identificador único, usado en la CLI
      "dir": "~/projects/my-frontend",// directorio del proyecto (soporta ~)
      "shell": "zsh",                 // shell a usar en la terminal (default: bash)
      "setup": ["nvm use 20"],        // comandos previos al run (opcional)
      "run": "yarn start",            // comando principal a correr
      "editor": true,                 // abrir VS Code en dir (default: true)
      "terminal": true                // abrir terminal con el run (default: true)
    }
  ]
}
```

El `~/.<shell>rc` correspondiente (`~/.zshrc`, `~/.bashrc`, etc.) se
sourcea automáticamente antes de correr `setup` y `run`, así que no hace
falta repetirlo en `setup`.

## Cómo agrega soporte de plataformas

- **WSL**: se detecta vía `/proc/version` o `$WSL_DISTRO_NAME`. Abre la
  terminal con `cmd.exe /c start "" wsl.exe -e <shell> <launcher>`.
- **Linux nativo**: se detecta vía `uname -s`. Autodetecta el primer
  emulador de terminal disponible de una lista conocida, o usa el que
  configures en `linux_terminal`.
- **macOS**: no soportado todavía (queda como próximo paso natural,
  usando `osascript`/`open -a Terminal`).

## Cómo funciona por dentro

Por cada servicio, genera un script lanzador temporal en
`/tmp/workspace-launcher_<name>.sh` que sourcea tu rc, hace `cd` al
directorio, corre `setup` + `run`, y deja la shell abierta al final
(`exec $shell`). Después abre el editor y la terminal según la
plataforma detectada.
