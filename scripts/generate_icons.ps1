# Generate app icons for all platforms from a single source image
# Usage: .\generate_icons.ps1 <source_image.png>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceImage
)

Write-Host "Generating app icons for all platforms..." -ForegroundColor Green

# Check if ImageMagick is installed
$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
    Write-Host "ImageMagick not found. Please install it first:" -ForegroundColor Red
    Write-Host "winget install ImageMagick.ImageMagick" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or download from: https://imagemagick.org/script/download.php" -ForegroundColor Yellow
    exit 1
}

# Windows ICO (16, 32, 48, 256)
Write-Host "Generating Windows ICO..." -ForegroundColor Cyan
magick convert $SourceImage -define icon:auto-resize=256, 128, 96, 64, 48, 32, 16 windows/runner/resources/app_icon.ico
Copy-Item windows/runner/resources/app_icon.ico app_icon.ico

# iOS Icons
Write-Host "Generating iOS icons..." -ForegroundColor Cyan
$iosPath = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
magick convert $SourceImage -resize 1024x1024 "$iosPath/Icon-App-1024x1024@1x.png"
magick convert $SourceImage -resize 20x20 "$iosPath/Icon-App-20x20@1x.png"
magick convert $SourceImage -resize 40x40 "$iosPath/Icon-App-20x20@2x.png"
magick convert $SourceImage -resize 60x60 "$iosPath/Icon-App-20x20@3x.png"
magick convert $SourceImage -resize 29x29 "$iosPath/Icon-App-29x29@1x.png"
magick convert $SourceImage -resize 58x58 "$iosPath/Icon-App-29x29@2x.png"
magick convert $SourceImage -resize 87x87 "$iosPath/Icon-App-29x29@3x.png"
magick convert $SourceImage -resize 40x40 "$iosPath/Icon-App-40x40@1x.png"
magick convert $SourceImage -resize 80x80 "$iosPath/Icon-App-40x40@2x.png"
magick convert $SourceImage -resize 120x120 "$iosPath/Icon-App-40x40@3x.png"
magick convert $SourceImage -resize 120x120 "$iosPath/Icon-App-60x60@2x.png"
magick convert $SourceImage -resize 180x180 "$iosPath/Icon-App-60x60@3x.png"
magick convert $SourceImage -resize 76x76 "$iosPath/Icon-App-76x76@1x.png"
magick convert $SourceImage -resize 152x152 "$iosPath/Icon-App-76x76@2x.png"
magick convert $SourceImage -resize 167x167 "$iosPath/Icon-App-83.5x83.5@2x.png"

# macOS Icons
Write-Host "Generating macOS icons..." -ForegroundColor Cyan
$macosPath = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
magick convert $SourceImage -resize 1024x1024 "$macosPath/app_icon_1024.png"
magick convert $SourceImage -resize 512x512 "$macosPath/app_icon_512.png"
magick convert $SourceImage -resize 256x256 "$macosPath/app_icon_256.png"
magick convert $SourceImage -resize 128x128 "$macosPath/app_icon_128.png"
magick convert $SourceImage -resize 64x64 "$macosPath/app_icon_64.png"
magick convert $SourceImage -resize 32x32 "$macosPath/app_icon_32.png"
magick convert $SourceImage -resize 16x16 "$macosPath/app_icon_16.png"

# Android Icons (mipmap)
Write-Host "Generating Android icons..." -ForegroundColor Cyan
$androidPath = "android/app/src/main/res"
New-Item -ItemType Directory -Force -Path "$androidPath/mipmap-mdpi" | Out-Null
New-Item -ItemType Directory -Force -Path "$androidPath/mipmap-hdpi" | Out-Null
New-Item -ItemType Directory -Force -Path "$androidPath/mipmap-xhdpi" | Out-Null
New-Item -ItemType Directory -Force -Path "$androidPath/mipmap-xxhdpi" | Out-Null
New-Item -ItemType Directory -Force -Path "$androidPath/mipmap-xxxhdpi" | Out-Null

magick convert $SourceImage -resize 48x48 "$androidPath/mipmap-mdpi/ic_launcher.png"
magick convert $SourceImage -resize 72x72 "$androidPath/mipmap-hdpi/ic_launcher.png"
magick convert $SourceImage -resize 96x96 "$androidPath/mipmap-xhdpi/ic_launcher.png"
magick convert $SourceImage -resize 144x144 "$androidPath/mipmap-xxhdpi/ic_launcher.png"
magick convert $SourceImage -resize 192x192 "$androidPath/mipmap-xxxhdpi/ic_launcher.png"

Write-Host ""
Write-Host "✓ All icons generated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Generated icons for:" -ForegroundColor Yellow
Write-Host "  - Windows (ICO)" -ForegroundColor White
Write-Host "  - iOS (15 sizes)" -ForegroundColor White
Write-Host "  - macOS (7 sizes)" -ForegroundColor White
Write-Host "  - Android (5 densities)" -ForegroundColor White
