# LyricsCaster Windows 版 - 一键打包脚本 (PowerShell)
# 使用方法: 右键此文件 → 用 PowerShell 运行
# 或者在 PowerShell 中: .\build.ps1

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  LyricsCaster Windows 版 - 一键打包" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Node.js
try {
    $nodeVersion = node -v
    Write-Host "[✓] Node.js 版本: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "[✗] 未检测到 Node.js！" -ForegroundColor Red
    Write-Host ""
    Write-Host "请先安装 Node.js v18 或更高版本:" -ForegroundColor Yellow
    Write-Host "  下载地址: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "按回车键退出"
    exit 1
}

# 检查 npm
$npmVersion = npm -v
Write-Host "[✓] npm 版本: $npmVersion" -ForegroundColor Green
Write-Host ""

# 询问是否使用国内镜像
$useMirror = Read-Host "是否使用淘宝镜像加速下载? (推荐国内用户) [Y/n]"
if ($useMirror -ne "n" -and $useMirror -ne "N") {
    Write-Host "[信息] 设置淘宝 npm 镜像..." -ForegroundColor Yellow
    npm config set registry https://registry.npmmirror.com
    $env:ELECTRON_MIRROR = "https://npmmirror.com/mirrors/electron/"
    $env:ELECTRON_BUILDER_BINARIES_MIRROR = "https://npmmirror.com/mirrors/electron-builder-binaries/"
    Write-Host "[✓] 镜像设置完成" -ForegroundColor Green
}
Write-Host ""

# 步骤 1: 安装依赖
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "[步骤 1/4] 安装项目依赖..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "[✗] 依赖安装失败！" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}
Write-Host "[✓] 依赖安装完成！" -ForegroundColor Green
Write-Host ""

# 步骤 2: 编译主进程
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "[步骤 2/4] 编译主进程 TypeScript..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

npx tsc -p tsconfig.main.json
if ($LASTEXITCODE -ne 0) {
    Write-Host "[✗] TypeScript 编译失败！" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}
Write-Host "[✓] 主进程编译完成！" -ForegroundColor Green
Write-Host ""

# 步骤 3: 构建渲染进程
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "[步骤 3/4] 构建渲染进程 (React + Vite)..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

npx vite build
if ($LASTEXITCODE -ne 0) {
    Write-Host "[✗] Vite 构建失败！" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}
Write-Host "[✓] 渲染进程构建完成！" -ForegroundColor Green
Write-Host ""

# 步骤 4: 打包 .exe
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "[步骤 4/4] 打包 Windows .exe 安装程序..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

npx electron-builder --win
if ($LASTEXITCODE -ne 0) {
    Write-Host "[✗] 打包失败！" -ForegroundColor Red
    Write-Host "可能原因:" -ForegroundColor Yellow
    Write-Host "  1. 首次打包需下载 Electron 二进制文件" -ForegroundColor Yellow
    Write-Host "  2. 请确保网络通畅或已设置镜像" -ForegroundColor Yellow
    Read-Host "按回车键退出"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  打包完成！" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# 查找输出文件
$releaseDir = if (Test-Path "release") { "release" } elseif (Test-Path "dist") { "dist" } else { $null }

if ($releaseDir) {
    $exeFiles = Get-ChildItem -Path $releaseDir -Filter "*.exe" -Recurse
    if ($exeFiles.Count -gt 0) {
        Write-Host "生成的安装程序:" -ForegroundColor Green
        foreach ($file in $exeFiles) {
            $sizeMB = [math]::Round($file.Length / 1MB, 1)
            Write-Host "  $($file.FullName)  ($sizeMB MB)" -ForegroundColor White
        }
        Write-Host ""
        # 打开目录
        explorer $exeFiles[0].DirectoryName
    }
}

Write-Host "双击 .exe 文件即可在任何 Windows 电脑上安装。" -ForegroundColor White
Write-Host ""
Read-Host "按回车键退出"
