<#
    Spustí lokální kopii monet2010.com.

    Nahodí statický server nad .\monet2010\ (pokud už neběží) a otevře ho
    v Ruffle. Nativní Ruffle nepodléhá škrcení vykreslování, které postihuje
    skryté záložky prohlížeče — načtení trvá zhruba deset sekund.

    Ruffle binárka není v repu (je velká a platformně specifická). Stáhni si ji
    z https://github.com/ruffle-rs/ruffle/releases a rozbal do .\ruffle-desktop\
    nebo ji dej kamkoli do PATH.

    Použití:
        ./play-monet2010.ps1              # Ruffle desktop (doporučeno)
        ./play-monet2010.ps1 -Browser     # jen server, otevři si /fr sám
#>
param(
    [switch]$Browser,
    [string]$Lang = 'fr',
    [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# --- server: nastartovat jen když port nikdo nedrží ---
$busy = $false
try {
    $probe = [Net.Sockets.TcpClient]::new()
    $probe.Connect('127.0.0.1', $Port)
    $busy = $true
    $probe.Close()
} catch { }

if ($busy) {
    Write-Host "  server uz na portu $Port bezi" -ForegroundColor DarkGray
} else {
    Write-Host "  startuji server na portu $Port ..." -ForegroundColor Cyan
    $pwsh = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    Start-Process -FilePath $pwsh `
        -ArgumentList '-NoProfile', '-File', (Join-Path $root 'serve-monet2010.ps1'), '-Port', $Port `
        -WorkingDirectory $root
    Start-Sleep -Seconds 2
}

$url = "http://127.0.0.1:$Port"

if ($Browser) {
    Write-Host "  otevri: $url/$Lang" -ForegroundColor Cyan
    Write-Host "  (nech zalozku vepredu - na pozadi prohlizec Ruffle uskrti)" -ForegroundColor DarkYellow
    if ($IsMacOS)      { & open "$url/$Lang" }
    elseif ($IsLinux)  { & xdg-open "$url/$Lang" }
    else               { Start-Process "$url/$Lang" }
    return
}

# --- najit Ruffle: v repu, pak v PATH ---
$candidates = @(
    (Join-Path $root 'ruffle-desktop/ruffle.exe'),
    (Join-Path $root 'ruffle-desktop/ruffle'),
    (Join-Path $root 'ruffle-desktop/Ruffle.app/Contents/MacOS/ruffle')
)
$ruffle = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ruffle) {
    $onPath = Get-Command ruffle -ErrorAction SilentlyContinue
    if ($onPath) { $ruffle = $onPath.Source }
}

if (-not $ruffle) {
    Write-Host ""
    Write-Host "  Ruffle nenalezen." -ForegroundColor Yellow
    Write-Host "  Stahni si build pro svou platformu:" -ForegroundColor Yellow
    Write-Host "     https://github.com/ruffle-rs/ruffle/releases" -ForegroundColor Cyan
    Write-Host "  a rozbal do:  $root/ruffle-desktop/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Mezitim to jde i v prohlizeci:  ./play-monet2010.ps1 -Browser" -ForegroundColor DarkGray
    Write-Host ""
    return
}

Write-Host "  spoustim Ruffle (jazyk: $Lang) ..." -ForegroundColor Cyan
& $ruffle "-Plg=$Lang" "$url/index.swf"
