# BrainHack 2023 / OpenNeuro ds004808

This example applies lightweight SPM preprocessing and PhysIO modeling to
brainstem fMRI data from OpenNeuro dataset `ds004808`, using the Siemens
physiological recordings distributed with the BrainHack PhysIO workshop.

Run the default subject and first run with:

```matlab
physio4all_setup
physio4all_run("brainhack23", Subject="sub-46", Run=1)
```

## Tested subject/run combinations

The following combinations have completed the full `model-001` pipeline,
including preprocessing, PhysIO regressor computation, GLM estimation,
statistical-map export, and tSNR assessment:

| Subject | Run | Status |
|---|---:|---|
| `sub-46` | 1 | Tested successfully |
| `sub-46` | 2 | Tested successfully |
| `sub-44` | 1 | Tested successfully |

For example:

```matlab
physio4all_download_example_data("brainhack23", 44)
physio4all_run("brainhack23", ...
    Subject="sub-44", Run=1, Model="model-001")
```

The dataset configuration permits runs 1 through 4, and the upstream OSF
project currently provides matching `Info`, `PULS`, and `RESP` recordings for
all four runs of `sub-44` and `sub-46`. Combinations not listed in the table
are available candidates but have not yet been validated end to end in this
repository.

Raw downloaded data remain under `data/`. Disposable preprocessing files are
written under `work/`, and durable PhysIO, GLM, and assessment outputs are
written under `derivatives/`.
