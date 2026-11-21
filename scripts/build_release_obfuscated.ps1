# ============================================================================
# [AUD-04] Hasibu — Canlı (Release) Kod Karartma (Obfuscation) Derleme Betiği
# ============================================================================
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path ".\build\symbols" | Out-Null

$dartDefineArgs = @()
if (Test-Path ".\dart_defines.local.json") {
    $dartDefineArgs += "--dart-define-from-file=.\dart_defines.local.json"
}

Write-Host "1/2 Android Release APK Obfuscation başlatılıyor..." -ForegroundColor Cyan
flutter build apk --release --obfuscate --split-debug-info=./build/symbols @dartDefineArgs

Write-Host "2/2 Windows Release Obfuscation başlatılıyor..." -ForegroundColor Cyan
flutter build windows --release --obfuscate --split-debug-info=./build/symbols @dartDefineArgs

Write-Host "✓ Kod karartılmış (Obfuscated) canlı paketler ve sembol haritaları (./build/symbols) üretildi." -ForegroundColor Green
