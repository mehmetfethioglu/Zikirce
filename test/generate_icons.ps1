Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$fgPath = Join-Path $PSScriptRoot "..\assets\images\appiconfg.png"
if (-not (Test-Path $fgPath)) {
    Write-Error "Foreground asset not found at $fgPath"
}

# 1. Load source image and find non-transparent bounding box
$rawFg = [System.Drawing.Bitmap]::FromFile((Resolve-Path $fgPath).ProviderPath)
$minX = $rawFg.Width
$maxX = 0
$minY = $rawFg.Height
$maxY = 0

for ($y = 0; $y -lt $rawFg.Height; $y++) {
    for ($x = 0; $x -lt $rawFg.Width; $x++) {
        $p = $rawFg.GetPixel($x, $y)
        if ($p.A -gt 15) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

$cropW = $maxX - $minX + 1
$cropH = $maxY - $minY + 1
Write-Host "Emblem Bounding Box: X=[$minX, $maxX] Y=[$minY, $maxY], W=$cropW, H=$cropH"

# Create a tightly cropped bitmap of the emblem
$emblem = New-Object System.Drawing.Bitmap($cropW, $cropH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gCrop = [System.Drawing.Graphics]::FromImage($emblem)
$gCrop.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gCrop.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gCrop.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$srcRect = New-Object System.Drawing.Rectangle($minX, $minY, $cropW, $cropH)
$destRect = New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)
$gCrop.DrawImage($rawFg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$gCrop.Dispose()
$rawFg.Dispose()

# Cream background color (#F7F1E5)
$bgColor = [System.Drawing.ColorTranslator]::FromHtml("#F7F1E5")

# -------------------------------------------------------------
# 2. Generate Android Icons
# -------------------------------------------------------------
$androidDensities = @(
    @{ Name = "mipmap-mdpi";    LegacySize = 48;  FgSize = 108 },
    @{ Name = "mipmap-hdpi";    LegacySize = 72;  FgSize = 162 },
    @{ Name = "mipmap-xhdpi";   LegacySize = 96;  FgSize = 216 },
    @{ Name = "mipmap-xxhdpi";  LegacySize = 144; FgSize = 324 },
    @{ Name = "mipmap-xxxhdpi"; LegacySize = 192; FgSize = 432 }
)

foreach ($d in $androidDensities) {
    $folder = Join-Path $PSScriptRoot "..\android\app\src\main\res\$($d.Name)"
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    # A. Adaptive Icon Foreground (ic_launcher_foreground.png)
    # Android Adaptive canvas is 108dp. Mask is 72dp.
    # Optimum emblem size: 62dp / 108dp (~57.4% of canvas, 86% of 72dp mask)
    $fgCanvas = New-Object System.Drawing.Bitmap($d.FgSize, $d.FgSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($fgCanvas)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $emblemFgSize = [int]($d.FgSize * (62.0 / 108.0))
    $offset = [int](($d.FgSize - $emblemFgSize) / 2)
    $g.DrawImage($emblem, $offset, $offset, $emblemFgSize, $emblemFgSize)
    $g.Dispose()

    $fgOut = Join-Path $folder "ic_launcher_foreground.png"
    $fgCanvas.Save($fgOut, [System.Drawing.Imaging.ImageFormat]::Png)
    $fgCanvas.Dispose()

    # B. Legacy Square Icon (ic_launcher.png) with #F7F1E5 background
    $legacyCanvas = New-Object System.Drawing.Bitmap($d.LegacySize, $d.LegacySize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($legacyCanvas)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear($bgColor)

    $emblemLegSize = [int]($d.LegacySize * 0.74)
    $offsetLeg = [int](($d.LegacySize - $emblemLegSize) / 2)
    $g.DrawImage($emblem, $offsetLeg, $offsetLeg, $emblemLegSize, $emblemLegSize)
    $g.Dispose()

    $legOut = Join-Path $folder "ic_launcher.png"
    $legacyCanvas.Save($legOut, [System.Drawing.Imaging.ImageFormat]::Png)
    $legacyCanvas.Dispose()

    # C. Legacy Round Icon (ic_launcher_round.png)
    $roundCanvas = New-Object System.Drawing.Bitmap($d.LegacySize, $d.LegacySize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($roundCanvas)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $brush = New-Object System.Drawing.SolidBrush($bgColor)
    $g.FillEllipse($brush, 0, 0, $d.LegacySize, $d.LegacySize)
    $brush.Dispose()

    $emblemRoundSize = [int]($d.LegacySize * 0.72)
    $offsetRound = [int](($d.LegacySize - $emblemRoundSize) / 2)
    $g.DrawImage($emblem, $offsetRound, $offsetRound, $emblemRoundSize, $emblemRoundSize)
    $g.Dispose()

    $roundOut = Join-Path $folder "ic_launcher_round.png"
    $roundCanvas.Save($roundOut, [System.Drawing.Imaging.ImageFormat]::Png)
    $roundCanvas.Dispose()

    Write-Host "Generated Android icons for $($d.Name)"
}

# -------------------------------------------------------------
# 3. Generate iOS App Icons
# -------------------------------------------------------------
$iosFolder = Join-Path $PSScriptRoot "..\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosFolder) {
    $iosIcons = @(
        @{ File = "Icon-App-20x20@1x.png";   Size = 20 },
        @{ File = "Icon-App-20x20@2x.png";   Size = 40 },
        @{ File = "Icon-App-20x20@3x.png";   Size = 60 },
        @{ File = "Icon-App-29x29@1x.png";   Size = 29 },
        @{ File = "Icon-App-29x29@2x.png";   Size = 58 },
        @{ File = "Icon-App-29x29@3x.png";   Size = 87 },
        @{ File = "Icon-App-40x40@1x.png";   Size = 40 },
        @{ File = "Icon-App-40x40@2x.png";   Size = 80 },
        @{ File = "Icon-App-40x40@3x.png";   Size = 120 },
        @{ File = "Icon-App-60x60@2x.png";   Size = 120 },
        @{ File = "Icon-App-60x60@3x.png";   Size = 180 },
        @{ File = "Icon-App-76x76@1x.png";   Size = 76 },
        @{ File = "Icon-App-76x76@2x.png";   Size = 152 },
        @{ File = "Icon-App-83.5x83.5@2x.png"; Size = 167 },
        @{ File = "Icon-App-1024x1024@1x.png"; Size = 1024 }
    )

    foreach ($icon in $iosIcons) {
        $canvas = New-Object System.Drawing.Bitmap($icon.Size, $icon.Size, [System.Drawing.Imaging.PixelFormat]::Format32bppRgb)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear($bgColor)

        $emblemSize = [int]($icon.Size * 0.74)
        $offset = [int](($icon.Size - $emblemSize) / 2)
        $g.DrawImage($emblem, $offset, $offset, $emblemSize, $emblemSize)
        $g.Dispose()

        $outPath = Join-Path $iosFolder $icon.File
        $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $canvas.Dispose()
    }
    Write-Host "Generated iOS app icons"
}

# -------------------------------------------------------------
# 4. Generate Web Icons
# -------------------------------------------------------------
$webFolder = Join-Path $PSScriptRoot "..\web\icons"
if (Test-Path $webFolder) {
    $webIcons = @(
        @{ File = "Icon-192.png"; Size = 192; Scale = 0.74 },
        @{ File = "Icon-512.png"; Size = 512; Scale = 0.74 },
        @{ File = "Icon-maskable-192.png"; Size = 192; Scale = 0.574 },
        @{ File = "Icon-maskable-512.png"; Size = 512; Scale = 0.574 }
    )

    foreach ($icon in $webIcons) {
        $canvas = New-Object System.Drawing.Bitmap($icon.Size, $icon.Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear($bgColor)

        $emblemSize = [int]($icon.Size * $icon.Scale)
        $offset = [int](($icon.Size - $emblemSize) / 2)
        $g.DrawImage($emblem, $offset, $offset, $emblemSize, $emblemSize)
        $g.Dispose()

        $outPath = Join-Path $webFolder $icon.File
        $canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $canvas.Dispose()
    }
    Write-Host "Generated Web icons"
}

# -------------------------------------------------------------
# 5. Generate Asset Icons (assets/images/)
# -------------------------------------------------------------
$assetFolder = Join-Path $PSScriptRoot "..\assets\images"
if (Test-Path $assetFolder) {
    # 1024x1024 with cream background
    $canvas1024 = New-Object System.Drawing.Bitmap(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas1024)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear($bgColor)

    $emblemSize1024 = [int](1024 * 0.74)
    $offset1024 = [int]((1024 - $emblemSize1024) / 2)
    $g.DrawImage($emblem, $offset1024, $offset1024, $emblemSize1024, $emblemSize1024)
    $g.Dispose()

    $appIconWithBgPath = Join-Path $assetFolder "appicon_with_bg.png"
    $canvas1024.Save($appIconWithBgPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $zikirceLogoPath = Join-Path $assetFolder "zikirce_logo.png"
    $canvas1024.Save($zikirceLogoPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $appIconPath = Join-Path $assetFolder "appicon.png"
    $canvas1024.Save($appIconPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $canvas1024.Dispose()
    Write-Host "Updated assets/images/ icons (appicon_with_bg.png, zikirce_logo.png, appicon.png)"
}

# -------------------------------------------------------------
# 6. Generate Windows Icon (.ico)
# -------------------------------------------------------------
$winFolder = Join-Path $PSScriptRoot "..\windows\runner\resources"
if (Test-Path $winFolder) {
    $icoPath = Join-Path $winFolder "app_icon.ico"
    $canvas256 = New-Object System.Drawing.Bitmap(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas256)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear($bgColor)

    $emblemSize256 = [int](256 * 0.74)
    $offset256 = [int]((256 - $emblemSize256) / 2)
    $g.DrawImage($emblem, $offset256, $offset256, $emblemSize256, $emblemSize256)
    $g.Dispose()

    $iconHandle = $canvas256.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    $fs = New-Object System.IO.FileStream($icoPath, [System.IO.FileMode]::Create)
    $icon.Save($fs)
    $fs.Close()
    $fs.Dispose()
    $icon.Dispose()
    $canvas256.Dispose()
    Write-Host "Updated windows/runner/resources/app_icon.ico"
}

$emblem.Dispose()
Write-Host "All icons generated successfully with cream background (#F7F1E5) and optimum logo sizing!"
