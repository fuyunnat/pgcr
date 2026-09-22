# PGCR P0915 — Stage 1 install/test guide

Target vehicle: Audi A4L B9 / MHI2Q_CN_AUG22_P0915 with a working MMI Mirror V2.2 installation.

## What Stage 1 changes

Only the supported runtime geometry key below is changed:

```
MMI_CLASSIC_FULL_SCALE
```

The verified V2.2 native binary, Unified Java JAR, ctx80 ownership, displayable IDs, AutoStart hook and rollback payloads are not replaced by PGCR Stage 1.

## Prepare the SD card

Start from the same known-good MHI2Q-CarPlay-RGI-MMI-Mirror SD card that already works on the vehicle.

Overlay these PGCR paths onto that card:

```
Toolbox/GEM/mqb-mmiMirror.esd
Toolbox/scripts/pgcr_*.sh
```

Do not remove the existing V2.2 payload or Backup directory.

## Install the PGCR Green Menu controls

1. Vehicle safely parked; maintain stable vehicle power.
2. Insert SD card in SD1.
3. Use the normal Audi red Software Update flow to update Toolbox.
4. Let the update finish and reboot normally.
5. Enter Green Engineering Menu.
6. Go to `mqbcoding -> customization -> mmi mirror`.

New entries should appear:

```
PGCR - Show current geometry
PGCR Classic FULL 63% - V2.2 baseline
PGCR Classic FULL 75%
PGCR Classic FULL 80% - first test
PGCR Classic FULL 85%
PGCR Classic FULL 90%
PGCR Classic FULL 95%
PGCR Classic FULL 100% - edge test
PGCR - Restore pre-PGCR geometry
```

## First vehicle test

Start with **80%** only.

The preset helper will:

1. detect whether MMI Mirror is running;
2. stop it if needed;
3. preserve the exact pre-PGCR `config.local` once as `config.local.pgcr-original`;
4. change only `MMI_CLASSIC_FULL_SCALE`;
5. remount `/mnt/app` read-only again;
6. restart Mirror if it was running before the change.

The other three profiles are not changed.

## Rollback

Two rollback choices exist:

- **Classic FULL 63%**: sets the Classic Full scale to the published V2.2 baseline.
- **Restore pre-PGCR geometry**: restores the exact `config.local` captured before the first PGCR preset.

This Stage 1 feature does not uninstall MMI Mirror and does not alter AutoStart.

## Testing sequence

Recommended progression:

```
0.80 -> 0.85 -> 0.90 -> 0.95
```

Use 1.00 only as an edge test after the lower values are checked for clipping.

For every step, photograph the instrument cluster in:
- Classic FULL;
- Classic SMALL;
- CarPlay/Amap map screen;
- a non-map MMI screen.

Do not tune or photograph the engineering menu while driving.
