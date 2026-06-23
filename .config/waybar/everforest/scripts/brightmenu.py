#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
brightmenu — panel flotante de brillo (rice everforest).
- Pantalla interna (eDP-1) vía brightnessctl (logind, sin root).
- Monitores externos vía ddcutil (VCP 0x10) SI está instalado y con permisos i2c.
  Si ddcutil no está o no detecta nada, simplemente no aparecen (Fase A = solo interno).

Lanzar desde el on-click de waybar (toggle):
  pkill -f brightmenu.py || python3 ~/.config/waybar/everforest/scripts/brightmenu.py
"""
import gi, subprocess, shutil, threading, re
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib

GLib.set_prgname("brightmenu")  # -> app_id/class en Wayland (para la windowrule de Hypr)

# ----------------------------------------------------------------------------- backends
class InternalBackend:
    """Brillo del panel interno por brightnessctl (usa logind, no escribe sysfs)."""
    def __init__(self, device="intel_backlight", label="Interno  ·  eDP-1"):
        self.device = device
        self.label = label

    def get(self):
        try:
            cur = int(subprocess.check_output(
                ["brightnessctl", "-m", "-d", self.device, "get"], text=True).strip())
            mx = int(subprocess.check_output(
                ["brightnessctl", "-m", "-d", self.device, "max"], text=True).strip())
            return max(1, round(100 * cur / mx)) if mx else 100
        except Exception:
            return 100

    def set(self, pct):
        # min 1% para no apagar el panel por completo
        subprocess.Popen(["brightnessctl", "-d", self.device, "set", f"{max(1, pct)}%"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class ExternalBackend:
    """Brillo de un monitor externo por ddcutil (DDC/CI, VCP 0x10). Lento -> throttle."""
    def __init__(self, display, label, maxval=100):
        self.display = str(display)
        self.label = label
        self.maxval = maxval or 100

    def get(self):
        try:
            out = subprocess.check_output(
                ["ddcutil", "--display", self.display, "--brief", "getvcp", "10"],
                text=True, timeout=8)
            # formato breve: "VCP 10 C <cur> <max>"
            parts = out.split()
            cur, mx = int(parts[3]), int(parts[4])
            self.maxval = mx or 100
            return max(1, round(100 * cur / self.maxval))
        except Exception:
            return 50

    def set(self, pct):
        val = round(max(1, pct) * self.maxval / 100)
        subprocess.Popen(["ddcutil", "--display", self.display, "setvcp", "10", str(val)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def detect_external_backends():
    """Devuelve backends externos vía 'ddcutil detect'. Vacío si no hay ddcutil/permisos."""
    if not shutil.which("ddcutil"):
        return []
    try:
        out = subprocess.check_output(["ddcutil", "detect", "--brief"],
                                      text=True, timeout=12, stderr=subprocess.DEVNULL)
    except Exception:
        return []
    backends, disp, name = [], None, None
    for line in out.splitlines():
        m = re.match(r"\s*Display\s+(\d+)", line)
        if m:
            if disp is not None:
                backends.append(ExternalBackend(disp, name or f"Externo {disp}"))
            disp, name = m.group(1), None
        elif "Monitor:" in line:
            # "Monitor: MFG:MODELO:SERIE" -> nos quedamos con el modelo
            try:
                name = line.split("Monitor:")[1].strip().split(":")[1].strip()
            except Exception:
                name = None
    if disp is not None:
        backends.append(ExternalBackend(disp, name or f"Externo {disp}"))
    return backends

# ----------------------------------------------------------------------------- throttle
class Throttle:
    """Coalesce escrituras: a lo sumo una cada interval_ms (trailing). Para DDC lento."""
    def __init__(self, interval_ms, fn):
        self.interval, self.fn = interval_ms, fn
        self.pending, self.source = None, None

    def push(self, val):
        self.pending = val
        if self.source is None:
            self.source = GLib.timeout_add(self.interval, self._flush)

    def _flush(self):
        if self.pending is not None:
            self.fn(self.pending)
            self.pending = None
            return True   # sigue mientras lleguen valores
        self.source = None
        return False      # sin pendientes -> deja de tickear

# ----------------------------------------------------------------------------- UI
CSS = b"""
window { background-color:#2d353b; border:2px solid #3d484d; border-radius:14px; }
.title { color:#a7c080; font-size:15px; font-weight:bold; margin-bottom:4px; }
.mon   { color:#9da9a0; font-size:12px; }
.pct   { color:#d3c6aa; font-size:13px; font-weight:bold; }
scale trough    { background-color:#3d484d; border-radius:8px; min-height:8px; }
scale highlight { background-color:#a7c080; border-radius:8px; }
scale slider    { background-color:#d3c6aa; border-radius:50%;
                  min-width:18px; min-height:18px; margin:-7px; }
"""


class BrightRow:
    def __init__(self, backend):
        self.backend = backend
        self.throttle = Throttle(30 if isinstance(backend, InternalBackend) else 150,
                                 backend.set)

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        name = Gtk.Label(label=backend.label, xalign=0)
        name.get_style_context().add_class("mon")
        self.box.pack_start(name, False, False, 0)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        self.scale.set_value(backend.get())
        self.scale.connect("value-changed", self._on_change)
        row.pack_start(self.scale, True, True, 0)

        self.pct = Gtk.Label(label=f"{int(self.scale.get_value())}%")
        self.pct.get_style_context().add_class("pct")
        self.pct.set_width_chars(4)
        row.pack_start(self.pct, False, False, 0)

        self.box.pack_start(row, False, False, 0)

    def _on_change(self, scale):
        v = int(scale.get_value())
        self.pct.set_text(f"{v}%")
        self.throttle.push(v)


class BrightWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="brightmenu")
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)
        self.set_default_size(320, -1)
        self._had_focus = False

        prov = Gtk.CssProvider()
        prov.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER)

        self.outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.outer.set_margin_top(16)
        self.outer.set_margin_bottom(16)
        self.outer.set_margin_start(18)
        self.outer.set_margin_end(18)
        self.add(self.outer)

        title = Gtk.Label(label="\U000f0335  Brillo", xalign=0)  # 󰌵 -> usa icono nf
        title.get_style_context().add_class("title")
        self.outer.pack_start(title, False, False, 0)

        # fila interna (siempre)
        self.outer.pack_start(BrightRow(InternalBackend()).box, False, False, 0)

        # externos: detectar en hilo aparte (ddcutil es lento) y agregar al volver
        threading.Thread(target=self._load_external, daemon=True).start()

        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self._on_key)
        self.connect("focus-in-event", self._on_focus_in)
        self.connect("focus-out-event", self._on_focus_out)

    def _load_external(self):
        backends = detect_external_backends()
        if backends:
            GLib.idle_add(self._add_external, backends)

    def _add_external(self, backends):
        for b in backends:
            self.outer.pack_start(BrightRow(b).box, False, False, 0)
        self.show_all()
        return False

    def _on_key(self, _w, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def _on_focus_in(self, *_):
        self._had_focus = True

    def _on_focus_out(self, *_):
        # cerrar al hacer clic fuera (solo si ya habíamos recibido foco)
        if self._had_focus:
            self.destroy()


if __name__ == "__main__":
    win = BrightWindow()
    win.show_all()
    Gtk.main()
