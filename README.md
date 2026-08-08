# Latvijas Pasts parcel lockers for OpenCart 3

An independent, open-source OpenCart 3 shipping extension for choosing a
Latvijas Pasts parcel locker during checkout. The parcel-locker list uses the
public Latvijas Pasts endpoint, so API credentials are not required for this
part of checkout.

## Features

- one compact, searchable parcel-locker selector instead of hundreds of
  shipping radio buttons;
- Latvia, Lithuania and Estonia support;
- fixed price, free-shipping threshold, tax class and geo-zone settings;
- 24-hour local cache with stale-cache fallback if the public service is down;
- server-side terminal validation before checkout continues;
- the selected locker name is stored in OpenCart's standard order shipping
  method field, without a custom database table;
- optional API credentials are deliberately outside this module's scope;
- compatible with PHP 7.4 through PHP 8.5.

This project is a community integration. It is not an official Latvijas Pasts
release and does not imply endorsement.

## Build

On Windows PowerShell 5.1 or PowerShell 7:

```powershell
./build.ps1
```

The installer is created at:

```text
dist/latvijas-pasts-parcel-lockers-opencart3-1.0.0.ocmod.zip
```

## Install

1. Open **Extensions → Installer** in OpenCart and upload the `.ocmod.zip`.
2. Open **Extensions → Modifications** and refresh modifications.
3. Open **Extensions → Extensions → Shipping** and install
   **Latvijas Pasts parcel lockers**.
4. Configure the price, geo zone, tax class and status.
5. Test checkout without placing a real order.

The price field is a normal fixed amount in the store's base currency. The
module does not need contract credentials to display or validate parcel
lockers. Shipment creation and label printing can be added later as a separate
integration once API access is available.

## Why use this instead of the legacy EcomBaltic 1.2.2 extension?

This project was written as a focused replacement after reviewing and running
the older Latvijas Pasts OpenCart 3 extension published by EcomBaltic. The
comparison below describes the tested 1.2.2 package, not later vendor releases.

| Area | This module | Legacy EcomBaltic 1.2.2 package |
| --- | --- | --- |
| Checkout UI | One compact searchable selector | Can render a separate shipping row for every parcel locker |
| Locker list | Public endpoint; no contract credentials required | Configuration is coupled to the wider contract integration |
| Price | Validated fixed price plus an optional free-shipping threshold | A plain numeric tariff can reach a weight-rate parser and fail on PHP 8.5 |
| PHP | Tested on PHP 8.5 and targets PHP 7.4–8.5 | Contains compatibility issues with current PHP releases |
| Network safety | TLS peer/hostname verification and explicit connect/request timeouts | The reviewed package disables certificate verification in some requests |
| Availability | 24-hour cache with stale-cache fallback | Checkout depends more directly on the remote service |
| Storage | Uses standard OpenCart order shipping fields; no module tables | Adds custom order/shipment/courier tables |
| Scope | Parcel-locker selection only | Also includes labels, shipments, courier and several pickup methods |

The narrower scope is intentional: choosing a locker should work before
contract credentials arrive. Label printing, shipment creation and courier
workflows belong in an optional contract-API integration. This module is
independent and is not affiliated with or endorsed by Latvijas Pasts or
EcomBaltic.

## Compatibility

Tested against OpenCart 3.0.5.x and PHP 8.5. The package uses the standard
OpenCart 3 checkout controller and default extension conventions.

## License

MIT. The implementation in this repository is original and does not contain
the proprietary/unclear-licensed official OpenCart extension source.

Latvijas Pasts and related names are trademarks of their respective owners.
