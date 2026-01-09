# Flutter 构建脚本（自动下载核心）
# 使用方法: .\scripts\build.ps1 [windows|macos|linux]

param(
    [string]$Platform = "windows",
    [switch]$Release = $false,
    [switch]$SkipDownload = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Slux 自动构建工具" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# 1. 下载核心文件（除非指定跳过）
if (-not $SkipDownload) {
    Write-Host "步骤 1/3: 下载 Sing-box 核心..." -ForegroundColor Cyan
    $DownloadScript = Join-Path $PSScriptRoot "download_core.ps1"
    
    if (Test-Path $DownloadScript) {
        & $DownloadScript -Platform $Platform
        if ($LASTEXITCODE -ne 0) {
            Write-Host "核心下载失败，但继续构建..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "未找到下载脚本，跳过..." -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    Write-Host "跳过核心下载" -ForegroundColor Yellow
    Write-Host ""
}

# 2. Flutter pub get
Write-Host "步骤 2/3: 获取依赖..." -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "依赖获取失败" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 3. Flutter build
Write-Host "步骤 3/3: 构建应用..." -ForegroundColor Cyan
$BuildMode = if ($Release) { "release" } else { "debug" }
$BuildCommand = "flutter build $Platform --$BuildMode"

Write-Host "执行: $BuildCommand" -ForegroundColor Gray
Invoke-Expression $BuildCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  构建成功！" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    
    # 显示输出路径
    $OutputPath = switch ($Platform) {
        "windows" { "build\windows\x64\runner\$BuildMode\" }
        "macos" { "build\macos\Build\Products\$BuildMode\" }
        "linux" { "build\linux\x64\$BuildMode\bundle\" }
        default { "build\" }
    }
    Write-Host "输出目录: $OutputPath" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "构建失败" -ForegroundColor Red
    exit 1
}
