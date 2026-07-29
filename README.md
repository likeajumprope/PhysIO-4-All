[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=likeajumprope/physio-4-all)

# PhysIO-4-All

Repository demonstrating the application of the PhysIO toolbox to a wide range of public fMRI datasets, with an emphasis on OpenNeuro.

## Dependencies

This repository depends on upstream copies of:

- [SPM](https://github.com/spm/spm)
- [PhysIO](https://github.com/ComputationalPsychiatry/PhysIO)

Both dependencies are included as pinned Git submodules under `external/`:

```text
external/
  spm/
  PhysIO/
```

Note: `physio4all_setup.m` adds the pinned SPM and PhysIO copies under `external/` to the MATLAB path and puts PhysIO as a link/copy to `external/spm/toolbox/PhysIO` to work with the SPM Batch Editor.

## Installation

### Simple Installation

Clone the repository and run the setup script:

```bash
git clone https://github.com/likeajumprope/PhysIO-4-All.git
cd PhysIO-4-All
```

Then start MATLAB in the repository root and run:

```matlab
physio4all_setup
```

This does

1. Download/Initialize the SPM and PhysIO dependencies (Git submodules) to `external/`.
2. Link `PhysIO` to `external/spm/toolbox/PhysIO` for usage of PhysIO in the SPM Batch Editor.
3. Adds the right folders to the Matlab path.

## Example Data

To download the first example dataset used in `mrikasper/brainhack-physio`, run:

```matlab
physio4all_download_example_data("brainhack_physio_ds004808")
```

This defaults to `sub-46` and creates a reproducible subset under `data/brainhack_physio/ds004808`.

To request specific subjects, pass a numeric subject ID or vector as the second input:

```matlab
physio4all_download_example_data("brainhack_physio_ds004808", 44)
physio4all_download_example_data("brainhack_physio_ds004808", [44 46])
```

If a requested subject has no upstream OSF physio logs, the downloader warns and still downloads the imaging files from OpenNeuro.

## Run an Example

The preferred identifier for the BrainHack example is
`brainhack23_ds004808`. The earlier `brainhack_physio_ds004808` identifier
remains available as an alias.

```matlab
physio4all_setup
results = physio4all_run("brainhack23_ds004808", ...
    Subject="sub-46", Run=1, Model="model-001");
```

Pipeline output is also appended incrementally to a predictable diary:

```text
derivatives/<example>/<subject>/<run>/logs/<model>/
    <subject>_<run>_<model>_pipeline.log
```

Follow a running pipeline from PowerShell with:

```powershell
Get-Content .\derivatives\<example>\<subject>\<run>\logs\<model>\*.log -Wait
```

Set `EnableDiary=false` to disable logging, or pass `LogFile="path/to/log"`
to choose a different location.

The pipeline keeps downloaded data unchanged:

```text
data/          downloaded inputs
work/          disposable preprocessing files
derivatives/   PhysIO, GLM, statistical maps, and assessment reports
```

Reusable implementation functions live in the `physio4all` namespace under
`src/+physio4all`. The setup function adds `src`, which is the namespace
parent, and does not add the `+physio4all` folder itself.

## Repository Structure

The `examples/` folder contains **code and documentation describing each
example**, not the downloaded example data. An example definition specifies
how to find the dataset files, which acquisition metadata and PhysIO settings
to use, and which pipeline options are appropriate for that dataset.

```text
PhysIO-4-All/
├── examples/                       Dataset-specific configurations and documentation
│   └── brainhack23_ds004808/
│       ├── physio4all_example_brainhack23_ds004808.m
│       └── README.md
├── models/                         Reusable analysis configurations
│   ├── physio4all_model_001.m
│   └── README.md                   Model catalog and pipeline summaries
├── src/
│   └── +physio4all/                Reusable pipeline namespace
├── tests/                          MATLAB unit tests
├── data/                           Downloaded input datasets (Git-ignored)
├── work/                           Disposable processing copies/intermediates (Git-ignored)
├── derivatives/                    Durable PhysIO, GLM, map, and report outputs (Git-ignored)
├── physio4all_run.m                Public pipeline entry point
├── physio4all_setup.m              Path and dependency setup
└── physio4all_download_example_data.m
```

This separation keeps dataset-specific decisions small and reviewable while
sharing the preprocessing, PhysIO computation, GLM, and assessment
implementation across all examples. Downloaded inputs remain unchanged under
`data/`; SPM can modify copies under `work/`; and outputs intended for review
or reuse are written under `derivatives/`.

Each dataset example selects a default configuration from the top-level
`models/` folder, such as `model-001`. The model catalog summarizes each
pipeline, while its MATLAB configuration records preprocessing,
PhysIO-regressor, GLM, and assessment parameters. GLM outputs, statistical
maps, tSNR maps, and their checkpoint files are stored below folders named
with that model ID.
Changing analysis parameters therefore means adding a new configuration
(for example, `model-002`) rather than encoding every parameter in filenames
or overwriting results from another model.


### Manual Installation

If you prefer to initialize dependencies yourself, clone the repository together with its submodules:

```bash
git clone --recurse-submodules https://github.com/likeajumprope/PhysIO-4-All.git
cd PhysIO-4-All
```

If you already cloned the repository without submodules, fetch them with:

```bash
git submodule update --init --recursive
```

Then start MATLAB in the repository root and run:

```matlab
physio4all_setup
```

The setup script adds the required SPM and PhysIO folders to the MATLAB path and validates that both submodules are present and in the right location.

## Notes

- GitHub ZIP downloads do not include submodule contents.
- Please use `git clone --recurse-submodules` for a complete installation.
- Dependency versions are pinned by submodule commit for reproducibility.
