@echo off
chcp 65001 >nul
echo ============================================
echo   LyricsCaster Build Tool
echo ============================================
echo.

cd /d "%~dp0"

echo [1/4] Setting npm mirror...
set "ELECTRON_MIRROR=https://cdn.npmmirror.com/binaries/electron/"
call npm config set registry https://registry.npmmirror.com
if errorlevel 1 (
    echo [WARN] Mirror setup failed, using default registry
)

echo.
echo [2/4] Installing dependencies...
call npm install
if errorlevel 1 (
    echo.
    echo [FAIL] npm install failed
    pause
    exit /b 1
)

echo.
echo [3/4] Compiling TypeScript...
call node ./node_modules/typescript/bin/tsc -p tsconfig.main.json
if errorlevel 1 (
    echo.
    echo [FAIL] TypeScript compile failed
    pause
    exit /b 1
)

echo.
echo [4/4] Building exe installer...
call node ./node_modules/vite/bin/vite.js build
if errorlevel 1 (
    echo.
    echo [FAIL] Vite build failed
    pause
    exit /b 1
)

call node ./node_modules/electron-builder/out/cli/cli.js --win --publish never
if errorlevel 1 (
    echo.
    echo [FAIL] Electron builder failed
    pause
    exit /b 1
)

echo.
echo ============================================
echo   BUILD SUCCESS!
echo   Output: release folder
echo ============================================
echo.

if exist "%~dp0release" (
    explorer "%~dp0release"
) else (
    echo [WARN] release folder not found, opening current directory
    explorer "%~dp0"
)
pause
