# Analysis Models

This folder contains reusable pipeline configurations. Dataset examples select
a default model by ID, but the models are not tied to a particular dataset.

Each model describes the analysis decisions that can change independently of
the input data: preprocessing, PhysIO regressors, GLM specification, and
assessment outputs. Acquisition details and file-discovery rules remain under
`examples/`.

## Model catalog

### `model-001` — PhysIO nuisance model with 3 mm smoothing

Configuration: [`physio4all_model_001.m`](physio4all_model_001.m)

Pipeline:

```text
realign → smooth (3 mm) → RETROICOR + RVT + movement → nuisance-only SPM GLM
        → Cardiac/RVT statistical maps → raw, corrected, and ratio tSNR maps
```

Key choices:

- 3 mm isotropic smoothing
- third-order cardiac and fourth-order respiratory RETROICOR
- first-order cardiac–respiratory interactions
- RVT from the Hilbert respiratory phase
- six motion regressors
- 128-second GLM high-pass filter and AR(1) serial correlations
- Cardiac and RespiratoryVolumePerTime assessment contrasts

To change analysis parameters without replacing existing results, copy the
configuration to the next unused ID (for example,
`physio4all_model_002.m`), update its `model.id`, parameters, and catalog
entry, and run with `Model="model-002"`.
