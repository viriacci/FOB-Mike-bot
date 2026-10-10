WOJSKO STOLICY — DISCORD BOT
WERSJA FINAL AUDITED
Data audytu: 2026-10-07

ZAWARTOŚĆ
- bot.py — właściwy bot
- minecraft_items.json — baza przedmiotów Minecraft
- requirements.txt — zależności
- .env.example — wzór konfiguracji, BEZ sekretów
- wojsko-bot.service — jednostka systemd
- install.sh — instalacja/aktualizacja
- SMOKE_TEST.txt — test po wdrożeniu
- AUDIT_REPORT.txt — podsumowanie audytu
- .gitignore — blokada przypadkowego dodania sekretów do Git

WAŻNE
Paczka NIE zawiera:
- tokenu Discord
- .env
- serviceAccount.json

Nie dodawaj tych plików do GitHuba ani nie wysyłaj ich na Discord.

WYMAGANA KONFIGURACJA .env
DISCORD_TOKEN=...
OWNER_DISCORD_ID=...
DISCORD_GUILD_ID=...
FIREBASE_SERVICE_ACCOUNT=/opt/wojsko-discord-bot/serviceAccount.json

DISCORD_GUILD_ID jest wymagany. Bot celowo działa tylko na jednym
skonfigurowanym serwerze i odrzuca interakcje z innych guildów.

ROLE
- Magazynier
- Strażnik
- Oficer ochrony
- Skarbnik
- Zarządca
- Minister

Zarządca ma pełny dostęp.
Minister jest rolą odczytową zgodnie z macierzą modułów.
@everyone nie może zostać użyte jako rola logiczna.

MODUŁY
1. Magazyn
- Przyjmij / Wydaj
- stan jednego lub wielu przedmiotów
- zwykłe i zaklęte warianty
- historia
- /ile do 5 przedmiotów z autocomplete

2. Księga wejść i wyjść
- wejście / wyjście
- obecni
- historia
- informacje dla strażników
- notatki
- blokowanie podwójnego aktywnego wejścia po stronie bota

3. Skrytka
- saldo
- wpłata / wypłata
- potwierdzenie dużych operacji
- planowane wydatki
- propozycje wydatków
- zaległe płatności
- edycja i oznaczanie zaległości jako opłacone
- historia

4. Audit Logs
- Magazyn / Brama / Skrytka
- użytkownik
- dziś / wczoraj / 7 dni
- obsługa zdarzeń utworzonych i później edytowanych/rozpatrzonych
- jawny błąd zamiast cichego ucięcia raportu po przekroczeniu limitu

PRYWATNE ODPOWIEDZI
Odpowiedzi interakcji są ephemeral i bot usuwa je po około 120 sekundach.
Nie używa do tego problematycznego delete_after na interaction.followup.send.
Usuwanie odbywa się jawnie przez API Discorda.

ODPORNOŚĆ
- operacje krytyczne mają idempotency po interaction.id
- magazyn korzysta z transakcji Firestore
- wejścia/wyjścia i decyzje finansowe są odporne na retry bota
- Firestore ma deadline operacji
- blocking I/O jest ograniczone semaforem
- konfiguracja ma cache i okresowe odświeżanie
- startup ma retry Firestore
- Discord reconnect jest logowany
- persistent views działają po restarcie

SYSTEMD
Usługa działa jako dedykowany użytkownik `wojsko-bot`, a nie root.
Pliki .env i serviceAccount.json powinny mieć prawa 640 i grupę wojsko-bot.
Jednostka ma ograniczone capabilities i podstawowy hardening systemd.

INSTALACJA / AKTUALIZACJA
1. Wgraj zawartość paczki do:
   /opt/wojsko-discord-bot/

2. Zostaw istniejące:
   /opt/wojsko-discord-bot/.env
   /opt/wojsko-discord-bot/serviceAccount.json

3. Uruchom:
   chmod +x /opt/wojsko-discord-bot/install.sh
   /opt/wojsko-discord-bot/install.sh

Skrypt:
- utworzy użytkownika systemowego wojsko-bot, jeśli go nie ma,
- przygotuje/wykorzysta venv,
- zainstaluje zależności,
- sprawdzi składnię bot.py,
- sprawdzi JSON przedmiotów i klucza Firebase,
- zainstaluje service systemd,
- ustawi prawa plików,
- ZRESTARTUJE usługę, również przy aktualizacji.

LOGI
journalctl -u wojsko-bot -f

