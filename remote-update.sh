#!/usr/bin/env bash
set -euo pipefail

ZIP_PATH="${1:-/root/wojsko-discord-bot-final-audited.zip}"
APP_DIR="/opt/wojsko-discord-bot"
BACKUP_DIR="/root/wojsko-bot-backups"
SERVICE_FILE="/etc/systemd/system/wojsko-bot.service"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/wojsko-bot-$STAMP.tar.gz"
STAGING_DIR="/tmp/wojsko-bot-release-$STAMP"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Uruchom jako root."
  exit 1
fi

for command in python3 unzip tar systemctl runuser; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Brak wymaganego polecenia: $command"
    exit 1
  fi
done

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Brak paczki: $ZIP_PATH"
  exit 1
fi

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$APP_DIR" "$BACKUP_DIR" "$STAGING_DIR"

echo "Rozpakowuję paczkę do staging..."
unzip -q "$ZIP_PATH" -d "$STAGING_DIR"

for required in \
  bot.py \
  minecraft_items.json \
  requirements.txt \
  wojsko-bot.service \
  install.sh \
  preflight.py \
  rollback.sh \
  diagnostics.sh
do
  if [[ ! -f "$STAGING_DIR/$required" ]]; then
    echo "Paczka jest niekompletna. Brak: $required"
    exit 1
  fi
done

echo "Waliduję paczkę przed dotknięciem działającej wersji..."
python3 -m py_compile "$STAGING_DIR/bot.py" "$STAGING_DIR/preflight.py"
rm -rf "$STAGING_DIR/__pycache__"
bash -n "$STAGING_DIR/install.sh"
bash -n "$STAGING_DIR/rollback.sh"
bash -n "$STAGING_DIR/diagnostics.sh"

python3 - "$STAGING_DIR/minecraft_items.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
if not isinstance(data, list) or not data:
    raise SystemExit("minecraft_items.json nie zawiera niepustej listy.")

ids = []
for row in data:
    if not isinstance(row, dict) or not str(row.get("id") or "").strip():
        raise SystemExit("minecraft_items.json zawiera rekord bez ID.")
    ids.append(str(row["id"]))

if len(ids) != len(set(ids)):
    raise SystemExit("minecraft_items.json zawiera zduplikowane ID.")
PY

HAS_BACKUP=0

if [[ -f "$APP_DIR/bot.py" ]]; then
  echo "Tworzę backup kodu: $BACKUP_PATH"
  tar \
    --exclude='.venv' \
    --exclude='.env' \
    --exclude='serviceAccount.json' \
    --exclude='__pycache__' \
    -czf "$BACKUP_PATH" \
    -C "$APP_DIR" .
  HAS_BACKUP=1
else
  BACKUP_PATH=""
  echo "Pierwsza instalacja: brak poprzedniego bot.py do backupu."
fi

rollback_code() {
  if [[ "$HAS_BACKUP" -ne 1 ]]; then
    echo "Brak poprzedniej wersji do automatycznego rollbacku."
    return 1
  fi

  echo
  echo "Przywracam poprzednią wersję z:"
  echo "  $BACKUP_PATH"

  systemctl stop wojsko-bot || true

  find "$APP_DIR" \
    -mindepth 1 \
    -maxdepth 1 \
    ! -name '.env' \
    ! -name 'serviceAccount.json' \
    ! -name '.venv' \
    -exec rm -rf {} +

  tar -xzf "$BACKUP_PATH" -C "$APP_DIR"

  if [[ -f "$APP_DIR/requirements.txt" && -x "$APP_DIR/.venv/bin/pip" ]]; then
    "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
  fi

  if [[ -f "$APP_DIR/wojsko-bot.service" ]]; then
    cp "$APP_DIR/wojsko-bot.service" "$SERVICE_FILE"
  fi

  systemctl daemon-reload
  systemctl restart wojsko-bot
  sleep 2

  systemctl status wojsko-bot --no-pager -l || true
}

echo "Podmieniam pliki aplikacji..."
find "$APP_DIR" \
  -mindepth 1 \
  -maxdepth 1 \
  ! -name '.env' \
  ! -name 'serviceAccount.json' \
  ! -name '.venv' \
  -exec rm -rf {} +

cp -a "$STAGING_DIR"/. "$APP_DIR"/
chmod +x \
  "$APP_DIR/install.sh" \
  "$APP_DIR/preflight.py" \
  "$APP_DIR/rollback.sh" \
  "$APP_DIR/diagnostics.sh"

echo "Uruchamiam instalację/aktualizację..."
if ! "$APP_DIR/install.sh"; then
  echo "BŁĄD instalacji."
  rollback_code || true
  exit 1
fi

echo
echo "Sprawdzam usługę..."
if ! systemctl is-active --quiet wojsko-bot; then
  echo "BŁĄD: usługa nie jest aktywna po wdrożeniu."
  systemctl status wojsko-bot --no-pager -l || true
  journalctl -u wojsko-bot -n 120 --no-pager -l || true
  rollback_code || true
  exit 1
fi

echo "Usługa jest aktywna."

echo
echo "Uruchamiam preflight sieci/Firebase/Discord..."
set +e
runuser -u wojsko-bot -- \
  "$APP_DIR/.venv/bin/python" \
  "$APP_DIR/preflight.py"
PREFLIGHT_RC=$?
set -e

if [[ "$PREFLIGHT_RC" -ne 0 ]]; then
  echo
  echo "UWAGA: usługa działa, ale preflight nie przeszedł."
  echo "Nie wykonuję automatycznego rollbacku, bo przyczyną może być chwilowa awaria sieci."
  echo "Sprawdź:"
  echo "  journalctl -u wojsko-bot -n 150 --no-pager -l"
  if [[ "$HAS_BACKUP" -eq 1 ]]; then
    echo "Backup poprzedniej wersji:"
    echo "  $BACKUP_PATH"
  fi
  exit "$PREFLIGHT_RC"
fi

echo
systemctl status wojsko-bot --no-pager -l
echo
journalctl -u wojsko-bot -n 40 --no-pager -l

echo
echo "WDROŻENIE: OK"
if [[ "$HAS_BACKUP" -eq 1 ]]; then
  echo "Backup poprzedniej wersji:"
  echo "  $BACKUP_PATH"
fi
