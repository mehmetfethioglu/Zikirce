# ============================================================================
# Hasibu Şube Yüz Okutma Köprüsü — Windows 10 x64 Tek-Dosya Yayın Betiği
# ============================================================================
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$projectPath = Join-Path $repoRoot "tools\hasibu_branch_bridge\HasibuBranchBridge.csproj"
$outDir = Join-Path $repoRoot "dist\HasibuBranchBridge_win_x64"
$definesPath = Join-Path $repoRoot "dart_defines.local.json"

$clientId = ""
$clientSecret = ""
if (Test-Path $definesPath) {
    $defines = Get-Content $definesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($defines.PSObject.Properties["HASIBU_GOOGLE_CLIENT_ID"]) {
        $clientId = [string]$defines.HASIBU_GOOGLE_CLIENT_ID
    }
    if ($defines.PSObject.Properties["HASIBU_GOOGLE_CLIENT_SECRET"]) {
        $clientSecret = [string]$defines.HASIBU_GOOGLE_CLIENT_SECRET
    }
}

if (Test-Path $outDir) {
    Remove-Item -Recurse -Force $outDir
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "1/4 Windows 10 x64 (win-x64) tek-dosya HasibuBranchBridge.exe derleniyor..." -ForegroundColor Cyan

$publishArgs = @(
    "publish", $projectPath,
    "-c", "Release",
    "-r", "win-x64",
    "--self-contained", "true",
    "-p:PublishSingleFile=true",
    "-p:IncludeNativeLibrariesForSelfExtract=true",
    "-p:DebugType=none",
    "-p:DebugSymbols=false",
    "-o", $outDir
)
if (-not [string]::IsNullOrWhiteSpace($clientId)) {
    $publishArgs += "-p:HasibuOAuthClientId=$clientId"
}
if (-not [string]::IsNullOrWhiteSpace($clientSecret)) {
    $publishArgs += "-p:HasibuOAuthClientSecret=$clientSecret"
}

& dotnet @publishArgs
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish win-x64 başarısız oldu (çıkış kodu: $LASTEXITCODE)."
}

$exePath = Join-Path $outDir "HasibuBranchBridge.exe"
if (-not (Test-Path $exePath)) {
    throw "Beklenen çıktı dosyası üretilemedi: $exePath"
}

