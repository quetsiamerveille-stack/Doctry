# Generation des icones Android DOCTRY (logo document + QR + coche) - version sans fonction imbriquee
Add-Type -AssemblyName System.Drawing

$sizes = @{ "mdpi" = 48; "hdpi" = 72; "xhdpi" = 96; "xxhdpi" = 144; "xxxhdpi" = 192 }
$base = "C:\Users\Quetsia\Desktop\projet\doctry\android\app\src\main\res"

foreach ($density in $sizes.Keys) {
    $px = $sizes[$density]
    $bmp = New-Object System.Drawing.Bitmap($px, $px)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    $white = [System.Drawing.Brushes]::White
    $gold = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 215, 0))
    $ink = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(26, 43, 76))

    # Fond degrade arrondi
    $rect = New-Object System.Drawing.Rectangle(0, 0, $px, $px)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(0, 168, 181),
        [System.Drawing.Color]::FromArgb(26, 43, 76),
        45)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = [int]($px * 0.22)
    $path.AddArc(0, 0, 2*$r, 2*$r, 180, 90)
    $path.AddArc($px - 2*$r, 0, 2*$r, 2*$r, 270, 90)
    $path.AddArc($px - 2*$r, $px - 2*$r, 2*$r, 2*$r, 0, 90)
    $path.AddArc(0, $px - 2*$r, 2*$r, 2*$r, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)

    # Document blanc
    $docX = [double]($px * 0.26); $docY = [double]($px * 0.16); $docW = [double]($px * 0.48); $docH = [double]($px * 0.66)
    $fold = [double]($px * 0.14)
    $docPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $docPath.AddPolygon(@(
        (New-Object System.Drawing.PointF([float]$docX, [float]$docY)),
        (New-Object System.Drawing.PointF([float]($docX + $docW - $fold), [float]$docY)),
        (New-Object System.Drawing.PointF([float]($docX + $docW), [float]($docY + $fold))),
        (New-Object System.Drawing.PointF([float]($docX + $docW), [float]($docY + $docH))),
        (New-Object System.Drawing.PointF([float]$docX, [float]($docY + $docH)))
    ))
    $g.FillPath($white, $docPath)
    $foldPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $foldPath.AddPolygon(@(
        (New-Object System.Drawing.PointF([float]($docX + $docW - $fold), [float]$docY)),
        (New-Object System.Drawing.PointF([float]($docX + $docW - $fold), [float]($docY + $fold))),
        (New-Object System.Drawing.PointF([float]($docX + $docW), [float]($docY + $fold)))
    ))
    $g.FillPath($gold, $foldPath)

    # QR : 3 yeux
    $qrX = [double]($px * 0.32); $qrY = [double]($px * 0.36); $qrS = [double]($px * 0.34)
    $eye = [double]($qrS * 0.34)
    # Oeil haut-gauche
    $g.FillRectangle($ink, [float]$qrX, [float]$qrY, [float]$eye, [float]$eye)
    $g.FillRectangle($white, [float]($qrX + $eye*0.28), [float]($qrY + $eye*0.28), [float]($eye*0.44), [float]($eye*0.44))
    # Oeil haut-droit
    $g.FillRectangle($ink, [float]($qrX + $qrS - $eye), [float]$qrY, [float]$eye, [float]$eye)
    $g.FillRectangle($white, [float]($qrX + $qrS - $eye + $eye*0.28), [float]($qrY + $eye*0.28), [float]($eye*0.44), [float]($eye*0.44))
    # Oeil bas-gauche
    $g.FillRectangle($ink, [float]$qrX, [float]($qrY + $qrS - $eye), [float]$eye, [float]$eye)
    $g.FillRectangle($white, [float]($qrX + $eye*0.28), [float]($qrY + $qrS - $eye + $eye*0.28), [float]($eye*0.44), [float]($eye*0.44))
    # Points QR
    $dot = [double]($qrS * 0.10)
    $g.FillRectangle($ink, [float]($qrX + $qrS*0.52), [float]($qrY + $qrS*0.10), [float]$dot, [float]$dot)
    $g.FillRectangle($ink, [float]($qrX + $qrS*0.74), [float]($qrY + $qrS*0.32), [float]$dot, [float]$dot)
    $g.FillRectangle($ink, [float]($qrX + $qrS*0.10), [float]($qrY + $qrS*0.74), [float]$dot, [float]$dot)

    # Coche de protection
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 215, 0), [float]($px * 0.05))
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
    $g.DrawLine($pen, [float]($px*0.36), [float]($px*0.78), [float]($px*0.46), [float]($px*0.88))
    $g.DrawLine($pen, [float]($px*0.46), [float]($px*0.88), [float]($px*0.70), [float]($px*0.60))

    $g.Dispose()

    $dir = Join-Path $base "mipmap-$density"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $bmp.Save((Join-Path $dir "ic_launcher.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    "mipmap-$density ($px px) OK"
}
"ICONES ANDROID DOCTRY GENEREES AVEC SUCCES"
