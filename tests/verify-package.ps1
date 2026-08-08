param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ArchivePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('latvijas-pasts-package-test-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $workRoot | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $workRoot

    $files = @(Get-ChildItem -Path $workRoot -Recurse -File)
    $uploadFiles = @(Get-ChildItem -Path (Join-Path $workRoot 'upload') -Recurse -File)
    $phpFiles = @($uploadFiles | Where-Object Extension -eq '.php')
    $compatibilityFiles = @($files | Where-Object Extension -in '.php', '.xml')

    if ($files.Count -ne 56) { throw "Expected 56 package files, found $($files.Count)." }
    if ($uploadFiles.Count -ne 55) { throw "Expected 55 upload files, found $($uploadFiles.Count)." }
    if ($phpFiles.Count -ne 43) { throw "Expected 43 PHP files, found $($phpFiles.Count)." }
    if (-not (Test-Path -LiteralPath (Join-Path $workRoot 'install.xml'))) { throw 'install.xml is missing.' }
    if (Test-Path -LiteralPath (Join-Path $workRoot 'upload/system/pasts.ocmod.xml')) { throw 'Manual storefront OCMOD was packaged twice.' }
    if (Test-Path -LiteralPath (Join-Path $workRoot 'upload/system/pastsadmin.ocmod.xml')) { throw 'Manual admin OCMOD was packaged twice.' }

    [xml]$modification = Get-Content -LiteralPath (Join-Path $workRoot 'install.xml') -Raw
    if ($modification.modification.code -ne 'latvijas-pasts-shipping-1-2-2') { throw 'Unexpected OCMOD code.' }
    if (@($modification.modification.file).Count -ne 13) { throw 'Expected 13 OCMOD file targets.' }

    $combinedText = ($compatibilityFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    if ($combinedText.Contains('> -1')) { throw 'Unsafe strpos comparison remains.' }
    if ($combinedText.Contains('curl_close(')) { throw 'Deprecated curl_close() remains.' }
    if ($combinedText.Contains('CURLOPT_SSL_VERIFYPEER, false')) { throw 'TLS peer verification is disabled.' }
    if ($combinedText.Contains('CURLOPT_SSL_VERIFYHOST, false')) { throw 'TLS hostname verification is disabled.' }

    $strictCount = ([regex]::Matches($combinedText, [regex]::Escape('!== false'))).Count
    if ($strictCount -lt 25) { throw "Expected at least 25 strict strpos checks, found $strictCount." }

    Write-Host "Package verification passed: $($files.Count) files, $($phpFiles.Count) PHP files, $strictCount strict strpos checks."
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}
