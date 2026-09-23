# PGCR — Audi A4L B9 / MHI2Q P0915 Display Lab

PGCR is a **non-destructive sidecar** for the existing MMI Mirror V2.2 project on Audi A4L B9 / `MHI2Q_CN_AUG22_P0915`.

## Design rule

PGCR must not impersonate, rename or overwrite the upstream author's on-car menu.

Upstream remains:

```
Customization -> mmi mirror
```

PGCR appears separately as:

```
Customization -> PGCR Display Lab
```

PGCR files/scripts are namespaced with `pgcr_`.

Stage 1 keeps the already vehicle-proven V2.2 runtime unchanged and tunes only supported geometry values. The first test target is Classic Full 0.63 -> 0.80 with exact rollback.

Upstream base: `Lanye-z/MHI2Q-CarPlay-RGI-MMI-Mirror`.

Development stays on feature branches until vehicle validation.
