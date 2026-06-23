#!/usr/bin/env bash
#
# btmenu.sh — menú wofi para conectar/desconectar dispositivos Bluetooth.
# Gemelo de wifimenu.sh, pero con bluetoothctl en vez de nmcli.
#
# Uso:  btmenu.sh <tema> [args-extra-wofi]
#   $1 = nombre del tema en ~/.config/wofi/themes/<tema>.css   (ej. everforest)
#   $2 = argumentos extra opcionales para wofi                 (ej. "--height=30%")
#
# Requiere: bluez/bluez-utils (bluetoothctl), wofi, notify-send (dunst).

THEME="${1:-everforest}"
WOFI_ARGS="$2"
STYLE="$HOME/.config/wofi/themes/${THEME}.css"

# Helper: lanza wofi en modo dmenu con tu tema. $1 = texto del prompt.
# -j (--hide-search): sin barra de búsqueda; se navega con flechas/clic.
menu() {
    wofi $WOFI_ARGS -i -j -d --style "$STYLE" --prompt "$1"
}

# Estado del controlador: ¿está encendido el Bluetooth? (Powered: yes/no)
powered=$(bluetoothctl show | awk '/Powered:/ {print $2; exit}')

if [ "$powered" = "yes" ]; then
    TOGGLE="󰂲  Apagar Bluetooth"
else
    TOGGLE="󰂯  Encender Bluetooth"
fi

# Lista de dispositivos conocidos. bluetoothctl devices imprime:
#   Device AA:BB:CC:DD:EE:FF  Nombre del dispositivo
# Marcamos con ✓ los que están conectados ahora mismo.
device_list() {
    bluetoothctl devices | while read -r _ mac name; do
        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            echo "✓  $name"
        else
            echo "   $name"
        fi
    done
}

# Si está apagado, solo tiene sentido ofrecer encenderlo.
if [ "$powered" = "yes" ]; then
    CHOICE=$(printf '%s\n%s\n%s\n' "$TOGGLE" "󰂰  Escanear (5s)" "$(device_list)" | menu "Bluetooth: ")
else
    CHOICE=$(printf '%s\n' "$TOGGLE" | menu "Bluetooth: ")
fi

# Si cerró wofi con Esc, no hay elección: salir limpio.
[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    *"Encender Bluetooth")
        bluetoothctl power on ;;

    *"Apagar Bluetooth")
        bluetoothctl power off ;;

    *"Escanear (5s)")
        notify-send -t 5000 "Bluetooth" "Escaneando dispositivos (5s)…"
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1
        # Relanzar el menú para mostrar lo que apareció.
        exec "$0" "$THEME" "$WOFI_ARGS" ;;

    *)
        # Quitar el prefijo (✓ o espacios) para quedarnos con el nombre puro,
        # y resolver su MAC buscando ese nombre en la lista de bluetoothctl.
        name=$(printf '%s' "$CHOICE" | sed 's/^[✓[:space:]]*//')
        mac=$(bluetoothctl devices | grep -F "$name" | head -n1 | awk '{print $2}')
        [ -z "$mac" ] && exit 0

        if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
            bluetoothctl disconnect "$mac" \
                && notify-send "Bluetooth" "Desconectado: $name"
        else
            # Por si es un dispositivo nuevo: emparejar + confiar antes de conectar.
            # (Si ya estaba emparejado, estos comandos no hacen daño.)
            bluetoothctl pair  "$mac" >/dev/null 2>&1
            bluetoothctl trust "$mac" >/dev/null 2>&1
            if bluetoothctl connect "$mac" >/dev/null 2>&1; then
                notify-send "Bluetooth" "Conectado: $name"
            else
                notify-send -u critical "Bluetooth" "No se pudo conectar a $name"
            fi
        fi ;;
esac
