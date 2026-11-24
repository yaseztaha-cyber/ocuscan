# OcuScan Dataset Cards (v0.5)

**No external datasets are used in this build.** No training images, no
downloaded weights, no bundled patient data. The research workspace can
record local experiments/trials/reference labels; those are the
researcher's own data with their own provenance, stored on-device.

## Policy (binding for future work)

No dataset enters the project without a card containing: dataset,
source, population, sample count, labels, image modality, device,
geography, age distribution, known limitations, license. Datasets
without provenance are rejected. Real medical patient data requires
appropriate permissions before use; the regression set uses only
synthetic/consented captures.

## Regression dataset (internal, non-medical)

Camera-processing regression coverage uses synthetic frames (solid
planes, checkerboards, gradients) in unit tests — no human subjects,
no medical content. Purpose: prevent processing changes from breaking
known image handling (strides, rotation, sampling).