OSTATNIE 100 LINII
journalctl -u wojsko-bot -n 100 --no-pager -l

STATUS
systemctl status wojsko-bot --no-pager -l

ZNANE OGRANICZENIA ARCHITEKTONICZNE
1. Strona WWW i bot są osobnymi klientami Firestore.
   Pełna globalna atomowość wypłat WWW ↔ Discord wymaga wspólnego,
   transakcyjnego dokumentu salda albo jednego backendu zapisującego finanse.

2. Bot prowadzi własny dokładny audyt swoich operacji, ale pełny append-only
   audit zmian/usunięć wykonanych przez stronę WWW wymaga również zmian w WWW.

3. Przy bardzo dużej historii bankTransactions krytyczna operacja bankowa
   nadal musi przeliczyć całą historię, żeby pozostać zgodna z obecnym WWW.
   Docelowa migracja powinna wprowadzić bankMeta/balance aktualizowane
   transakcyjnie przez oba klienty.

TESTY
Kod przeszedł:
- pełny audyt AST całego pliku
- py_compile
- testy parserów i wartości granicznych
- testy inwariantów Discord/security
- 38 testów integracyjnych na emulatorze Firestore
- 5000 losowych wejść fuzz
- testy idempotency krytycznych operacji
- regresję audytu starych dokumentów
- ponowny pełny audyt po poprawkach

Po wdrożeniu wykonaj testy z SMOKE_TEST.txt.


BEZPIECZNE WDROŻENIE Z WINDOWS
W paczce są dodatkowo:
- deploy-windows.bat
- remote-update.sh
- rollback.sh
- preflight.py

Najprostsza ścieżka:
1. Umieść deploy-windows.bat, remote-update.sh i
   wojsko-discord-bot-final-audited.zip w tym samym katalogu.
2. Uruchom deploy-windows.bat.
3. Skrypt:
   - wyśle ZIP i remote-update.sh na VPS,
   - rozpakowuje nową wersję najpierw do staging,
   - waliduje składnię i bazę przedmiotów,
   - tworzy backup poprzedniego kodu,
   - zachowuje .env, serviceAccount.json i .venv,
   - aktualizuje aplikację,
   - uruchamia install.sh,
   - sprawdza systemd,
   - uruchamia preflight Firebase + Discord.
4. Błąd instalacji lub niedziałająca usługa powodują próbę automatycznego
   przywrócenia poprzedniego kodu.
5. Sam błąd preflight sieciowego nie robi automatycznego rollbacku,
   ponieważ mógłby być skutkiem chwilowej awarii Discorda/Firebase.

PREFLIGHT RĘCZNY
Na VPS:
  runuser -u wojsko-bot -- /opt/wojsko-discord-bot/.venv/bin/python /opt/wojsko-discord-bot/preflight.py

Preflight nie modyfikuje danych. Sprawdza:
- wersję Pythona i discord.py,
- wymagane zmienne .env,
- serviceAccount.json,
- unikalność ID w minecraft_items.json,
- odczyt Firestore,
- poprawność tokenu bota,
- dostęp bota do skonfigurowanego serwera Discord.

ROLLBACK RĘCZNY
remote-update.sh wypisuje ścieżkę utworzonego backupu.
Przywrócenie:
  /opt/wojsko-discord-bot/rollback.sh /root/wojsko-bot-backups/NAZWA_BACKUPU.tar.gz


DIAGNOSTYKA PO WDROŻENIU
Na VPS:
  /opt/wojsko-discord-bot/diagnostics.sh

Z Windows można użyć:
  diagnostics-windows.bat

Diagnostyka:
- sprawdza stan usługi i liczbę restartów,
- porównuje SHA256 wdrożonego bot.py z BUILD_INFO,
- sprawdza prawa .env i serviceAccount.json bez wyświetlania ich treści,
- pokazuje wersje zależności,
- uruchamia preflight Firebase/Discord,
- pokazuje ostatnie 100 linii logów.


UWAGA O NAZWIE ZIP
deploy-windows.bat może dostać paczkę jako parametr:
  deploy-windows.bat "C:\Users\viria\Downloads\wojsko-discord-bot-final-audited-seg12.zip"

Jeśli parametru nie podasz, skrypt sam szuka najpierw wersji `-seg12.zip`,
a potem wcześniejszej nazwy `wojsko-discord-bot-final-audited.zip`.
Na VPS paczka jest zawsze wysyłana pod stałą nazwą, więc remote-update.sh
nie zależy od lokalnej nazwy pobranego pliku.
