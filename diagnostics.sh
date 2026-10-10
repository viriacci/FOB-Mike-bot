#!/usr/bin/env bash
set -uo pipefail

APP_DIR="/opt/wojsko-discord-bot"
SERVICE="wojsko-bot"
FAILURES=0

section() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

ok() {
  echo "OK:   $1"
}

section "USŁUGA"
if systemctl is-active --quiet "$SERVICE"; then
  ok "systemd: active"
else
  fail "systemd: usługa nie jest active"
fi

systemctl show "$SERVICE" \
  -p ActiveState \
  -p SubState \
  -p MainPID \
  -p NRestarts \
  -p ExecMainStatus \
  --no-pager || true

section "PLIKI I INTEGRALNOŚĆ"

if [[ ! -f "$APP_DIR/bot.py" ]]; then
  fail "brak bot.py"
else
  ACTUAL_SHA="$(sha256sum "$APP_DIR/bot.py" | awk '{print $1}')"
  echo "bot.py SHA256: $ACTUAL_SHA"

  EXPECTED_SHA=""
  if [[ -f "$APP_DIR/BUILD_INFO.txt" ]]; then
    EXPECTED_SHA="$(sed -n 's/^bot.py SHA256: //p' "$APP_DIR/BUILD_INFO.txt" | head -n 1)"
  fi

  if [[ -n "$EXPECTED_SHA" ]]; then
    echo "expected SHA256: $EXPECTED_SHA"
    if [[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]]; then
      ok "bot.py zgadza się z BUILD_INFO"
    else
      fail "bot.py NIE zgadza się z BUILD_INFO"
    fi
  else
    fail "BUILD_INFO.txt nie zawiera oczekiwanego SHA256"
  fi
fi

for secret_file in ".env" "serviceAccount.json"; do
  path="$APP_DIR/$secret_file"

  if [[ ! -f "$path" ]]; then
    fail "brak $secret_file"
    continue
  fi

  mode="$(stat -c '%a' "$path" 2>/dev/null || echo '?')"
  owner="$(stat -c '%U:%G' "$path" 2>/dev/null || echo '?')"
  echo "$secret_file -> mode=$mode owner=$owner"

  if [[ "$mode" == "640" || "$mode" == "600" ]]; then
    ok "$secret_file nie jest world-readable"
  else
    fail "$secret_file ma nieoczekiwane prawa $mode"
  fi
done

section "PYTHON I ZALEŻNOŚCI"

if [[ -x "$APP_DIR/.venv/bin/python" ]]; then
  "$APP_DIR/.venv/bin/python" --version || fail "nie można uruchomić Pythona z venv"

  "$APP_DIR/.venv/bin/python" - <<'PY'
from importlib.metadata import version

for package in ("discord.py", "firebase-admin", "python-dotenv", "tzdata"):
    try:
        print(f"{package}={version(package)}")
    except Exception as exc:
        print(f"{package}=ERROR:{exc}")
PY
else
  fail "brak .venv/bin/python"
fi

section "PREFLIGHT"

if [[ -x "$APP_DIR/.venv/bin/python" && -f "$APP_DIR/preflight.py" ]]; then
  if runuser -u wojsko-bot -- \
    "$APP_DIR/.venv/bin/python" \
    "$APP_DIR/preflight.py"
  then
    ok "preflight przeszedł"
  else
    fail "preflight nie przeszedł"
  fi
else
  fail "nie można uruchomić preflight.py"
fi

section "OSTATNIE LOGI"
journalctl -u "$SERVICE" -n 100 --no-pager -l || true

section "WYNIK"
if [[ "$FAILURES" -eq 0 ]]; then
  echo "DIAGNOSTYKA: OK"
  exit 0
fi

echo "DIAGNOSTYKA: $FAILURES problem(y)"
exit 1
