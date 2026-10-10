@echo off
setlocal

set "HOST=lee125.mikrus.xyz"
set "PORT=10125"

echo ==========================================
echo Wojsko Stolicy - diagnostyka VPS
echo ==========================================
echo.

ssh -p %PORT% root@%HOST% "chmod +x /opt/wojsko-discord-bot/diagnostics.sh && /opt/wojsko-discord-bot/diagnostics.sh"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo DIAGNOSTYKA ZAKONCZONA: OK
) else (
    echo DIAGNOSTYKA WYKRYLA PROBLEM.
)
echo.

exit /b %RC%
