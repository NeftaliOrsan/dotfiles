#!/usr/bin/env bash
# ~/.config/hypr/scripts/lid.sh
# Maneja la tapa de la laptop según los monitores externos conectados.
#   close + >=1 externo  -> apaga eDP-1, NO suspende, NO bloquea (clamshell / híbrido)
#   close + 0 externos   -> bloquea + suspende (modo móvil)
#   open                 -> reactiva eDP-1
#
# OJO: con config en Lua, 'hyprctl keyword' NO funciona ("non-legacy parser").
# Hay que usar 'hyprctl eval' con la API hl.monitor():
#   - deshabilitar -> disabled = true
#   - re-habilitar -> disabled = false  (si no se pone, se queda apagado)
set -eu

INTERNAL="eDP-1"

# Cuenta líneas "Monitor ..." que NO son la pantalla interna = externos activos
ext_count() {
  hyprctl monitors | awk -v internal="$INTERNAL" '/^Monitor/ && $2 != internal {n++} END {print n+0}'
}

# True (exit 0) si la tapa esta FISICAMENTE cerrada (lee /proc, no depende de eventos).
lid_is_closed() { grep -qi closed /proc/acpi/button/lid/*/state 2>/dev/null; }

disable_internal() {
  hyprctl eval "hl.monitor({ output = \"$INTERNAL\", disabled = true })"
}

enable_internal() {
  hyprctl eval "hl.monitor({ output = \"$INTERNAL\", disabled = false, mode = \"preferred\", position = \"auto\", scale = \"auto\" })"
}

case "${1:-}" in
  close)
    if [ "$(ext_count)" -gt 0 ]; then
      # Hay externos: solo apaga la pantalla interna y sigue trabajando
      disable_internal
    else
      # Sin externos: bloquea (-> hypridle -> hyprlock) y suspende a RAM
      loginctl lock-session
      systemctl suspend
    fi
    ;;
  open)
    # Reactiva la pantalla interna
    enable_internal
    ;;
  sync)
    # Re-evalua pantallas con el estado REAL de la tapa, SIN efectos secundarios
    # (NO bloquea ni suspende). Se llama al arrancar, al resumir y en hotplug.
    if lid_is_closed && [ "$(ext_count)" -gt 0 ]; then
      disable_internal   # clamshell: tapa cerrada + externos
    else
      enable_internal    # nunca headless: tapa abierta, o cerrada sin externos
    fi
    ;;
esac
