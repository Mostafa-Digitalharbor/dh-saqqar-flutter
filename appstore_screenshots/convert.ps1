# Converts raw app screenshots into exact App Store Connect dimensions.
#
#   Portrait  sources  -> iPhone 6.5"  : 1284 x 2778  (cover / center-crop)
#   Landscape sources  -> iPad 13"     : 2732 x 2048  (contain / dark pad)
# Note: 1284x2778 is one of the sizes App Store Connect's iPhone 6.5" slot
# accepts (alongside 1242x2688). 1290x2796 is the 6.9"/6.7" size and is
# REJECTED by the 6.5" slot, so we target 1284x2778 here.
#
# Output is flattened to 24-bit RGB PNG (no alpha); App Store rejects alpha.
# Drop your originals into  _source\  (any names) and run this script.

Add-Type -AssemblyName System.Drawing

$root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir   = Join-Path $root '_source'
$phoneOut = Join-Path $root 'iphone_6.5'
$tabOut   = Join-Path $root 'ipad_13'
New-Item -ItemType Directory -Force -Path $phoneOut, $tabOut | Out-Null

# Dark pad colour (matches the app's near-black navy background).
$pad = [System.Drawing.Color]::FromArgb(255, 10, 14, 22)

function Convert-One($inPath, $outPath, $tw, $th, $mode) {
  $img = [System.Drawing.Image]::FromFile($inPath)
  try {
    $flat = New-Object System.Drawing.Bitmap($tw, $th, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($flat)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.Clear($pad)

    $sw = $img.Width; $sh = $img.Height
    if ($mode -eq 'cover') {
      $scale = [Math]::Max($tw / $sw, $th / $sh)
    } else {
      $scale = [Math]::Min($tw / $sw, $th / $sh)
    }
    $dw = [int][Math]::Round($sw * $scale)
    $dh = [int][Math]::Round($sh * $scale)
    $dx = [int][Math]::Round(($tw - $dw) / 2)
    $dy = [int][Math]::Round(($th - $dh) / 2)
    $g.DrawImage($img, $dx, $dy, $dw, $dh)

    $flat.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $flat.Dispose()
  } finally { $img.Dispose() }
}

$files = Get-ChildItem -Path $srcDir -Include *.png, *.jpg, *.jpeg -File -Recurse | Sort-Object Name
if ($files.Count -eq 0) {
  Write-Output ("No images in {0} - drop your screenshots there first." -f $srcDir)
  return
}

$pi = 1; $ti = 1
foreach ($f in $files) {
  $im = [System.Drawing.Image]::FromFile($f.FullName)
  $w = $im.Width; $h = $im.Height; $im.Dispose()
  $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  if ($h -ge $w) {
    $out = Join-Path $phoneOut ("{0:D2}_{1}.png" -f $pi, $base)
    Convert-One $f.FullName $out 1284 2778 'cover'
    Write-Output ("iPhone 1284x2778 from {0} ({1}x{2})" -f $f.Name, $w, $h); $pi++
  } else {
    $out = Join-Path $tabOut ("{0:D2}_{1}.png" -f $ti, $base)
    Convert-One $f.FullName $out 2732 2048 'contain'
    Write-Output ("iPad 2732x2048 from {0} ({1}x{2})" -f $f.Name, $w, $h); $ti++
  }
}
Write-Output ("Done. {0} iPhone + {1} iPad images written." -f ($pi - 1), ($ti - 1))
