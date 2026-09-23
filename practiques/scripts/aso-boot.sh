#!/bin/bash
#
# aso-boot.sh — script executat com a root per aso.service en arrencar aso.target.
# Porta un comptador d'arrencades i deixa un "banner" a /etc/motd amb l'estat
# de la màquina en aquell moment (target actiu, IP, kernel, uptime...).

set -e

LOGFILE="/var/log/aso-boot.log"
COUNTFILE="/var/lib/aso/boot-count"
MOTDFILE="/etc/motd"

mkdir -p "$(dirname "$COUNTFILE")"

if [ -f "$COUNTFILE" ]; then
    COUNT=$(($(cat "$COUNTFILE") + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTFILE"

HOST=$(hostname)
KERNEL=$(uname -r)
DATA=$(date '+%Y-%m-%d %H:%M:%S')
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
TARGET=$(systemctl get-default)
PUJADA=$(uptime -p)

echo "[$DATA] Arrencada #$COUNT - target=$TARGET - host=$HOST - ip=${IP:-cap} - kernel=$KERNEL" >> "$LOGFILE"

cat > "$MOTDFILE" <<EOF

╔══════════════════════════════════════════════╗
  ASO · $HOST
  Target actiu:    $TARGET
  Arrencada núm.:  $COUNT
  Data:            $DATA
  Kernel:          $KERNEL
  IP:              ${IP:-(sense xarxa)}
  Uptime:          $PUJADA
╚══════════════════════════════════════════════╝

EOF

exit 0
