# dotfiles

Configuración de mi entorno en **Arch Linux + Hyprland**. Gestionado como
**bare repo** de git (los archivos viven en su sitio dentro de `~`, no se
mueven ni se symlinkean).

## Qué incluye

| Carpeta | Qué es |
|---|---|
| `.config/hypr` | Hyprland (config en **Lua**, `hl.*` API), hypridle, hyprlock, hyprpaper, scripts |
| `.config/waybar` | Barra. Temas `everforest` (original) y `hyperos` (frosted glass) |
| `.config/wofi` | Lanzador y menús (wifi, bluetooth, powermenu, emoji). Temas por `$1` |
| `.config/dunst` | Notificaciones |
| `.config/kitty` | Terminal |
| `.config/gtk-3.0` | Tema GTK |

## Cómo se usa (bare repo)

El repo vive en `~/.dotfiles` y se opera con un alias `dots` en lugar de `git`:

```sh
alias dots='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

Operaciones normales:

```sh
dots status            # ver cambios (solo archivos ya rastreados)
dots add .config/hypr/hyprland.lua
dots commit -m "..."
dots push
```

## Clonar en una máquina nueva

```sh
git clone --bare git@github.com:USUARIO/dotfiles.git $HOME/.dotfiles
alias dots='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dots config status.showUntrackedFiles no
dots checkout            # si hay conflictos, respalda los archivos que choquen y reintenta
```

## Notas

- Hyprland aquí usa **config Lua**, no `.conf` legacy: `hyprctl keyword`/`reload`
  son poco fiables; aplicar cambios recargando Hyprland con el método propio.
- waybar se recarga **solo** con `kill -9` + relanzar una instancia (bug de IPC
  self-join en este build → SIGABRT con SIGTERM/SIGUSR2).
