#!/usr/bin/env bash
# ~/.config/hypr/scripts/wake-monitors.sh
# Se ejecuta al RESUMIR de suspend (after_sleep_cmd de hypridle). Tareas:
#  1) Re-evaluar pantallas con lid.sh sync (estado REAL de la tapa; nunca headless).
#  2) Re-pintar el fondo (wallpaper.sh): los outputs pueden renacer "nuevos".
#  3) Auto-sanacion: relanza hyprlock/waybar si murieron al reinicializarse los
#     outputs en el resume (cascada portal+hyprlock+waybar). Ver bloque al final.
#
# NO reenciende pantallas: el DPMS dispatch (hl.dsp.dpms) TUMBA waybar y rompe la
# sesion en este equipo, asi que esta PROHIBIDO aqui. Hyprland reactiva los externos
# por su cuenta al resumir; la tapa la maneja lid.sh por evento (Lid Switch).
#
# OJO (config Lua): nada de 'hyprctl keyword'. Se usa 'hyprctl eval' + hl.monitor.
set -u
# 1) Re-evaluar pantallas: misma logica que arranque/hotplug. lid.sh sync mira el
#    estado REAL de la tapa: cerrada+externos -> eDP-1 off; si no -> eDP-1 on (no headless).
/home/neftalir/.config/hypr/scripts/lid.sh sync

# 2) Re-pintar el fondo: tras el resume los outputs pueden renacer sin wallpaper.
/home/neftalir/.config/hypr/scripts/wallpaper.sh

# --- Auto-sanacion tras resume -------------------------------------------------
# En este equipo, al reinicializarse los outputs en el resume pueden abortar los
# clientes sensibles a outputs (xdg-desktop-portal-hyprland, hyprlock, waybar).
# Si alguno murio, lo relanzamos UNA vez (sin bucle, para no entrar en crash-loop).
# hyprlock re-ancla el lock vivo gracias a misc.allow_session_lock_restore = true
# (en hyprland.lua). NO se usa dpms ni se señaliza waybar: solo se lanza uno nuevo.
#
# Se lanzan DIRECTO con 'setsid -f', NO con 'hyprctl dispatch exec': bajo config Lua
# ese dispatch se traduce a Lua invalido (return hl.dispatch(exec hyprlock)) y aborta
# con "')' expected near 'hyprlock'". Ese bug fue por el que el resume del 25-jun NO
# relanzo el locker tras un crash de hyprlock y hubo que reiniciar a mano.
sleep 1   # dar margen a que los outputs se estabilicen antes de relanzar
pidof hyprlock >/dev/null || setsid -f hyprlock >/dev/null 2>&1
pidof waybar   >/dev/null || setsid -f waybar -c /home/neftalir/.config/waybar/hyperos/config -s /home/neftalir/.config/waybar/hyperos/style.css >/dev/null 2>&1
