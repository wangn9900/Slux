Add-Type -AssemblyName System.Drawing

try {
    Write-Host "Step 0: Init"
    $size = 256
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    Write-Host "Step 1: Background"
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $c1 = [System.Drawing.ColorTranslator]::FromHtml("#3B82F6")
    $c2 = [System.Drawing.ColorTranslator]::FromHtml("#8B5CF6")
    $angle = [float]45.0
    
    # Use ArgumentList to be explicit
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $rect, $c1, $c2, $angle
    
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $radius = 64 
    $diameter = $radius * 2
    
    # Draw Rounded Rect using float coords
    $path.AddArc([float]0, [float]0, [float]$diameter, [float]$diameter, [float]180, [float]90)
    $path.AddArc([float]($size - $diameter), [float]0, [float]$diameter, [float]$diameter, [float]270, [float]90)
    $path.AddArc([float]($size - $diameter), [float]($size - $diameter), [float]$diameter, [float]$diameter, [float]0, [float]90)
    $path.AddArc([float]0, [float]($size - $diameter), [float]$diameter, [float]$diameter, [float]90, [float]90)
    $path.CloseFigure()
    
    $g.FillPath($brush, $path)

    Write-Host "Step 2: Bolt"
    # 2. Lightning Bolt (Lucide Zap)
    $boltPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $scale = 6.5 
    $offsetX = 128 - (12 * $scale)
    $offsetY = 128 - (12 * $scale)

    # Points Coords
    $x1 = [float]($offsetX + 13 * $scale); $y1 = [float]($offsetY + 2 * $scale)
    $x2 = [float]($offsetX + 3 * $scale); $y2 = [float]($offsetY + 14 * $scale)
    $x3 = [float]($offsetX + 12 * $scale); $y3 = [float]($offsetY + 14 * $scale)
    $x4 = [float]($offsetX + 11 * $scale); $y4 = [float]($offsetY + 22 * $scale)
    $x5 = [float]($offsetX + 21 * $scale); $y5 = [float]($offsetY + 10 * $scale)
    $x6 = [float]($offsetX + 12 * $scale); $y6 = [float]($offsetY + 10 * $scale)

    # Draw Lines
    $boltPath.AddLine($x1, $y1, $x2, $y2)
    $boltPath.AddLine($x2, $y2, $x3, $y3)
    $boltPath.AddLine($x3, $y3, $x4, $y4)
    $boltPath.AddLine($x4, $y4, $x5, $y5)
    $boltPath.AddLine($x5, $y5, $x6, $y6)
    $boltPath.AddLine($x6, $y6, $x1, $y1)
    
    $boltPath.CloseFigure()
    
    $g.FillPath([System.Drawing.Brushes]::White, $boltPath)

    Write-Host "Step 3: Save"
    # 3. Save as PNG-encoded ICO
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytes = $ms.ToArray()
    $ms.Close()
    
    $outputFile = "app_icon.ico"
    $fs = [System.IO.File]::Create($outputFile)
    $bw = New-Object System.IO.BinaryWriter $fs
    
    # ICO Header
    $bw.Write([int16]0) # Reserved
    $bw.Write([int16]1) # Type (1=Icon)
    $bw.Write([int16]1) # Count
    
    # Directory Entry
    $bw.Write([byte]0) # Width (0=256)
    $bw.Write([byte]0) # Height
    $bw.Write([byte]0) # Colors
    $bw.Write([byte]0) # Reserved
    $bw.Write([int16]1) # Planes
    $bw.Write([int16]32) # BitCount
    $bw.Write([int]$pngBytes.Length) # Size
    $bw.Write([int]22) # Offset
    
    # Image Data
    $bw.Write($pngBytes)
    
    $bw.Close()
    $fs.Close()
    
    $g.Dispose()
    $bmp.Dispose()
    $boltPath.Dispose()
    $path.Dispose()
    $brush.Dispose()
    
    Write-Host "Success Generated: $outputFile"
}
catch {
    Write-Error "Failed to generate icon at $_"
    exit 1
}
