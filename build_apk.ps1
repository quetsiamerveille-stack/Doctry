# Build APK release DOCTRY - processus detache avec journal
$root = 'C:\Users\Quetsia\Desktop\projet\doctry'
$jdk = (Get-Content 'C:\Java\jdk17.path' -Raw).Trim()

Set-Location $root
$env:JAVA_HOME = $jdk
$env:PATH = "$jdk\bin;$env:PATH"

# Purge des anciens logs
Remove-Item "$root\apk_build.log", "$root\apk_build.exit" -Force -ErrorAction SilentlyContinue

flutter build apk --release 2>&1 | Out-File "$root\apk_build.log" -Encoding utf8
"exit=$LASTEXITCODE" | Out-File "$root\apk_build.exit" -Encoding ascii
