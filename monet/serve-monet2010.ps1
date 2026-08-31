<#
    Statický HTTP server pro lokální archiv monet2010.com.

    Používá raw TcpListener (ne HttpListener), takže port 80 nepotřebuje
    ani administrátora, ani rezervaci přes `netsh http add urlacl`.

    Loguje každý požadavek; 404 se vypisují červeně, což ukazuje přesně
    ty soubory, které SWF za běhu shání a archiv.org je nemá.

    Použití:
        .\serve-monet2010.ps1
        .\serve-monet2010.ps1 -Port 8080
#>
param(
    [string]$Root = (Join-Path $PSScriptRoot 'monet2010'),
    [string]$Address = '127.0.0.1',
    [int]$Port = 80
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

$mime = @{
    '.html' = 'text/html; charset=iso-8859-1'
    '.htm'  = 'text/html; charset=iso-8859-1'
    '.js'   = 'text/javascript; charset=utf-8'
    '.json' = 'application/json'
    '.map'  = 'application/json'
    '.wasm' = 'application/wasm'
    '.swf'  = 'application/x-shockwave-flash'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.png'  = 'image/png'
    '.gif'  = 'image/gif'
    '.ico'  = 'image/x-icon'
    '.xml'  = 'text/xml'
    '.mp3'  = 'audio/mpeg'
    '.flv'  = 'video/x-flv'
    '.css'  = 'text/css'
    '.txt'  = 'text/plain'
}

function Resolve-Target([string]$urlPath) {
    # zahodit query a fragment
    $p = $urlPath.Split('?')[0].Split('#')[0]
    try { $p = [Uri]::UnescapeDataString($p) } catch { }
    if ($p -eq '/' -or $p -eq '') { $p = '/index.html' }
    $rel = $p.TrimStart('/') -replace '/', '\'
    $full = Join-Path $Root $rel
    # ochrana proti path traversal
    try { $full = [IO.Path]::GetFullPath($full) } catch { return $null }
    if (-not $full.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if (Test-Path -LiteralPath $full -PathType Container) {
        $full = Join-Path $full 'index.html'
    }
    return $full
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($Address), $Port)
$listener.Start()

Write-Host ""
Write-Host "  monet2010.com  ->  $Root" -ForegroundColor Cyan
Write-Host "  naslouchám na http://$($Address):$Port/" -ForegroundColor Cyan
Write-Host "  Ctrl+C ukončí" -ForegroundColor DarkGray
Write-Host ""

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.NoDelay = $true
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000

            # --- přečíst hlavičky po prázdný řádek ---
            $buf = [byte[]]::new(8192)
            $sb = [Text.StringBuilder]::new()
            while ($sb.ToString() -notmatch "`r`n`r`n") {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                [void]$sb.Append([Text.Encoding]::ASCII.GetString($buf, 0, $n))
                if ($sb.Length -gt 65536) { break }
            }
            $req = $sb.ToString()
            if ([string]::IsNullOrWhiteSpace($req)) { $client.Close(); continue }

            $line  = ($req -split "`r`n")[0]
            $parts = $line -split ' '
            $method = $parts[0]
            $urlPath = if ($parts.Count -ge 2) { $parts[1] } else { '/' }

            $full = Resolve-Target $urlPath
            $exists = $full -and (Test-Path -LiteralPath $full -PathType Leaf)

            if ($exists) {
                $ext = [IO.Path]::GetExtension($full).ToLower()
                # bezpřípontové soubory (/fr, /en, /es, /jp, /ch) jsou HTML stránky
                $ct = if ($ext -eq '') { 'text/html; charset=iso-8859-1' }
                      elseif ($mime.ContainsKey($ext)) { $mime[$ext] }
                      else { 'application/octet-stream' }

                $body = [IO.File]::ReadAllBytes($full)
                $head = "HTTP/1.1 200 OK`r`n" +
                        "Content-Type: $ct`r`n" +
                        "Content-Length: $($body.Length)`r`n" +
                        "Access-Control-Allow-Origin: *`r`n" +
                        "Cache-Control: no-cache`r`n" +
                        "Connection: close`r`n`r`n"
                $hb = [Text.Encoding]::ASCII.GetBytes($head)
                if ($method -eq 'HEAD') {
                    $stream.Write($hb, 0, $hb.Length)
                } else {
                    $stream.Write($hb, 0, $hb.Length)
                    $stream.Write($body, 0, $body.Length)
                }
                $stream.Flush()
                Write-Host ("  200  {0,-9} {1}" -f "$($body.Length)B", $urlPath) -ForegroundColor DarkGray
            }
            else {
                $msg = [Text.Encoding]::UTF8.GetBytes("404 Not Found`n$urlPath`n`nTento soubor v archivu web.archive.org neexistuje.")
                $head = "HTTP/1.1 404 Not Found`r`n" +
                        "Content-Type: text/plain; charset=utf-8`r`n" +
                        "Content-Length: $($msg.Length)`r`n" +
                        "Connection: close`r`n`r`n"
                $hb = [Text.Encoding]::ASCII.GetBytes($head)
                $stream.Write($hb, 0, $hb.Length)
                $stream.Write($msg, 0, $msg.Length)
                $stream.Flush()
                Write-Host ("  404  {0,-9} {1}" -f '', $urlPath) -ForegroundColor Red
            }
        }
        catch {
            Write-Host ("  ERR  $($_.Exception.Message)") -ForegroundColor DarkYellow
        }
        finally {
            try { $client.Close() } catch { }
        }
    }
}
finally {
    $listener.Stop()
    Write-Host "`n  server zastaven." -ForegroundColor Cyan
}
