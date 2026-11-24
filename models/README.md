# Nuisance models

These reusable configurations are independent of the dataset. They specify
preprocessing, PhysIO regressors, GLM settings, and assessment outputs;
acquisition details and file-discovery rules remain under `examples/`.

Select a model with `physio4all_run(..., Model="model-002")`. All six models
use the same six motion parameters with motion censoring disabled, 3 mm
GLM smoothing, 128 s SPM high-pass filter, and AR(1) serial correlations.
There is no global-signal regression. These are nuisance-only assessment
GLMs; they do not include a task design or implement connectivity analysis.

| ID | RETROICOR | HRV | RVT | Anatomical PCA |
| --- | --- | --- | --- | --- |
| model-001 | yes | yes | yes | no |
| model-002 | no | no | no | 4 PCs + mean, separately in WM and CSF |
| model-003 | no | no | no | >50% variance PCs + mean, separately in WM and CSF |
| model-004 | yes | no | no | no |
| model-005 | yes | no | yes | no |
| model-006 | yes | yes | no | no |

The original model-001 batch already enabled HRV, despite its description
mentioning only RETROICOR and RVT. Its physiological orders/delays are
preserved. Motion censoring is now disabled across all models, and new runs
use configuration-keyed output folders.
RETROICOR orders remain cardiac 3, respiratory 4,
interaction 1; HRV/RVT response-function delays remain zero and RVT uses
the Hilbert method.

## Optional motion censoring

`model.physio.movementCensoringEnabled = false` in model-001 is inherited by
all six models. This maps to PhysIO's `censoring_method='none'` and retains
the six motion regressors. Set it to `true` in a model configuration to use
`movementCensoringMethod` and `movementCensoringThreshold` (currently
`"MAXVAL"` and `[3 Inf]`). Older custom configurations without the switch
continue to use their configured censoring method.

CONN includes outlier/scrubbing regressors in its default denoising pipeline.
fMRIPrep produces motion-outlier columns for optional downstream use; it
does not apply denoising itself. These choices are separate from aCompCor's
component selection. Our switch is off to simplify model comparisons.
Even without censoring, physiological component counts and design rank can
still change residual degrees of freedom. For identical input motion and
thresholds, censoring would add the same outlier columns to each model.

Existing cached outputs retain their original censoring. To evaluate this
change, use fresh derivative roots or recompute PhysIO, GLM, and assessment
outputs; do not reuse a GLM fitted with the previous regressor matrix.

## aCompCor settings in PhysIO

The two variants use PhysIO's `model.noise_rois`. Preprocessing and regressor
extraction use the images in this order.

1. **Segment the subject T1w.** SPM writes the bias-corrected T1w and native
   WM and CSF probability maps (`c2` and `c3`) under the subject's `anat/`
   derivative. All runs and quick checks using that T1w, tissue template and
   segmentation settings can share these continuous maps.
2. **Align anatomy to the run.** BOLD realignment corrects motion within the
   functional series. Preprocessing therefore also estimates one rigid
   transform from the bias-corrected T1w to this run's mean BOLD. It saves the
   transform separately so each run can use the same native tissue maps.
3. **Make extraction masks.** During `compute_physio`, threshold each posterior
   at >0.5 and erode once on the anatomical grid. Apply the saved transform
   to both mask headers and reslice with nearest-neighbour interpolation.
   The masks must match the unsmoothed BOLD grid and retain enough voxels.
   Changing the threshold or erosion selects new masks.
4. **Extract regressors with PhysIO.** PhysIO can register each supplied ROI
   separately and threshold and erode after reslicing to the functional grid.
   One BOLD voxel can cover several anatomical voxels. To preserve the native
   erosion and the shared anatomical transform, pass the prepared binary masks
   with `thresholds=0.5`, `n_voxel_crop=0`, and `force_coregister='No'`.
   PhysIO extracts means and PCs from **unsmoothed realigned** BOLD. The GLM
   uses smoothed BOLD. Inspect mask overlays, especially for partial coverage.

For model-002, `n_components=[4 4]` requests four PCs per tissue. PhysIO adds
the mean automatically, yielding ten anatomical regressors. For model-003,
`n_components=[0.5 0.5]` requests enough PCs to strictly exceed 50% cumulative
variance in each tissue, followed by the additional means. Thus its regressor
count varies across subjects/runs. These fractions refer to PhysIO's
mean-centered PCA variance, not the variance of the final voxelwise GLM.

