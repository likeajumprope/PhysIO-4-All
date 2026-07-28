# BrainHack 2023 / OpenNeuro ds004808

This example applies lightweight SPM preprocessing and PhysIO modeling to
brainstem fMRI data from OpenNeuro dataset `ds004808`, using the Siemens
physiological recordings distributed with the BrainHack PhysIO workshop.

Run the default subject and first run with:

```matlab
physio4all_setup
physio4all_run("brainhack23_ds004808", Subject="sub-46", Run=1)
```

Raw downloaded data remain under `data/`. Disposable preprocessing files are
written under `work/`, and durable PhysIO, GLM, and assessment outputs are
written under `derivatives/`.
