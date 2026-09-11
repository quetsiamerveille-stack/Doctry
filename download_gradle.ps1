# Telechargement Gradle robuste avec reprise, puis extraction
$out = "$env:TEMP\gradle-8.14-all.zip"
$target = 226  # Mo approximatifs attendus
$deadline = (Get-Date).AddMinutes(30)

while ((Get-Date) -lt $deadline) {
    $size = 0
    if (Test-Path $out) { $size = [math]::Round((Get-Item $out).Length/1MB,1) }
    if ($size -ge $target) { break }

    # curl avec reprise (-C -), 10 retry, silencieux
    Start-Process -FilePath "curl.exe" -ArgumentList "-L","-C","-","--retry","10","--retry-delay","3","--connect-timeout","30","-o","$out","https://services.gradle.org/distributions/gradle-8.14-all.zip" -NoNewWindow -Wait
    Start-Sleep 2
}

$final = [math]::Round((Get-Item $out).Length/1MB,1)
"Taille finale: $final Mo" | Out-File "$env:TEMP\gradle_dl_status.txt" -Encoding utf8

if ($final -ge $target) {
    $dest = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.14-all\c2qonpi39x1mddn7hk5gh9iqj"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Move-Item $out "$dest\gradle-8.14-all.zip" -Force
    try {
        Expand-Archive -Path "$dest\gradle-8.14-all.zip" -DestinationPath $dest -Force
        Remove-Item "$dest\gradle-8.14-all.zip" -Force
        if (Test-Path "$dest\gradle-8.14\bin\gradle.bat") {
            "GRADLE_EXTRACT_OK" | Out-File "$env:TEMP\gradle_dl_status.txt" -Append -Encoding utf8
        } else {
            "GRADLE_EXTRACT_FAIL" | Out-File "$env:TEMP\gradle_dl_status.txt" -Append -Encoding utf8
        }
    } catch {
        "EXTRACT_ERROR: $($_.Exception.Message)" | Out-File "$env:TEMP\gradle_dl_status.txt" -Append -Encoding utf8
    }
} else {
    "DOWNLOAD_INCOMPLETE" | Out-File "$env:TEMP\gradle_dl_status.txt" -Append -Encoding utf8
}
