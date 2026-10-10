#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/wojsko-discord-bot"
SERVICE_FILE="/etc/systemd/system/wojsko-bot.service"
SERVICE_USER="wojsko-bot"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Uruchom install.sh jako root."
  exit 1
fi

cd "$APP_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Brak python3 na serwerze."
  exit 1
fi

if ! python3 -m venv --help >/dev/null 2>&1; then
  echo "Brak modułu venv. Na Ubuntu zainstaluj: apt install python3-venv"
  exit 1
fi

if ! id "$SERVICE_USER" >/dev/null 2>&1; then
  useradd \
    --system \
    --home-dir "$APP_DIR" \
    --shell /usr/sbin/nologin \
    "$SERVICE_USER"
fi

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi

.venv/bin/python -m pip install --upgrade pip
.venv/bin/pip install -r requirements.txt

.venv/bin/python -m py_compile bot.py
.venv/bin/python - <<'PY'
import json
from pathlib import Path

items = Path("minecraft_items.json")
with items.open("r", encoding="utf-8") as fh:
    data = json.load(fh)

if not isinstance(data, list) or not data:
    raise SystemExit("minecraft_items.json nie zawiera poprawnej, niepustej listy.")

service = Path("serviceAccount.json")
if service.exists():
    with service.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if payload.get("type") != "service_account":
        raise SystemExit("serviceAccount.json nie wygląda jak klucz konta usługi Firebase.")
PY

cp "$APP_DIR/wojsko-bot.service" "$SERVICE_FILE"
systemctl daemon-reload

chown -R root:"$SERVICE_USER" "$APP_DIR"
chmod -R o-rwx "$APP_DIR"
chmod -R g+rX "$APP_DIR"

if [[ -f "$APP_DIR/.env" && -f "$APP_DIR/serviceAccount.json" ]]; then
  chmod 640 "$APP_DIR/.env" "$APP_DIR/serviceAccount.json"

  systemctl enable wojsko-bot
  systemctl restart wojsko-bot

  sleep 2
  echo
  echo "Bot został uruchomiony."
  systemctl --no-pager --full status wojsko-bot || true
else
  echo
  echo "Kod zainstalowany, ale bot NIE został uruchomiony."
  echo "Brakuje .env lub serviceAccount.json."
  echo "Po dodaniu plików wykonaj:"
  echo "  chown root:wojsko-bot /opt/wojsko-discord-bot/.env /opt/wojsko-discord-bot/serviceAccount.json"
  echo "  chmod 640 /opt/wojsko-discord-bot/.env /opt/wojsko-discord-bot/serviceAccount.json"
  echo "  systemctl enable --now wojsko-bot"
fi
