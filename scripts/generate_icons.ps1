Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\theak\.gemini\antigravity-ide\brain\2abf2d2d-b510-4caf-b333-4957508be8d7\media__1785224207647.jpg"
$resDir = "c:\Users\theak\source\repos\foodscore\android\app\src\main\res"

$sizes = @{
    "mipmap-mdpi" = 48;
    "mipmap-hdpi" = 72;
    "mipmap-xhdpi" = 96;
    "mipmap-xxhdpi" = 144;
    "mipmap-xxxhdpi" = 192;
}

$srcImg = [System.Drawing.Image]::FromFile($srcPath)

foreach ($key in $sizes.Keys) {
    $size = $sizes[$key]
    $folder = Join-Path $resDir $key
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
    
    $destImg = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($destImg)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    $g.Dispose()
    
    $outPath = Join-Path $folder "ic_launcher.png"
    $destImg.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destImg.Dispose()
    Write-Host "Saved $outPath (${size}x${size})"
}

# Play Store High Res Icon 512x512
$storeImg = New-Object System.Drawing.Bitmap(512, 512)
$gStore = [System.Drawing.Graphics]::FromImage($storeImg)
$gStore.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gStore.DrawImage($srcImg, 0, 0, 512, 512)
$gStore.Dispose()
$storePath = Join-Path $resDir "ic_launcher-web.png"
$storeImg.Save($storePath, [System.Drawing.Imaging.ImageFormat]::Png)
$storeImg.Dispose()
Write-Host "Saved Play Store Icon $storePath (512x512)"

$srcImg.Dispose()
