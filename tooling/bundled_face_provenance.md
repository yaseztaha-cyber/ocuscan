# Bundled face-test asset: provenance

File: `assets/bundled_face.jpg` (512×512 RGB JPEG, quality 92, 74,962 bytes)
SHA-256: 370adb9cb9dd03ca911ea316fb227495e01095398bc1f71188a3995209b9c81a

## What it is

Downscaled JPEG conversion of `astronaut.png` — a color photograph of
astronaut Eileen Collins.

## Source + license

- Original: NASA Great Images database (via Flickr https://flic.kr/p/r9qvLn).
- Status: **no known copyright restrictions, released into the public
  domain** (per scikit-image dataset documentation, which redistributes
  the same image under BSD-3-Clause packaging of public-domain data).
- Fetched from the scikit-image dataset mirror:
  https://gitlab.com/scikit-image/data/-/raw/master/astronaut.png
- Conversion: PNG → RGB JPEG (quality 92) with Pillow; pixels otherwise
  unmodified. No cropping, no retouching.

## Why this image

- Clearly contains one human face (frontal, eyes visible).
- Not a medical subject; used ONLY for software verification of the
  face-detection pipeline (never for screening, never shown as a result).
- Standard, widely mirrored test image — reproducible by anyone.

## Expected behavior

- TEST A (/dev/vision-core) and Test B (/ml-test) run this file through
  `InputImage.fromFilePath` + a fresh minimal detector.
- EXPECTED: FACE_DETECTED (≥1 face with a bounding box).
- NO_FACE means the detector executed cleanly but missed a known face
  (detector-weakness signal, still proves the engine runs).
- PROCESSING_ERROR (exception) means the detector runtime is broken.

## Replaces

`assets/test_face.jpg` (synthetic generated pattern) + its generator
`tooling/gen_test_face.dart`, removed: a synthetic oracle cannot
distinguish "engine runs" from "engine broken-but-quiet".
