# DOCTRY - arret propre des serveurs
$pidFile = 'C:\Users\Quetsia\Desktop\projet\doctry\.server_pids'
if (Test-Path $pidFile) {
    Get-Content $pidFile | ForEach-Object {
        if ($_ -match '^\d+$') {
            Stop-Process -Id ([int]$_) -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item $pidFile -Force
    "Serveurs arretes"
} else {
    "Aucun PID enregistre"
}
# Filet de securite : tuer tout ce qui occupe les ports
foreach ($port in 8000, 5000) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
        "Port $port libere"
    }
}
