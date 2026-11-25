# Design history

PhysIO-4-All began with a BrainHack workshop analysis of brainstem fMRI. The
workshop scripts realigned and smoothed the BOLD series, used PhysIO to model
recorded physiology and motion, and fitted a nuisance-only SPM GLM. Contrast
maps and temporal signal-to-noise ratio (tSNR) gains showed where the model
accounted for variance. [Original BrainHack workflow](https://github.com/mrikasper/brainhack-physio/tree/brainhack23)

## Why datasets and models became separate

The workshop scripts and saved SPM batches combined acquisition details
with analysis choices. For example, the BrainHack recordings needed a
dataset-specific PhysIO slice-count workaround. Keeping that choice with
the dataset allowed a second example, the ds004645 fast-fMRI acquisition,
to use the same pipeline with its own timing and file conventions.
[Pipeline refactor](https://github.com/likeajumprope/PhysIO-4-All/commit/671f54a64c4a2ec452fca02bc8b27889ce05fb84) · [BrainHack timing workaround](https://github.com/likeajumprope/PhysIO-4-All/commit/623ab9e340670801e6add783b552356e8f78005b) · [Fast-fMRI example](https://github.com/likeajumprope/PhysIO-4-All/pull/1)

## What model comparison changed

Comparing RETROICOR combinations with two aCompCor variants on the same run
made it useful to vary the regressors while holding the images and GLM
settings fixed. Quick checks used the first 100 volumes to exercise the
whole workflow. Caching realignment and segmentation by their inputs let
models share that work. Keeping the tissue probabilities also meant that
changing a mask threshold no longer required segmenting the subject again.
[Model family](https://github.com/likeajumprope/PhysIO-4-All/commit/62a34a0950f5f96234a16bda9997cce3526f709e) · [Quick checks and reuse](https://github.com/likeajumprope/PhysIO-4-All/commit/71eec02e8e573a8314ef6e487b593207d2db2de7) · [Shared tissue maps](https://github.com/likeajumprope/PhysIO-4-All/commit/847a20584dad77e27b1db9802506f9816d7746cc)

## Why display alignment and group normalization differ

The first-level maps kept the acquired voxel grid. For group analysis,
warping the 3-D summaries saved the cost of writing a normalized 4-D BOLD
series. During first-level review, scanner coordinates placed the maps
poorly on SPM's glass brain. Reusing the rigid part of the
segmentation affine gave the reports an approximate MNI origin without
resampling the fitted data. Using mean EPI as the segmentation source also
extended this workflow to runs without a T1w. The partial-coverage fast-fMRI
example showed why a plausible glass-brain outline alone is insufficient
evidence of anatomical correspondence.
[Standard-space export](https://github.com/likeajumprope/PhysIO-4-All/commit/73d635d7dffdbafb5c7adf96ccc18d3fbad1bd32) · [Glass-brain alignment and mean-EPI fallback](https://github.com/likeajumprope/PhysIO-4-All/commit/7db7aab9bbe2622a0665207ab32c44f70fd0014a)

For current behavior, see the [pipeline guide](README.md) and
[model settings and scientific references](models/README.md).
