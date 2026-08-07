# From BrainHack Prototype to PhysIO-4-All

PhysIO-4-All grew from the lightweight brainstem-fMRI workflow in the
[`brainhack23` branch of `mrikasper/brainhack-physio`](https://github.com/mrikasper/brainhack-physio/tree/brainhack23).
That repository demonstrated the complete scientific sequence for one example:
SPM realignment and smoothing, PhysIO regressor creation, a nuisance-only GLM,
and visual assessment with statistical and tSNR maps.

## What was retained

- The intentionally lightweight SPM preprocessing.
- PhysIO regressors combining RETROICOR, RVT, HRV, and movement terms.
- A nuisance-only first-level SPM GLM for assessing physiological-noise models.
- Statistical-map and tSNR-gain outputs for visual quality assessment.
- Dataset-specific workarounds, including the documented BrainHack
  `Nslices=28` timing-log workaround.

## What was generalized

The original script and saved `matlabbatch` jobs mixed reusable analysis logic
with paths and parameters for a particular dataset. PhysIO-4-All separates
those concerns:

- `examples/` defines dataset discovery, acquisition metadata, and known
  dataset-specific behavior.
- `models/` defines reusable preprocessing, PhysIO, GLM, and assessment choices.
- `src/+physio4all/` implements the shared pipeline as a MATLAB namespace.
- `physio4all_run` provides one public entry point for selecting an example,
  subject, run, model, stages, and storage roots.
- `data/`, `work/`, and `derivatives/` separate immutable downloads,
  disposable SPM intermediates, and durable results.

The pipeline also gained resumable checkpoints, model-labelled GLM and
assessment outputs, predictable diary logs, configurable scratch storage, and
tests for configuration and batch construction.

## Current pipeline shape

```text
downloaded data
    -> realign/reslice and smooth
    -> compute PhysIO regressors
    -> specify and estimate nuisance GLM
    -> export statistical maps and tSNR gains
```

This preserves the original BrainHack analysis theme while making it possible
to add another public dataset mainly by supplying a small example definition
and, only when the analysis changes, a new model definition.

## Adding another example

1. Add `examples/<example-id>/physio4all_example_<example_id>.m` with file
   patterns, acquisition settings, and documented dataset workarounds.
2. Add a short example README describing the source data and invocation.
3. Reuse an existing `model-###`, or add a model when analysis parameters—not
   merely dataset paths or acquisition metadata—change.
4. Extend file-resolution and batch-construction tests before running the full
   dataset.

