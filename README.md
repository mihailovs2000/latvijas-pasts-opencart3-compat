# Latvijas Pasts OpenCart 3 compatibility builder

Community compatibility fixes and an Extension Installer package builder for
the official Latvijas Pasts OpenCart 3 module version 1.2.2.

The builder keeps the upstream authorship intact and downloads the original
module from the [official Latvijas Pasts integration page](https://pasts.lv/en/services/e-commerce/ecommerce).
It verifies the exact upstream archives before making any changes.

## What it fixes

- packages the two manual OCMOD files into one installer-ready `install.xml`;
- replaces incorrect `strpos(...) > -1` conditions with strict
  `!== false` checks so unrelated shipping methods are not intercepted;
- enables TLS certificate and hostname verification for remote API requests;
- removes PHP 8.5-deprecated `curl_close()` calls.

The generated archive contains 55 upstream module files plus `install.xml` and
does not contain API credentials or store-specific data.

## Build

Requirements: Windows PowerShell 5.1 or PowerShell 7 and internet access.

```powershell
./build.ps1
```

The result is written to:

```text
dist/latvijas-pasts-1.2.2-opencart3-php85.ocmod.zip
```

For an offline or reproducible build, download the official outer ZIP yourself
and pass it explicitly:

```powershell
./build.ps1 -OfficialBundlePath C:\Downloads\Opencart3.zip
```

Both the outer archive and nested module archive are checked against pinned
SHA-256 hashes. The build stops if Latvijas Pasts replaces either file; update
the hashes only after reviewing the new upstream release.

## Install

1. In OpenCart 3, open **Extensions → Installer** and upload the generated
   `.ocmod.zip` file.
2. Open **Extensions → Modifications** and refresh modifications.
3. Install only the Latvijas Pasts shipping methods and courier module you
   need.
4. Configure contract/API credentials, geo zones and tariffs.
5. Keep every component disabled until a complete test checkout, label and
   courier workflow has passed.

Five shipping components are supplied upstream: parcel terminal, post-office
pickup, Circle K, Express and Mans Pasts. Pasts Courier appears under Modules.

## Compatibility

Validated with OpenCart 3.0.5.1 and PHP 8.5. The builder targets the official
module 1.2.2 archive currently published by Latvijas Pasts. Other OpenCart or
module versions are not assumed compatible.

## Licensing

The builder and repository documentation are MIT licensed. The upstream module
is not relicensed or redistributed here because its download does not include
an explicit redistribution license. See [NOTICE.md](NOTICE.md).
