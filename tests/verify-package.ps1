param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ArchivePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('latvijas-pasts-test-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $workRoot | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $workRoot

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        if ($zip.Entries[0].FullName -ne 'install.xml') {
            throw 'install.xml must be the first ZIP entry for the OpenCart installer.'
        }
        if (@($zip.Entries | Where-Object { $_.FullName.Contains('\') }).Count -ne 0) {
            throw 'ZIP entry names must use forward slashes.'
        }
    }
    finally {
        $zip.Dispose()
    }

    $required = @(
        'install.xml',
        'upload/admin/controller/extension/shipping/latvijas_pasts.php',
        'upload/admin/view/template/extension/shipping/latvijas_pasts.twig',
        'upload/catalog/model/extension/shipping/latvijas_pasts.php'
    )

    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $workRoot $relative))) {
            throw "Required package file is missing: $relative"
        }
    }

    [xml]$modification = Get-Content -LiteralPath (Join-Path $workRoot 'install.xml') -Raw
    if ($modification.modification.code -ne 'latvijas-pasts-parcel-lockers') {
        throw 'Unexpected OCMOD code.'
    }
    if ($modification.modification.name -ne 'Latvijas Pasts Parcel Lockers for OpenCart 3') {
        throw 'Unexpected public module name.'
    }
    if ($modification.modification.version -ne '1.0.0') {
        throw 'Unexpected module version.'
    }

    $allText = (Get-ChildItem -Path $workRoot -Recurse -File | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw
    }) -join "`n"

    foreach ($forbidden in @('CURLOPT_SSL_VERIFYPEER, false', 'shell_exec(', 'eval(', 'base64_decode(')) {
        if ($allText.Contains($forbidden)) {
            throw "Forbidden construct found: $forbidden"
        }
    }

    if (-not $allText.Contains('CURLOPT_CONNECTTIMEOUT')) { throw 'HTTP connect timeout is missing.' }
    if (-not $allText.Contains('CURLOPT_TIMEOUT')) { throw 'HTTP request timeout is missing.' }
    if (-not $allText.Contains('hash_equals')) { throw 'Constant-time terminal id validation is missing.' }
    if (-not $allText.Contains('#collapse-shipping-method select')) { throw 'Checkout does not submit the selected parcel locker.' }

    $legacyIdentifiers = @('nd' + '_pasts', 'nd' + '-pasts', 'ND' + ' Pasts')
    foreach ($legacyIdentifier in $legacyIdentifiers) {
        if ($allText.Contains($legacyIdentifier)) {
            throw "Legacy store-specific identifier remains in the package: $legacyIdentifier"
        }
    }

    Write-Host 'Package verification passed.'
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}
