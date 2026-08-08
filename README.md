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
dist/nd-pasts-parcel-lockers-1.0.0.ocmod.zip
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

## Compatibility

Tested against OpenCart 3.0.5.x and PHP 8.5. The package uses the standard
OpenCart 3 checkout controller and default extension conventions.

## License

MIT. The implementation in this repository is original and does not contain
the proprietary/unclear-licensed official OpenCart extension source.

Latvijas Pasts and related names are trademarks of their respective owners.
