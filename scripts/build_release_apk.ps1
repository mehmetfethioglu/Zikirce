param(
    [switch]$UploadToDrive,
    [string]$DriveReleasesDir = "G:\Drive'ım\organicscore\Releases"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SecretsFile = Join-Path $RepoRoot "edge_worker\.secrets.local.env"

if (-not (Test-Path $SecretsFile)) {
    throw "Missing secrets file: $SecretsFile"
}

$hmacSecret = ""
foreach ($line in Get-Content $SecretsFile) {
    if ($line -match '^\s*HMAC_SECRET\s*=\s*(.+)\s*$') {
        $hmacSecret = $Matches[1].Trim().Trim('"').Trim("'")
        break
    }
}

if ([string]::IsNullOrWhiteSpace($hmacSecret)) {
    throw "HMAC_SECRET is empty or missing in $SecretsFile"
}

$pubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
$versionSuffix = "latest"
if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)') {
    $versionSuffix = $Matches[1]
}

Push-Location $RepoRoot
try {
    Write-Host "Building signed release APK v$versionSuffix with KILERCE_HMAC_SECRET..." -ForegroundColor Cyan
    flutter build apk --release --dart-define="KILERCE_HMAC_SECRET=$hmacSecret"
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $apkPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        throw "Expected APK not found: $apkPath"
    }

    if ($UploadToDrive) {
        if (-not (Test-Path $DriveReleasesDir)) {
            throw "Google Drive Releases directory not found: $DriveReleasesDir"
        }
        $dstPath = Join-Path $DriveReleasesDir "Kilerce_v${versionSuffix}_release.apk"
        Copy-Item -Path $apkPath -Destination $dstPath -Force
        Write-Host "Uploaded to Google Drive: $dstPath" -ForegroundColor Green
    }
} finally {
    Pop-Location
}
