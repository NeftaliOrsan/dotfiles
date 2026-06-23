#!/bin/bash

# Cada entrada: un <span> Pango que pinta el fondo SOLO detrás del glifo
# (los espacios dentro del span le dan aire = badge). El texto va fuera del span.
# Los colores del badge dependen del tema ($1): HyperOS (azul/rojo/slate, glifo
# blanco) vs everforest (pasteles, original). Solo cambia la paleta, no la lógica.
case "$1" in
  hyperos*)
    # HyperOS: azul = primario, rojo = destructivo (shutdown), grises neutros.
    entries="<span background='#4084ff' foreground='#ffffff'>  ⭮  </span>  Reboot\n<span background='#ff5b6a' foreground='#ffffff'>  ⏻  </span>  Shutdown\n<span background='#8a93a6' foreground='#ffffff'>  ⇠  </span>  Logout\n<span background='#5b6b8a' foreground='#ffffff'>  ⏾  </span>  Suspend"
    ;;
  *)
    # everforest (original)
    entries="<span background='#83c092' foreground='#2d353b'>  ⭮  </span>  Reboot\n<span background='#e67e80' foreground='#2d353b'>  ⏻  </span>  Shutdown\n<span background='#d699b6' foreground='#2d353b'>  ⇠  </span>  Logout\n<span background='#7fbbb3' foreground='#d3c6aa'>  ⏾  </span>  Suspend"
    ;;
esac

selected=$(echo -e "$entries"|wofi -m --width 300 --height 310 --dmenu $2 --style ~/.config/wofi/themes/$1.css --hide-search --hide-scroll --cache-file /dev/null | awk '{print tolower($NF)}')

case $selected in
  logout)
    exec hyprctl dispatch exit NOW;;
  suspend)
    exec systemctl suspend;;
  reboot)
    exec systemctl reboot;;
  shutdown)
    exec systemctl poweroff -i;;
esac