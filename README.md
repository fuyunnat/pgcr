# PGCR — Audi A4L B9 / MHI2Q P0915 Display Lab

PGCR is a **non-destructive sidecar** for the existing MMI Mirror V2.2 project.

## v0.2 direction: Crop / Zoom / Pan

The scale-only experiment proved useful for measuring the stock path, but the upstream renderer clamps the full 1024x480 source so it always fits inside the 1440x455 destination. That prevents a true wide map view.

PGCR v0.2 therefore uses the GLES texture coordinates as a source viewport:

- **FIT** — full upstream source image;
- **WIDE / COVER** — crop top/bottom as needed to fill 1440x455 without stretching;
- **ZOOM** — crop further around the selected center;
- **PAN X/Y** — move the cropped source window left/right/up/down.

The destination remains displayable 3 and the existing V2.2 Java controller remains the sole owner of ctx80.

## Isolation from upstream

Upstream remains:

```
Customization -> mmi mirror
/mnt/app/root/mmi-mirror
mmi-mirror-display
```

PGCR is separate:

```
Customization -> PGCR Display Lab
/mnt/app/root/pgcr
pgcr-mirror-display
```

PGCR does not replace the upstream author's menu, binary, AutoStart, installer or rollback payloads.

## Build requirement

The crop/zoom/pan renderer changes are Native QNX ARMv7 code and require **QNX SDP 6.5** to compile.

Build output:

```
PGCR-Mirror/build/pgcr-mirror-display
```

Copy that binary to:

```
Toolbox/apps/pgcr/pgcr-mirror-display
```

before using `Install/Update PGCR v0.2`.

Development branch: `dev-crop-zoom-pan`.
