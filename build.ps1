param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'dist/nd-pasts-parcel-lockers-1.0.0.ocmod.zip')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nd-pasts-build-' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $stageRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.xml') -Destination $stageRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'upload') -Destination $stageRoot -Recurse

    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = Split-Path -Parent $resolvedOutput
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

    if (Test-Path -LiteralPath $resolvedOutput) {
        Remove-Item -LiteralPath $resolvedOutput
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($resolvedOutput, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            (Join-Path $stageRoot 'install.xml'),
            'install.xml',
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null

        $uploadRoot = Join-Path $stageRoot 'upload'
        foreach ($file in Get-ChildItem -LiteralPath $uploadRoot -Recurse -File | Sort-Object FullName) {
            $relative = 'upload/' + $file.FullName.Substring($uploadRoot.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $file.FullName,
                $relative,
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }
    & (Join-Path $PSScriptRoot 'tests/verify-package.ps1') $resolvedOutput

    Write-Host "Built: $resolvedOutput"
    Write-Host "SHA-256: $((Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash)"
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