PhysIO removes voxelwise means and linear trends before PCA and centers the
data across voxels. It does not implement CONN's projection against all other
confounds before PCA, or fMRIPrep's pre-PCA high-pass filtering. The downstream
SPM high-pass filter is retained consistently across this model family.
PhysIO's small-ROI PCA fallback can require Statistics and Machine Learning
Toolbox when the number of ROI voxels does not exceed the number of volumes.

## Relationship to CONN, fMRIPrep, and the cited comparison

[CONN's current denoising documentation](https://web.conn-toolbox.org/fmri-methods/denoising-pipeline)
describes a tissue mean plus four PCs from each of eroded WM/CSF masks
(posterior >50%). It also uses motion derivatives, scrubbing, session/task
terms, and temporal filtering; its PCA is conditioned on other confounds.
Model-002 adopts the tissue/component-count choice, while retaining the
common PhysIO-4-All motion and GLM settings. It is a CONN-inspired PhysIO
model, not an exact reproduction of the CONN denoising pipeline.

[fMRIPrep's current output documentation](https://fmriprep.org/en/stable/outputs.html#confounds)
describes separate WM, CSF, and combined-mask decompositions, by default
retaining components explaining the top 50% of variance. Users choose a
subset of decompositions for denoising. Model-003 adopts the variance rule
for separate WM and CSF, without importing fMRIPrep outputs or adding a
combined-mask decomposition. PhysIO's extra means, masks, detrending, and
PCA implementation remain different. It should be described as a
fMRIPrep-inspired selection rule, not as fMRIPrep-equivalent confounds.

The **February 22, 2023 version** of
[Krentz et al., doi:10.1101/2023.02.22.529506](https://doi.org/10.1101/2023.02.22.529506)
(section 2.3.2; [accessible full text](https://www.researchgate.net/publication/368828287_A_Comparison_of_fMRI_Data-Derived_and_Physiological_Data-Derived_Methods_for_Physiological_Noise_Correction))
selected the first **five PCA components total** from the fMRIPrep confounds
file, described as derived from WM and CSF masks. The passage does not
identify the exact mask provenance of each selected column. It does not
specify five components per tissue or variance-based selection. The authors
compared aCompCor, ICA-AROMA, RETROICOR, and combinations; RETROICOR had 18
regressors. Their comparison used shuffled additional regressors to balance
degrees of freedom and 6 mm smoothing in the tSNR analysis. Neither model-002
nor model-003 is a replication of that complete protocol. Later preprint
revisions exist; these method details are explicitly tied to the 2023 text.

## Running and comparing

```matlab
physio4all_setup
results = physio4all_run("fastfmri", Subject="sub-01", Run=1, ...
    Model="model-002");
results = physio4all_run("fastfmri", Subject="sub-01", Run=1, ...
    Model="model-003");
```

Use `Stages="compute_physio"` to stop after preprocessing and regressors.
`QuickCheck=true` limits any model/dataset to the first 100 volumes;
`QuickCheckVolumes` changes the limit. Quick-check outputs use their own
run namespace. See the main README for a complete invocation using TEMP
work and derivative roots.

Preprocessed images use a shared input/settings cache beneath `preproc/`.
WM/CSF mask preparation is shared there too. Compatible models reuse these
images and masks; the PCA regressors themselves remain model-specific.
PhysIO/GLM/assessment folders include an analysis-configuration key so that
changing component counts, censoring, or other model settings selects new
downstream outputs. Keys identify inputs by path, size, and modification
time rather than reading/hash-checking entire imaging files.
`OverwriteFrom="none"` reuses compatible completed stages and fills missing
ones. Choose `"preprocess"` (or `"all"`), `"compute_physio"`, `"fit_glm"`, or
`"assess_physio"` to force recomputation from that stage inclusively, up to
the endpoint requested by `Stages`. Upstream compatible products are reused.
Regenerated upstream products change downstream cache keys, including when
a later invocation requests stages beyond the current endpoint.
For a persistent new configuration, copy a model to the next unused ID,
update its `model.id` and settings, and add it to the catalog above.

Before a scientific comparison, inspect masks, motion censoring, regressor
rank and residual degrees of freedom. A higher in-sample tSNR alone does not
establish better physiological specificity, especially when model-003 uses
a different number of components. Use the same runs and preprocessing for
all models and account for differing model complexity in the comparison.

The previously processed local examples used older directory names:
`derivatives/openneuro_ds004645/` and `derivatives/brainhack23_ds004808/`.
Current canonical IDs are `openneuro_ds004645_fastfmri` and
`openneuro_ds004808_brainhack23`. Older unkeyed checkpoints are retained as
historical results. New pipeline runs use signature-based cache folders and
do not automatically import checkpoints lacking settings provenance.
