param(
    [Parameter(Mandatory = $false)]
    [string]$ChunksDir = "c:\Users\theak\Downloads\ym\d1_export_chunks",

    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = "kilerce-recipes-db",

    [Parameter(Mandatory = $false)]
    [string]$BucketName = "kilerce-recipe-media"
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkerDir = Join-Path $RepoRoot "edge_worker"

Push-Location $WorkerDir
try {
    Write-Host "1/4 D1 uzak veritabani semasi uygulaniyor..." -ForegroundColor Cyan
    npx wrangler d1 execute $DatabaseName --remote --file=".\migrations\0001_init_recipes_and_entitlements.sql"

    Write-Host "2/4 D1 23.933 tarif chunk dosyalari yukleniyor..." -ForegroundColor Cyan
    $chunks = Get-ChildItem -Path $ChunksDir -Filter "chunk_*.sql" | Sort-Object Name
    $total = $chunks.Count
    $idx = 0
    foreach ($chunk in $chunks) {
        $idx++
        Write-Host "[$idx/$total] Yukleniyor: $($chunk.Name)"
        npx wrangler d1 execute $DatabaseName --remote --file="$($chunk.FullName)"
    }

    Write-Host "3/4 Worker + Secret kontrolu..." -ForegroundColor Cyan
    Write-Host "Not: Secret eklemediyseniz once su komutlari calistirin:" -ForegroundColor Yellow
    Write-Host "  npx wrangler secret put HMAC_SECRET"
    Write-Host "  npx wrangler secret put MEDIA_SIGNING_SECRET"
    Write-Host "  npx wrangler secret put REVENUECAT_WEBHOOK_AUTH"
    Write-Host "  npx wrangler secret put GEMINI_API_KEY"
    npx wrangler deploy

    Write-Host "4/4 R2 gorsel yuklemesi icin:" -ForegroundColor Cyan
    Write-Host "  `$env:CF_ACCOUNT_ID='...'; `$env:R2_ACCESS_KEY_ID='...'; `$env:R2_SECRET_ACCESS_KEY='...'"
    Write-Host "  python `"$RepoRoot\scripts\cloudflare\upload_r2_media.py`" --bucket $BucketName"
} finally {
    Pop-Location
}
