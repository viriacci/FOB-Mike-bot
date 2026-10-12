# FOB Mike Bot — kontekst do nowego czatu

## Projekt
Bot Discord „FOB Mike” dla Wojska Stolicy. Integruje Discord z Firebase/Firestore i istniejącą stroną WWW.

Główne moduły:
- Magazyn
- Księga wejść/wyjść
- Informacje i notatki strażników
- Skrytka bankowa
- Audit Logs
- role/uprawnienia
- persistent views

## Co zostało zrobione
Od Segmentu 1 przeprowadzono pełny audyt kodu, poprawki i testy:
- pełny audyt `bot.py`
- usunięcie dead code i duplikatów
- poprawa obsługi wyjątków i async
- timeouty Firestore
- zabezpieczenia retry/idempotencji
- testy regresyjne
- testy integracyjne na fake Firestore
- fuzzing parserów
- testy wartości granicznych
- ponowny pełny re-audit po poprawkach

## Magazyn
- przyjęcia i wydania
- historia
- sprawdzanie stanu
- `/ile` do 5 przedmiotów
- autocomplete
- stacki/sztuki
- zabezpieczenie przed wydaniem większej ilości niż dostępna
- retry nie tworzy podwójnej operacji

## Brama
- wejścia i wyjścia
- blokowanie podwójnego aktywnego wejścia
- lista obecnych
- historia
- informacje/notatki strażników
- retry bez duplikatów

## Skrytka
- saldo
- wpłaty/wypłaty
- kontrola środków
- planowane wydatki
- propozycje wydatków
- zatwierdzanie/odrzucanie
- zaległe płatności
- archiwizacja opłaconych wpisów
- świeży odczyt salda
- retry bez podwójnych zmian

## Audit Logs
- filtrowanie po module/użytkowniku/okresie
- dzisiaj / wczoraj / 7 dni
- poprawione daty
- uwzględnianie późniejszych edycji i decyzji
- deduplikacja
- jawny błąd przy przekroczeniu limitu zamiast cichego obcinania wyników

## Uprawnienia
Role:
- Magazynier
- Strażnik
- Oficer ochrony
- Skarbnik
- Zarządca
- Minister

Zasady:
- Zarządca: pełny dostęp
- Minister: read-only
- konfiguracja ról: owner
- `@everyone` nie może być rolą uprzywilejowaną

## Discord
- persistent views działają po restarcie
- usunięto wadliwe `delete_after`
- naprawiono rekurencję `send_private_followup`
- bot używa `discord.Client + app_commands.CommandTree`
- nie wymaga Message Content Intent

## Wdrożenie
VPS:
- host: `lee125.mikrus.xyz`
- SSH port: `10125`
- katalog: `/opt/wojsko-discord-bot`
- systemd: `wojsko-bot.service`
- użytkownik systemowy: `wojsko-bot`

Środowisko:
- Python 3.12.3
- discord.py 2.7.1
- firebase-admin 7.7.0

Discord:
- bot: `FOB Mike`
- bot/app ID: `1557299195784724520`
- guild ID: `1556375242530885662`
- serwer: `WOJSKOWY SYSTEM ŁĄCZNOŚCI`

Firebase:
- projekt: `wojsko-stolicy-magazyn`

Sekrety pozostają tylko na VPS:
- `.env`
- `serviceAccount.json`

## Deployment
Przygotowano:
- staging
- backup
- automatyczny rollback
- ręczny rollback
- `preflight.py`
- `diagnostics.sh`
- deploy z Windows
- hardening systemd

## Produkcyjny preflight
Preflight został uruchomiony na VPS i zakończył się:

`PREFLIGHT: OK`

Potwierdzono:
- Python OK
- discord.py OK
- Firebase service account OK
- Firestore OK
- 1505 pozycji w `minecraft_items.json`
- token Discord OK
- właściwy guild OK

## Ważne ograniczenia architektury
1. Bot i WWW są osobnymi klientami Firestore.
2. `BANK_WRITE_LOCK` zabezpiecza tylko proces bota.
3. Pełna historia operacji WWW nie jest zawsze możliwa do odtworzenia po usunięciu wpisów.
4. Globalna unikalność wpisu Bramy między WWW i botem wymaga wspólnego mechanizmu transakcyjnego.
5. Saldo bankowe jest nadal liczone z historii `bankTransactions`.

# AKTUALNY PROBLEM DO NAPRAWY

## `[ENCH]`
Obecnie każdy przedmiot jest traktowany jako mający wariant zaklęty.

To jest błędne.

Wariant `[ENCH]` ma istnieć TYLKO dla:
- zbroi
- broni
- narzędzi
- złotych jabłek

Oznaczenie musi być na końcu nazwy:
- `Diamentowy miecz`
- `Diamentowy miecz [ENCH]`
- `Diamentowy kilof`
- `Diamentowy kilof [ENCH]`
- `Diamentowy hełm`
- `Diamentowy hełm [ENCH]`
- `Złote jabłko`
- `Złote jabłko [ENCH]`

Przedmioty typu:
- bruk
- deski
- żelazo
- węgiel
- redstone
- kamień
- zwykłe jedzenie

NIE mogą mieć wariantu `[ENCH]`.

## Co zrobić w następnym czacie
1. Zlokalizować logikę generującą warianty enchanted.
2. Sprawdzić `minecraft_items.json`.
3. Sprawdzić autocomplete `/ile`.
4. Zrobić whitelistę/regułę enchantowalnych typów.
5. Ujednolicić regułę dla Magazynu, `/ile`, autocomplete, historii, Firestore i wyświetlania nazw.
6. Dodać testy regresyjne.
7. Zbudować hotfix.
8. Wdrożyć na VPS.
9. Dokończyć smoke test.

## Stan końcowy rozmowy
Nie zaczynać audytu od początku.

Kontynuować od:
`naprawa [ENCH] -> test regresyjny -> build hotfix -> deployment -> końcowy smoke test`

Hash przeaudytowanej wersji `bot.py` sprzed poprawki `[ENCH]`:

`49eef5d45867a89c25633586cf1181d1ef4cd9c05b567733fd37767dc047a42f`
