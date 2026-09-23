# PGCR P0915 — Stage 1 install/test guide

Target vehicle: Audi A4L B9 / `MHI2Q_CN_AUG22_P0915` with an already-working upstream MMI Mirror V2.2 installation.

## Non-destructive rule

PGCR is a **sidecar**. It deliberately does not replace the author's MMI Mirror screen, runtime binaries, install menu, AutoStart menu or rollback payloads.

The original upstream menu stays:

```
mqbcoding -> customization -> mmi mirror
```

PGCR adds a separate menu:

```
mqbcoding -> customization -> PGCR Display Lab
```

All PGCR scripts use the `pgcr_` prefix.

## What Stage 1 changes

Only the installed runtime value below is changed when a preset is selected:

```
MMI_CLASSIC_FULL_SCALE
```

The verified V2.2 native binary, Unified Java JAR, ctx80 ownership, displayable IDs, AutoStart hook and upstream rollback files are not replaced.

## Prepare the SD card

Start from the same known-good upstream V2.2 SD card that already works on the vehicle.

Overlay **only** these PGCR files onto that card:

```
Toolbox/GEM/mqb-pgcrDisplay.esd
Toolbox/scripts/pgcr_*.sh
```

Do **not** replace:

```
Toolbox/GEM/mqb-mmiMirror.esd
Toolbox/apps/mmi-mirror/*
Toolbox/scripts/install_mmi_mirror.sh
Toolbox/scripts/start_mmi_mirror_toolbox.sh
Toolbox/scripts/stop_mmi_mirror_toolbox.sh
Toolbox/scripts/autostart_mmi_mirror_*.sh
```

Keep the upstream `Backup` directory intact.

## Install PGCR controls

1. Vehicle safely parked; maintain stable vehicle power.
2. Insert SD card in SD1.
3. Use the normal Audi red Software Update flow to update Toolbox.
4. Let the update finish and reboot normally.
5. Enter Green Engineering Menu.
6. Go to `mqbcoding -> customization -> PGCR Display Lab`.

The original `mmi mirror` menu should still be present separately.

## First vehicle test

Start with **PGCR Classic Full 80%** only.

The PGCR helper will:

1. detect whether the existing upstream MMI Mirror session is running;
2. use the existing upstream Stop helper if needed;
3. preserve the exact pre-PGCR installed `config.local` once as `config.local.pgcr-original`;
4. change only `MMI_CLASSIC_FULL_SCALE`;
5. remount `/mnt/app` read-only again;
6. use the existing upstream Start helper if Mirror was running before the change.

The other three geometry profiles are left unchanged.

## Rollback

Two rollback choices exist:

- **PGCR Classic Full 63%**: set Classic Full to the current published V2.2 baseline.
- **PGCR - Restore pre-PGCR geometry**: restore the exact installed `config.local` captured before the first PGCR change.

PGCR does not uninstall MMI Mirror and does not change AutoStart.

## Test sequence

Recommended progression:

```
0.80 -> 0.85 -> 0.90 -> 0.95
```

Use 1.00 only after lower values are checked for clipping.

Test parked. Photograph:
- Classic Full;
- Classic Small;
- Amap/CarPlay map;
- a non-map MMI page.
