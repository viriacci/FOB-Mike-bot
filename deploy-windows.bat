@echo off
setlocal

set "HOST=lee125.mikrus.xyz"
set "PORT=10125"
set "REMOTE_SCRIPT=%~dp0remote-update.sh"

if not "%~1"=="" (
    set "ZIP=%~1"
) else (
    if exist "%~dp0wojsko-discord-bot-final-audited-seg12.zip" (
        set "ZIP=%~dp0wojsko-discord-bot-final-audited-seg12.zip"
    ) else (
        set "ZIP=%~dp0wojsko-discord-bot-final-audited.zip"
    )
)

echo ==========================================
echo Wojsko Stolicy - bezpieczne wdrozenie
echo ==========================================
echo.
echo Paczka:
echo %ZIP%
echo.

if not exist "%ZIP%" (
    echo BRAK PLIKU ZIP:
    echo %ZIP%
    echo.
    echo Mozesz tez podac paczke jako parametr:
    echo deploy-windows.bat "C:\sciezka\do\paczki.zip"
    exit /b 1
)

if not exist "%REMOTE_SCRIPT%" (
    echo BRAK PLIKU:
    echo %REMOTE_SCRIPT%
    exit /b 1
)

echo [1/2] Wysylam paczke i skrypt wdrozeniowy...
scp -P %PORT% "%ZIP%" root@%HOST%:/root/wojsko-discord-bot-final-audited.zip
if errorlevel 1 (
    echo.
    echo BLAD SCP ZIP. Nic nie zostalo wdrozone.
    exit /b 1
)

scp -P %PORT% "%REMOTE_SCRIPT%" root@%HOST%:/root/remote-update.sh
if errorlevel 1 (
    echo.
    echo BLAD SCP remote-update.sh. Nic nie zostalo wdrozone.
    exit /b 1
)

echo.
echo [2/2] Uruchamiam staging, backup, aktualizacje i preflight...
ssh -p %PORT% root@%HOST% "chmod +x /root/remote-update.sh && /root/remote-update.sh /root/wojsko-discord-bot-final-audited.zip"
if errorlevel 1 (
    echo.
    echo WDROZENIE LUB PREFLIGHT ZGLOSILY BLAD.
    echo Pelny komunikat znajduje sie powyzej.
    exit /b 1
)

echo.
echo ==========================================
echo WDROZENIE ZAKONCZONE POMYSLNIE
echo ==========================================
endlocal
