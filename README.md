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
