# OcuScan Device Compatibility (v0.5)

No general compatibility is claimed without testing. Matrix to fill per
physical device (Egypt/local matrix first — development and testing
happen in Egypt; do not infer population performance from a few phones):

| Device model | Android | Camera (front/rear) | Lighting | Language | Network | Face | Eyes | Lock | Notes |
|---|---|---|---|---|---|---|---|---|
| _unfilled_ | | | | | | | | | |

## What the app records automatically per device

`/dev` device report (model, OS, lens, sensor orientation, preview
size) + diagnostic export (add FPS/latency/drop counts, ML format,
rotation, stages, versions). Send the export instead of descriptions.

## Known variability axes

Resolution, focus/macro, supported formats (NV21/YUV420/BGRA),
sensor orientation, Play-services availability (ML Kit), low-light
behavior, thermal throttling on long sessions. The fallback config
chain + capability engine exist precisely because of this variance.
Mid/low-end phones: expect lower processing FPS — the latest-frame
strategy keeps the preview smooth while analysis samples.
