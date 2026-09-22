# PGCR roadmap

## Stage 1 — reversible geometry-only tuning
- Keep V2.2 runtime binaries and Java controller unchanged.
- Change only supported `config.local` geometry values.
- First vehicle test: Classic + Full from 0.63 -> 0.80.
- Preserve Classic Small / Sport Full / Sport Small at 0.63.
- Record clipping, alignment and readability.
- If clean, test 0.85 / 0.90 / 0.95 incrementally.

## Stage 2 — presets in Green Menu
- Add selectable size presets.
- Add one-click restore to V2.2 baseline.
- Add X/Y nudge controls with bounded values.

## Stage 3 — navigation-focused crop/zoom
- Evaluate cropping CarPlay side dock / non-map UI.
- Create Amap-focused viewport preset.
- Do not alter ctx80 ownership, displayable IDs or recovery seams.

## Safety rules
- Never replace the verified P0915 runtime binaries during Stage 1.
- Never change context routing while geometry testing.
- Keep the original SD-card backup and current working vehicle backup.
- Test parked; do not tune display geometry while driving.
