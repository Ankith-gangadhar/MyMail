Add-Type -AssemblyName System.Drawing

$sizes = @{
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" = 48
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" = 72
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" = 96
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" = 144
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" = 192
}

foreach ($path in $sizes.Keys) {
    $dim = $sizes[$path]
    $bmp = New-Object System.Drawing.Bitmap($dim, $dim)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    # 1. Background Rounded Rectangle / Circle in Dark Midnight Slate
    $rect = New-Object System.Drawing.Rectangle(0, 0, $dim, $dim)
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 12, 10, 21))
    $g.FillEllipse($bgBrush, 1, 1, ($dim - 2), ($dim - 2))

    # 2. Glowing Violet Outer Ring
    $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 124, 58, 237), [Math]::Max(2, ($dim * 0.04)))
    $g.DrawEllipse($ringPen, ($dim * 0.04), ($dim * 0.04), ($dim * 0.92), ($dim * 0.92))

    # 3. Purple Shield Body
    $pTop = New-Object System.Drawing.PointF(($dim * 0.5), ($dim * 0.20))
    $pTopR = New-Object System.Drawing.PointF(($dim * 0.78), ($dim * 0.28))
    $pMidR = New-Object System.Drawing.PointF(($dim * 0.78), ($dim * 0.55))
    $pBot = New-Object System.Drawing.PointF(($dim * 0.5), ($dim * 0.82))
    $pMidL = New-Object System.Drawing.PointF(($dim * 0.22), ($dim * 0.55))
    $pTopL = New-Object System.Drawing.PointF(($dim * 0.22), ($dim * 0.28))

    $shieldPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $shieldPath.AddLine($pTop, $pTopR)
    $shieldPath.AddLine($pTopR, $pMidR)
    $shieldPath.AddLine($pMidR, $pBot)
    $shieldPath.AddLine($pBot, $pMidL)
    $shieldPath.AddLine($pMidL, $pTopL)
    $shieldPath.CloseFigure()

    $gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $pTop,
        $pBot,
        [System.Drawing.Color]::FromArgb(255, 139, 92, 246),
        [System.Drawing.Color]::FromArgb(255, 109, 40, 217)
    )
    $g.FillPath($gradBrush, $shieldPath)

    # 4. White Inner Check / Keyhole in Center
    $centerBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillEllipse($centerBrush, ($dim * 0.44), ($dim * 0.40), ($dim * 0.12), ($dim * 0.12))

    $pKey1 = New-Object System.Drawing.PointF(($dim * 0.47), ($dim * 0.46))
    $pKey2 = New-Object System.Drawing.PointF(($dim * 0.53), ($dim * 0.46))
    $pKey3 = New-Object System.Drawing.PointF(($dim * 0.55), ($dim * 0.64))
    $pKey4 = New-Object System.Drawing.PointF(($dim * 0.45), ($dim * 0.64))
    $keyPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $keyPath.AddPolygon(@($pKey1, $pKey2, $pKey3, $pKey4))
    $g.FillPath($centerBrush, $keyPath)

    # Save to disk
    $fullPath = [System.IO.Path]::GetFullPath($path)
    $bmp.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bmp.Dispose()
    Write-Output "Generated: $path"
}
