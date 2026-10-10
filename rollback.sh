#!/usr/bin/env bash
set -euo pipefail

BACKUP_PATH="${1:-}"
APP_DIR="/opt/wojsko-discord-bot"
SERVICE_FILE="/etc/systemd/system/wojsko-bot.service"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Uruchom jako root."
  exit 1
fi

if [[ -z "$BACKUP_PATH" || ! -f "$BACKUP_PATH" ]]; then
  echo "Użycie:"
  echo "  $0 /root/wojsko-bot-backups/wojsko-bot-RRRRMMDD-HHMMSS.tar.gz"
  exit 1
fi

echo "Zatrzymuję usługę..."
systemctl stop wojsko-bot || true

echo "Usuwam pliki bieżącej wersji z zachowaniem .env, serviceAccount.json i .venv..."
find "$APP_DIR" \
  -mindepth 1 \
  -maxdepth 1 \
  ! -name '.env' \
  ! -name 'serviceAccount.json' \
  ! -name '.venv' \
  -exec rm -rf {} +

echo "Przywracam backup..."
tar -xzf "$BACKUP_PATH" -C "$APP_DIR"

if [[ -f "$APP_DIR/requirements.txt" ]]; then
  if [[ ! -x "$APP_DIR/.venv/bin/pip" ]]; then
    echo "Brak istniejącego venv. Nie mogę odtworzyć zależności automatycznie."
    exit 1
  fi
  "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
fi

if [[ -f "$APP_DIR/wojsko-bot.service" ]]; then
  cp "$APP_DIR/wojsko-bot.service" "$SERVICE_FILE"
fi

systemctl daemon-reload
systemctl restart wojsko-bot
sleep 2

systemctl status wojsko-bot --no-pager -l
echo
journalctl -u wojsko-bot -n 60 --no-pager -l
echo
echo "ROLLBACK: zakończony."
