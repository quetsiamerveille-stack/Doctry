# DOCTRY - demarrage des deux serveurs en processus detachables
# Usage: powershell -File start_servers.ps1
$ErrorActionPreference = 'SilentlyContinue'
$root = 'C:\Users\Quetsia\Desktop\projet\doctry'

# Nettoyage des anciens PIDs
$pidFile = Join-Path $root '.server_pids'
if (Test-Path $pidFile) {
    Get-Content $pidFile | ForEach-Object {
        if ($_ -match '^\d+$') {
            Stop-Process -Id ([int]$_) -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item $pidFile -Force
}

# Ports libres ?
foreach ($port in 8000, 5000) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 500
    }
}

Start-Sleep -Seconds 1

# Demarrage backend (uvicorn, sans reload pour stabilite)
$backendCmd = '& "C:\Users\Quetsia\Desktop\projet\doctry\backend\.venv\Scripts\python.exe" -m uvicorn app.main:app --host 127.0.0.1 --port 8000'
$p1 = Start-Process powershell -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-Command', "Set-Location 'C:\Users\Quetsia\Desktop\projet\doctry\backend'; `$env:PYTHONHOME=`$null; $backendCmd" -PassThru -WindowStyle Hidden

# Demarrage frontend (http.server statique)
$p2 = Start-Process powershell -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-Command', "Set-Location 'C:\Users\Quetsia\Desktop\projet\doctry'; python -m http.server 5000 --directory build\web --bind 127.0.0.1" -PassThru -WindowStyle Hidden

# Enregistrement des PIDs pour arret propre ulterieur
"$($p1.Id)`n$($p2.Id)" | Out-File $pidFile -Encoding ascii

# Attente de sante
$deadline = (Get-Date).AddSeconds(40)
$okB = $false
$okF = $false
while ((Get-Date) -lt $deadline -and (-not $okB -or -not $okF)) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/api/health -TimeoutSec 2
        if ($r.StatusCode -eq 200) { $okB = $true }
    } catch {}
    try {
        $f = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:5000/ -TimeoutSec 2
        if ($f.StatusCode -eq 200) { $okF = $true }
    } catch {}
    Start-Sleep -Milliseconds 700
}

Write-Output "Backend  : $(if ($okB) {'OK http://127.0.0.1:8000'} else {'ECHEC'})"
Write-Output "Frontend : $(if ($okF) {'OK http://127.0.0.1:5000'} else {'ECHEC'})"
Write-Output "PIDs     : backend=$($p1.Id) frontend=$($p2.Id)"
