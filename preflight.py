#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import credentials, firestore


BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"OK:   {message}")


def require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        fail(f"Brak {name} w .env.")
    return value


def positive_int(name: str) -> int:
    raw = require_env(name)
    try:
        value = int(raw)
    except ValueError:
        fail(f"{name} nie jest liczbą całkowitą.")
    if value <= 0:
        fail(f"{name} musi być dodatnie.")
    return value


def discord_get(path: str, token: str) -> dict:
    request = Request(
        f"https://discord.com/api/v10{path}",
        headers={
            "Authorization": f"Bot {token}",
            "User-Agent": "WojskoStolicyPreflight/1.0",
        },
    )
    try:
        with urlopen(request, timeout=15) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:500]
        fail(f"Discord API HTTP {exc.code}: {body}")
    except URLError as exc:
        fail(f"Nie udało się połączyć z Discord API: {exc}")
    except Exception as exc:
        fail(f"Błąd Discord API: {type(exc).__name__}: {exc}")

    if not isinstance(payload, dict):
        fail("Discord API zwróciło nieoczekiwany format danych.")
    return payload


def main() -> None:
    print("Wojsko Stolicy — preflight")
    print("==========================")

    if sys.version_info < (3, 10):
        fail(f"Python {sys.version.split()[0]} jest zbyt stary.")
    ok(f"Python {sys.version.split()[0]}")

    try:
        discord_version = version("discord.py")
    except PackageNotFoundError:
        fail("Brak pakietu discord.py.")
    if discord_version != "2.7.1":
        fail(
            f"discord.py={discord_version}; oczekiwana wersja 2.7.1. "
            "Uruchom pip install -r requirements.txt."
        )
    ok(f"discord.py {discord_version}")

    token = require_env("DISCORD_TOKEN")
    owner_id = positive_int("OWNER_DISCORD_ID")
    guild_id = positive_int("DISCORD_GUILD_ID")
    ok(f"OWNER_DISCORD_ID={owner_id}")
    ok(f"DISCORD_GUILD_ID={guild_id}")

    service_account_path = Path(
        os.getenv(
            "FIREBASE_SERVICE_ACCOUNT",
            str(BASE_DIR / "serviceAccount.json"),
        ).strip()
    )
    if not service_account_path.is_file():
        fail(f"Brak service account: {service_account_path}")

    try:
        service_payload = json.loads(
            service_account_path.read_text(encoding="utf-8")
        )
    except Exception as exc:
        fail(f"Nie można odczytać serviceAccount.json: {exc}")

    if service_payload.get("type") != "service_account":
        fail("serviceAccount.json nie jest kluczem konta usługi.")
    project_id = str(service_payload.get("project_id") or "").strip()
    if not project_id:
        fail("serviceAccount.json nie zawiera project_id.")
    ok(f"Firebase service account: projekt {project_id}")

    items_path = BASE_DIR / "minecraft_items.json"
    try:
        items = json.loads(items_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"Nie można odczytać minecraft_items.json: {exc}")

    if not isinstance(items, list) or not items:
        fail("minecraft_items.json nie zawiera niepustej listy.")

    item_ids = [
        str(item.get("id") or "").strip()
        for item in items
        if isinstance(item, dict)
    ]
    if any(not item_id for item_id in item_ids):
        fail("minecraft_items.json zawiera pozycję bez ID.")
    if len(item_ids) != len(set(item_ids)):
        fail("minecraft_items.json zawiera zduplikowane ID przedmiotów.")
    ok(f"minecraft_items.json: {len(items)} pozycji")

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate(str(service_account_path))
        )
    db = firestore.client()

    try:
        db.collection("botConfig").document("preflight-check").get(timeout=15)
    except Exception as exc:
        fail(f"Firebase/Firestore nie odpowiada: {type(exc).__name__}: {exc}")
    ok("Firebase/Firestore: połączenie działa")

    bot_user = discord_get("/users/@me", token)
    bot_id = str(bot_user.get("id") or "")
    bot_name = str(bot_user.get("username") or "?")
    if not bot_id:
        fail("Token Discord nie zwrócił ID bota.")
    ok(f"Discord token: bot {bot_name} ({bot_id})")

    guild = discord_get(f"/guilds/{guild_id}", token)
    returned_guild_id = str(guild.get("id") or "")
    if returned_guild_id != str(guild_id):
        fail(
            f"Discord zwrócił inny guild ID: {returned_guild_id or 'brak'}."
        )
    ok(
        f"Bot ma dostęp do skonfigurowanego serwera: "
        f"{guild.get('name') or guild_id}"
    )

    print()
    print("PREFLIGHT: OK")


if __name__ == "__main__":
    main()
