<#
    Vygeneruje minimální validní (nekomprimovaný) SWF.

    Slouží jako záplata za moduly monet2010.com, které archive.org nikdy
    nestáhl. index.swf je načítá přes Loader a čeká na Event.INIT; když
    dostane 404, event nikdy nepřijde a loader visí navěky. Prázdný, ale
    platný SWF ten event vyvolá a aplikace se posune dál.

    POZOR: tohle NENÍ původní obsah. Je to náhrada, aby web nezamrzl.

    Použití:
        .\make-stub-swf.ps1 -Path .\monet2010\myvoyage_fr.swf
#>
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$WidthPx  = 960,
    [int]$HeightPx = 600,
    [int]$Fps      = 24
)

$ErrorActionPreference = 'Stop'

# --- zapisovač bitového proudu (SWF RECT je bitově zarovnaný) ---
$bits = [System.Collections.Generic.List[int]]::new()
function Add-Bits([int]$value, [int]$count) {
    for ($i = $count - 1; $i -ge 0; $i--) { $bits.Add(($value -shr $i) -band 1) }
}

# RECT: nbits, pak xmin/xmax/ymin/ymax po nbits bitech. Jednotky = twips (1px = 20).
$xmax = $WidthPx * 20
$ymax = $HeightPx * 20
$need = [Math]::Max([Convert]::ToString($xmax, 2).Length, [Convert]::ToString($ymax, 2).Length) + 1
Add-Bits $need 5
Add-Bits 0 $need
Add-Bits $xmax $need
Add-Bits 0 $need
Add-Bits $ymax $need
while ($bits.Count % 8 -ne 0) { $bits.Add(0) }

$rect = [System.Collections.Generic.List[byte]]::new()
for ($i = 0; $i -lt $bits.Count; $i += 8) {
    $b = 0
    for ($j = 0; $j -lt 8; $j++) { $b = ($b -shl 1) -bor $bits[$i + $j] }
    $rect.Add([byte]$b)
}

# --- tělo: RECT + frameRate (8.8 fixed) + frameCount + tagy ---
$body = [System.Collections.Generic.List[byte]]::new()
$body.AddRange($rect)
$body.Add([byte]0); $body.Add([byte]$Fps)        # frameRate: zlomek, celá část
$body.Add([byte]1); $body.Add([byte]0)           # frameCount = 1

function Add-Tag([int]$code, [byte[]]$data) {
    $hdr = ($code -shl 6) -bor $data.Length      # krátká hlavička tagu (délka < 63)
    $body.Add([byte]($hdr -band 0xFF))
    $body.Add([byte](($hdr -shr 8) -band 0xFF))
    if ($data.Length) { $body.AddRange($data) }
}

Add-Tag 9 ([byte[]]@(0xCC, 0xCC, 0xCC))          # SetBackgroundColor - shodné s webem
Add-Tag 1 ([byte[]]@())                          # ShowFrame
Add-Tag 0 ([byte[]]@())                          # End

# --- hlavička: 'FWS' + verze + celková délka ---
$total = 8 + $body.Count
$out = [System.Collections.Generic.List[byte]]::new()
$out.AddRange([byte[]]@(0x46, 0x57, 0x53))       # FWS = nekomprimovaný
$out.Add([byte]10)                               # SWF verze 10
$out.AddRange([BitConverter]::GetBytes([uint32]$total))
$out.AddRange($body)

$dir = Split-Path $Path -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllBytes($Path, $out.ToArray())

"{0}  ({1} B, {2}x{3})" -f $Path, $out.Count, $WidthPx, $HeightPx
