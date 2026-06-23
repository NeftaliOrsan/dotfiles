#!/usr/bin/env bash
# ~/.config/hypr/scripts/wallpaper.sh
# Aplica el fondo a CADA monitor conectado via IPC de hyprpaper.
#
# Por que existe: la imagen es 4K (3840x2160) y el 'preload' de hyprpaper es
# asincrono. Al arrancar, hyprpaper evalua los monitores antes de que la imagen
# termine de cargar, y los 'wallpaper =' del config quedan "has no target".
# Aplicarlo por IPC (cuando la imagen ya esta lista) si funciona.
#
# Requisitos: hyprpaper corriendo (el autostart lo lanza antes que esto) y su
# hyprpaper.conf hace el 'preload' de la imagen. Tambien sirve para tus modos
# de monitor (clamshell/hibrido/movil): aplica a los que esten presentes.
set -u
IMG="/home/neftalir/Pictures/wallpapers/summer-night.png"

# 1) Esperar a que hyprpaper responda por IPC (hasta ~5s)
for _ in $(seq 1 50); do
  hyprctl hyprpaper listactive >/dev/null 2>&1 && break
  sleep 0.1
done

# 2) Aplicar a cada monitor conectado (sin jq: se parsea 'hyprctl monitors').
#    Reintentar por si la imagen aun se esta precargando.
for mon in $(hyprctl monitors | awk '/^Monitor/ {print $2}'); do
  for _ in $(seq 1 50); do
    hyprctl hyprpaper wallpaper "$mon,$IMG" >/dev/null 2>&1 && break
    sleep 0.1
  done
done
