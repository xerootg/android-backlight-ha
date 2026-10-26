#!/usr/bin/env bash
# Install the backlight HTTP bridge onto a rooted Android device over adb.
# Usage: ./install.sh <device-ip>[:port]   (adb must already be authorized)
set -euo pipefail
DEV="${1:?usage: install.sh <device-ip[:port]>}"
case "$DEV" in *:*) : ;; *) DEV="$DEV:5555" ;; esac

adb connect "$DEV"
adb -s "$DEV" root >/dev/null 2>&1 || true
adb connect "$DEV" >/dev/null 2>&1 || true

# Find the system block device and remount read-write (handles the busybox
# explicit-device case where a bare `mount -o remount,rw /system` fails).
SYS_DEV=$(adb -s "$DEV" shell 'grep " /system " /proc/mounts | cut -d" " -f1' | tr -d '\r')
REAL=$(adb -s "$DEV" shell "readlink -f $SYS_DEV" | tr -d '\r')
adb -s "$DEV" shell "busybox mount -o remount,rw $REAL /system"

# Push the server content and the boot service.
adb -s "$DEV" shell 'mkdir -p /data/bl/cgi-bin'
adb -s "$DEV" push device/cgi-bin/bl /data/bl/cgi-bin/bl
adb -s "$DEV" shell 'chmod 0755 /data/bl/cgi-bin/bl'
adb -s "$DEV" push device/backlightd.rc /system/etc/init/backlightd.rc
adb -s "$DEV" shell 'chmod 0644 /system/etc/init/backlightd.rc'
adb -s "$DEV" shell "busybox mount -o remount,ro $REAL /system"

# Start it now (also autostarts on boot via the init service).
adb -s "$DEV" shell '/system/bin/busybox httpd -p 8099 -h /data/bl'
sleep 1
echo -n "health: "; adb -s "$DEV" shell 'busybox wget -qO- http://127.0.0.1:8099/cgi-bin/bl'
echo
echo "Done. Endpoint: http://${DEV%:*}:8099/cgi-bin/bl  (?on ?off ?v=0..255 ?q=state)"
