param(
    [string]$OfficialBundlePath,
    [string]$OutputPath = (Join-Path $PSScriptRoot 'dist/latvijas-pasts-1.2.2-opencart3-php85.ocmod.zip')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$officialUrl = 'https://pasts.lv/media/1201/download/Opencart3%20%284%29.zip'
$outerSha256 = '5D2A757F4E36A883D418D272C8185026031D662B8BC6943AD757218475B1E2EE'
$moduleSha256 = 'A88AB2769B28614B0A6E6B60853F215D9BE265B78C1DD34BE7CB2FA74F27B107'
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('latvijas-pasts-compat-build-' + [guid]::NewGuid().ToString('N'))

function Assert-Sha256 {
    param([string]$Path, [string]$Expected, [string]$Label)

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "$Label SHA-256 mismatch. Expected $Expected, got $actual. Refusing to patch unreviewed upstream code."
    }
}

function Set-CompatibilityText {
    param([string]$Text, [switch]$Ocmod)

    $result = $Text
    if ($Ocmod) {
        $result = $result.Replace('> -1', '!== false')
    }

    $result = $result.Replace('CURLOPT_SSL_VERIFYPEER, false', 'CURLOPT_SSL_VERIFYPEER, true')
    $result = $result.Replace('CURLOPT_SSL_VERIFYHOST, false', 'CURLOPT_SSL_VERIFYHOST, 2')
    $result = $result.Replace('CURLOPT_SSL_VERIFYPEER, $checkCert', 'CURLOPT_SSL_VERIFYPEER, true')
    $result = $result.Replace('CURLOPT_SSL_VERIFYHOST, $checkCert', 'CURLOPT_SSL_VERIFYHOST, 2')
    $result = [regex]::Replace($result, '(?m)^[\t ]*curl_close\(\$(?:ch|curl)\);[\t ]*\r?\n', '')
    return $result
}

try {
    New-Item -ItemType Directory -Path $workRoot | Out-Null
    $bundlePath = Join-Path $workRoot 'official-bundle.zip'

    if ($OfficialBundlePath) {
        Copy-Item -LiteralPath (Resolve-Path -LiteralPath $OfficialBundlePath).Path -Destination $bundlePath
    }
    else {
        Write-Host 'Downloading the official Latvijas Pasts OpenCart 3 bundle...'
        Invoke-WebRequest -UseBasicParsing -Uri $officialUrl -OutFile $bundlePath
    }

    Assert-Sha256 $bundlePath $outerSha256 'Official outer bundle'

    $outerRoot = Join-Path $workRoot 'outer'
    Expand-Archive -LiteralPath $bundlePath -DestinationPath $outerRoot
    $moduleArchive = Join-Path $outerRoot 'pasts-opencart-3-v1.2.2.zip'
    if (-not (Test-Path -LiteralPath $moduleArchive)) { throw 'The reviewed nested module archive is missing.' }
    Assert-Sha256 $moduleArchive $moduleSha256 'Official module archive'

    $moduleRoot = Join-Path $workRoot 'module'
    Expand-Archive -LiteralPath $moduleArchive -DestinationPath $moduleRoot

    $stageRoot = Join-Path $workRoot 'stage'
    $uploadRoot = Join-Path $stageRoot 'upload'
    New-Item -ItemType Directory -Path $uploadRoot | Out-Null
    foreach ($directory in 'admin', 'catalog', 'image', 'system') {
        Copy-Item -LiteralPath (Join-Path $moduleRoot $directory) -Destination $uploadRoot -Recurse
    }
    Remove-Item -LiteralPath (Join-Path $uploadRoot 'system/pasts.ocmod.xml')
    Remove-Item -LiteralPath (Join-Path $uploadRoot 'system/pastsadmin.ocmod.xml')

    $phpFiles = @(Get-ChildItem -Path $uploadRoot -Recurse -File -Filter '*.php')
    if ($phpFiles.Count -ne 43) { throw "Expected 43 upstream PHP files, found $($phpFiles.Count)." }
    foreach ($phpFile in $phpFiles) {
        $source = [System.IO.File]::ReadAllText($phpFile.FullName)
        $patched = Set-CompatibilityText $source
        [System.IO.File]::WriteAllText($phpFile.FullName, $patched, [System.Text.UTF8Encoding]::new($false))
    }

    $shippingText = Set-CompatibilityText ([System.IO.File]::ReadAllText((Join-Path $moduleRoot 'system/pasts.ocmod.xml'))) -Ocmod
    $adminText = Set-CompatibilityText ([System.IO.File]::ReadAllText((Join-Path $moduleRoot 'system/pastsadmin.ocmod.xml'))) -Ocmod

    $shippingXml = [System.Xml.XmlDocument]::new()
    $shippingXml.PreserveWhitespace = $true
    $shippingXml.LoadXml($shippingText)
    $adminXml = [System.Xml.XmlDocument]::new()
    $adminXml.PreserveWhitespace = $true
    $adminXml.LoadXml($adminText)

    $installXml = [System.Xml.XmlDocument]::new()
    $declaration = $installXml.CreateXmlDeclaration('1.0', 'utf-8', $null)
    [void]$installXml.AppendChild($declaration)
    $root = $installXml.CreateElement('modification')
    [void]$installXml.AppendChild($root)
    foreach ($pair in @(
        @('code', 'latvijas-pasts-shipping-1-2-2'),
        @('name', 'Latvijas Pasts Shipping Module'),
        @('version', '1.2.2'),
        @('author', 'EcomBaltic')
    )) {
        $element = $installXml.CreateElement($pair[0])
        $element.InnerText = $pair[1]
        [void]$root.AppendChild($element)
    }
    foreach ($sourceXml in @($shippingXml, $adminXml)) {
        foreach ($fileNode in @($sourceXml.modification.file)) {
            [void]$root.AppendChild($installXml.ImportNode($fileNode, $true))
        }
    }

    $installPath = Join-Path $stageRoot 'install.xml'
    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.NewLineChars = "`n"
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $writer = [System.Xml.XmlWriter]::Create($installPath, $settings)
    try { $installXml.Save($writer) } finally { $writer.Dispose() }

    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = Split-Path -Parent $resolvedOutput
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $resolvedOutput) { Remove-Item -LiteralPath $resolvedOutput }
    Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $resolvedOutput -CompressionLevel Optimal

    & (Join-Path $PSScriptRoot 'tests/verify-package.ps1') $resolvedOutput
    $outputHash = (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash
    Write-Host "Built: $resolvedOutput"
    Write-Host "SHA-256: $outputHash"
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}
