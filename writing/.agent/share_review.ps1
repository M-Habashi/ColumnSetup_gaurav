# Prints the public link of the manuscript review page.
# Reuses the running Cloudflare tunnel if it still answers, otherwise starts the server and/or a new tunnel.
$page = 'manuscript2_journal.html'
$urlFile = Join-Path $env:TEMP 'paper2_tunnel_url.txt'
$log = Join-Path $env:TEMP 'paper2_tunnel.log'
function Up($u) { try { (Invoke-WebRequest "$u/$page" -Method Head -TimeoutSec 10).StatusCode -eq 200 } catch { $false } }

if (-not (Up 'http://127.0.0.1:8765')) {
    Start-Process python "`"$PSScriptRoot\review_server.py`"" -WindowStyle Minimized
    Start-Sleep 2
}

$url = if (Test-Path $urlFile) { (Get-Content $urlFile -Raw).Trim() }
if (-not ($url -and (Up $url))) {
    Remove-Item $log -ErrorAction SilentlyContinue
    Start-Process 'C:\Program Files (x86)\cloudflared\cloudflared.exe' 'tunnel --url http://127.0.0.1:8765' -WindowStyle Hidden -RedirectStandardError $log
    do { Start-Sleep 1; $url = (Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue | Select-Object -First 1).Matches.Value } until ($url)
    for ($i = 0; $i -lt 30 -and -not (Up $url); $i++) { Start-Sleep 2 }
    Set-Content $urlFile $url
}
"$url/$page"
