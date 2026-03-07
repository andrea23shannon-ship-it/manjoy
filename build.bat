@echo off
chcp 65001 >nul 2>&1
title LyricsCaster Windows 打包工具
echo.
echo ============================================
echo   LyricsCaster Windows 版 - 一键打包
echo ============================================
echo.

:: 检查 Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js！
    echo.
    echo 请先安装 Node.js v18 或更高版本：
    echo   下载地址: https://nodejs.org/
    echo.
    echo 安装完成后请重新运行此脚本。
    pause
    exit /b 1
)

:: 显示 Node.js 版本
echo [信息] Node.js 版本:
node -v
echo.

:: 显示 npm 版本
echo [信息] npm 版本:
call npm -v
echo.

:: 第1步：安装依赖
echo ============================================
echo [步骤 1/4] 安装项目依赖...
echo ============================================
echo.
call npm install
if %errorlevel% neq 0 (
    echo.
    echo [错误] 依赖安装失败！请检查网络连接。
    echo 提示：如果在国内，可以先设置淘宝镜像：
    echo   npm config set registry https://registry.npmmirror.com
    echo 然后重新运行此脚本。
    pause
    exit /b 1
)
echo.
echo [成功] 依赖安装完成！
echo.

:: 第2步：编译主进程 TypeScript
echo ============================================
echo [步骤 2/4] 编译主进程 TypeScript...
echo ============================================
echo.
call npx tsc -p tsconfig.main.json
if %errorlevel% neq 0 (
    echo.
    echo [错误] TypeScript 编译失败！请检查代码。
    pause
    exit /b 1
)
echo.
echo [成功] 主进程编译完成！
echo.

:: 第3步：构建渲染进程 (Vite)
echo ============================================
echo [步骤 3/4] 构建渲染进程 (React + Vite)...
echo ============================================
echo.
call npx vite build
if %errorlevel% neq 0 (
    echo.
    echo [错误] Vite 构建失败！
    pause
    exit /b 1
)
echo.
echo [成功] 渲染进程构建完成！
echo.

:: 第4步：打包 .exe 安装程序
echo ============================================
echo [步骤 4/4] 打包 Windows .exe 安装程序...
echo ============================================
echo.
call npx electron-builder --win
if %errorlevel% neq 0 (
    echo.
    echo [错误] 打包失败！
    echo 可能原因：
    echo   1. 首次打包需要下载 Electron 二进制文件，请确保网络通畅
    echo   2. 如果下载慢，可以设置镜像：
    echo      set ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
    echo      然后重新运行此脚本
    pause
    exit /b 1
)

echo.
echo ============================================
echo   打包完成！
echo ============================================
echo.
echo 安装程序位于: release\
echo.
echo 请查看 release 目录中的 .exe 文件，
echo 双击即可在任何 Windows 电脑上安装。
echo.

:: 打开输出目录
if exist "release" (
    explorer release
) else if exist "dist" (
    echo 输出目录: dist\
    explorer dist
)

pause