Write-Host "2/4 PE başlığı doğrulanıyor (x64 = 0x8664, Windows GUI = 2)..." -ForegroundColor Cyan
$fs = [System.IO.File]::OpenRead($exePath)
try {
    $br = New-Object System.IO.BinaryReader($fs)
    $mz = $br.ReadUInt16()
    if ($mz -ne 0x5A4D) { throw "Geçersiz PE MZ imzası." }
    $fs.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
    $peOffset = $br.ReadInt32()
    $fs.Seek($peOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
    $peSig = $br.ReadUInt32()
    if ($peSig -ne 0x00004550) { throw "Geçersiz PE imzası." }
    $machine = $br.ReadUInt16()
    $fs.Seek($peOffset + 24 + 68, [System.IO.SeekOrigin]::Begin) | Out-Null
    $subsystem = $br.ReadUInt16()

    if ($machine -ne 0x8664) {
        throw ("Beklenen x64 (0x8664) yerine farklı mimari üretildi: 0x{0:X4}" -f $machine)
    }
    if ($subsystem -ne 2) {
        throw "Beklenen Windows GUI subsystem (2) yerine $subsystem üretildi."
    }
    $sizeMb = [Math]::Round((Get-Item $exePath).Length / 1MB, 2)
    Write-Host ("✓ PE Doğrulandı: Machine=0x{0:X4} (x64), Subsystem={1} (Ekransız WinExe), Boyut={2} MB" -f $machine, $subsystem, $sizeMb) -ForegroundColor Green
} finally {
    $fs.Dispose()
}

Write-Host "3/4 Terazi kurulum kısayolları (.bat) ve rehber oluşturuluyor..." -ForegroundColor Cyan
$unblockLine = 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath ''%~dp0'' -File | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1'
[System.IO.File]::WriteAllText(
    (Join-Path $outDir "1_Kurulum_Sihirbazi.bat"),
    "@echo off`r`nchcp 65001 >nul`r`n$unblockLine`r`n`"%~dp0HasibuBranchBridge.exe`" --setup`r`npause`r`n",
    [System.Text.Encoding]::ASCII
)
[System.IO.File]::WriteAllText(
    (Join-Path $outDir "2_Baglanti_Testi.bat"),
    "@echo off`r`nchcp 65001 >nul`r`n$unblockLine`r`n`"%~dp0HasibuBranchBridge.exe`" --test`r`npause`r`n",
    [System.Text.Encoding]::ASCII
)
[System.IO.File]::WriteAllText(
    (Join-Path $outDir "3_Baslangica_Ekle.bat"),
    "@echo off`r`nchcp 65001 >nul`r`n$unblockLine`r`n`"%~dp0HasibuBranchBridge.exe`" --install-startup`r`npause`r`n",
    [System.Text.Encoding]::ASCII
)
[System.IO.File]::WriteAllText(
    (Join-Path $outDir "4_Baslangictan_Kaldir.bat"),
    "@echo off`r`nchcp 65001 >nul`r`n$unblockLine`r`n`"%~dp0HasibuBranchBridge.exe`" --uninstall-startup`r`npause`r`n",
    [System.Text.Encoding]::ASCII
)

$readme = @"
HASİBU ŞUBE YÜZ OKUTMA KÖPRÜSÜ (WINDOWS 10 64-BIT AKILLI TERAZİ KURULUMU)
========================================================================

Bu klasör şubedeki Windows 10 (64-bit) akıllı terazide arka planda ekransız çalışır.
Personel yüzünü okuttuğu anda (~3 saniye içinde) kaydı şifreli olarak Google Drive'daki
kendi şube kutusuna (hasibu_branch_inbox_<sube>.enc) gönderir. Diğer şubelerle çakışmaz.

ADIM 1 — MERKEZDEN AYARI KOPYALAYIN
1. Merkezdeki Hasibu uygulamasında "Bulut Yedek Merkezi"ni açın.
2. "Şube Yüz Okutma Köprüleri" bölümünden kurulacak şubeyi seçip
   "Şube Köprüsü Ayar JSON Kopyala" butonuna basın.
3. Kopyalanan metni bu klasörde `config.json` adıyla kaydedin (veya kurulumda elle girin).

ADIM 2 — ŞUBE TERAZİSİNDE TEK SEFERLİK KURULUM
1. Bu klasörü terazide kalıcı bir yere kopyalayın (ör. C:\HasibuBranchBridge).
2. `1_Kurulum_Sihirbazi.bat` dosyasına çift tıklayın.
3. Ekrandaki adımları izleyip Google hesabıyla bir kez izin verin, ardından
   "Windows açılışında otomatik başlasın mı?" sorusunu `E` ile onaylayın.
4. `3_Baslangica_Ekle.bat` (veya kurulum sihirbazı) köprüyü otomatik olarak
   `%LOCALAPPDATA%\HasibuBranchBridge\bin\` içine kopyalar, internet indirme damgasını
   (`Zone.Identifier`) temizler ve Windows Görev Zamanlayıcı üzerinden oturum açılışında
   "Yayımcı doğrulanamadı / Çalıştır-İptal" uyarısı vermeden başlatır.
5. İstediğiniz zaman `2_Baglanti_Testi.bat` ile cihaz + Google Drive aktarımını test edebilirsiniz.

NOTLAR:
- Günlük çalışma dosyaları : %LOCALAPPDATA%\HasibuBranchBridge\
- Bağlantı günlükleri     : %LOCALAPPDATA%\HasibuBranchBridge\logs\
- Arka plan modu          : Windows açılışında ekransız (penceresiz) otomatik başlar.
"@
[System.IO.File]::WriteAllText((Join-Path $outDir "KURULUM_REHBERI.txt"), $readme, [System.Text.Encoding]::UTF8)

$driveTarget = "G:\Drive'ım\hasibu\BranchBridge"
if (Test-Path "G:\Drive'ım\hasibu") {
    Write-Host "4/4 Google Drive klasörüne ($driveTarget) kopyalanıyor..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $driveTarget | Out-Null
    Copy-Item -Path (Join-Path $outDir "*") -Destination $driveTarget -Recurse -Force
    Write-Host "✓ Google Drive teslimatı tamamlandı: $driveTarget" -ForegroundColor Green
} else {
    Write-Host "4/4 Google Drive yerel klasörü bulunamadı, yalnızca dist klasörüne yazıldı." -ForegroundColor Yellow
}

Write-Host "✓ Şube Köprüsü x64 paketi hazır: $outDir" -ForegroundColor Green
