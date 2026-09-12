# Installation NDK 26.3 + sources android-36 - detache
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$jdk = (Get-Content 'C:\Java\jdk17.path' -Raw).Trim()
$env:JAVA_HOME = $jdk
$env:PATH = "$jdk\bin;$env:PATH"

# Nettoyage de l'install interrompu
Remove-Item "$sdk\ndk\26.3.11579264" -Recurse -Force -ErrorAction SilentlyContinue

$log = "$env:TEMP\ndk_install.log"
$deadline = (Get-Date).AddMinutes(45)
$ok = $false
while ((Get-Date) -lt $deadline) {
    & "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --install "ndk;26.3.11579264" 2>&1 | Out-File $log -Append -Encoding utf8
    if (Test-Path "$sdk\ndk\26.3.11579264\source.properties") { $ok = $true; break }
    Start-Sleep 5
}

if ($ok) {
    "NDK_OK" | Out-File "$env:TEMP\ndk_status.txt" -Encoding utf8
} else {
    "NDK_FAIL" | Out-File "$env:TEMP\ndk_status.txt" -Encoding utf8
}
