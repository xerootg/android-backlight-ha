# android-backlight-ha

Turn the hardware LCD backlight of a rooted Android device into a **dimmable
Home Assistant light**. Built for old Android-based panels (POS terminals, wall
tablets, kiosks) whose backlight is a standard Linux `sysfs` node but which
have no usable app-level brightness control.

A tiny `busybox httpd` server on the device writes the kernel backlight node;
Home Assistant drives it with `wget` from a template light. No app, no cloud,
no companion-app push required.

## How it works

The device exposes one CGI endpoint on port 8099:

| Request | Effect |
|---|---|
| `GET /cgi-bin/bl?v=0..255` | set brightness (writes `brightness`) |
| `GET /cgi-bin/bl?on` | power the panel on (`bl_power` = 0) |
| `GET /cgi-bin/bl?off` | blank the panel (`bl_power` = 4) |
| `GET /cgi-bin/bl?q=state` | returns `ON <level>` or `OFF <level>` |

It targets `/sys/class/backlight/backlight/{brightness,bl_power}`. Change the
`N=` path in `device/cgi-bin/bl` if your panel is on a different node (check
`/sys/class/backlight/`).

## Requirements

- Root (the CGI and the boot service run as root).
- A backlight exposed under `/sys/class/backlight/`.
- `busybox` on the device with the `httpd` applet (common on these panels).
- To install the boot-autostart service, `/system` must be remountable
  read-write. On locked/verity devices skip `backlightd.rc` and start the
  server another way (Magisk service, Termux boot, etc.).
- SELinux permissive helps; under enforcing you may need a policy exception for
  httpd to read/write the backlight node and exec from `/data`.

## Install (over adb)

```bash
./install.sh 192.168.1.50          # device IP; :5555 assumed
```

This remounts `/system`, pushes the CGI and the init service, starts the
server, and prints a health check. The service restarts the server on every
boot via `on property:sys.boot_completed=1`.

## Home Assistant

Copy `homeassistant/configuration.snippet.yaml` into your `configuration.yaml`,
replace `DEVICE_IP`, and restart. You get `light.panel_lcd`: on/off plus a
brightness slider. `wget` ships in the Home Assistant core container.

## Notes and caveats

- **Brightness floor.** Most of these panels round brightness to coarse PWM
  steps and never reach 0; the slider bottom stays dim. True off uses
  `bl_power`, which the on/off toggle (not the slider) triggers.
- **Two backlight nodes.** Some panels expose `backlight` and `backlight1`;
  pick whichever drives the screen.
- **Security.** The endpoint is unauthenticated HTTP. Keep the device on a
  trusted VLAN and pin its IP (DHCP reservation). Anyone on the LAN can set the
  brightness.
- **State lag.** Home Assistant polls state every 30 s; control is instant, the
  reported level catches up on the next poll.

## Origin

Extracted from a Rockchip RK3288 Android 8.1 POS panel used as a Home Assistant
wall display. The backlight is a PWM-driven LVDS panel; this bridge made it a
dimmable light in the entry hallway without touching the (ancient) OS.
