@echo off
echo.
echo  ╔══════════════════════════════════════╗
echo  ║   STEP CODE — Запуск сайта           ║
echo  ╚══════════════════════════════════════╝
echo.

where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo  ✗ Node.js не найден!
    echo    Скачай с https://nodejs.org и установи версию LTS
    pause
    exit /b 1
)

if not exist "node_modules" (
    echo  Устанавливаю зависимости (первый раз, подожди 1-2 минуты)...
    npm install
    echo.
)

echo  ✓ Запускаю сайт...
echo  ✓ Фронтенд: http://localhost:5173
echo  ✓ Бэкенд:   http://localhost:3001
echo.
echo  Нажми Ctrl+C чтобы остановить
echo.
npm run dev
