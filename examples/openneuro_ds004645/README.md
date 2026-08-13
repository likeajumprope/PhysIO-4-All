# OpenNeuro ds004645

This example uses the two 7T resting-state runs from OpenNeuro dataset
[`ds004645` version 1.0.0](https://openneuro.org/datasets/ds004645/versions/1.0.0).
The dataset includes BIDS-formatted pulse-oximetry and respiratory-belt
recordings. The downloader defaults to `sub-01`; subjects `sub-01` through
`sub-15` can be requested.

```matlab
physio4all_setup
physio4all_download_example_data("openneuro_ds004645")
results = physio4all_run("openneuro_ds004645", Subject="sub-01", Run=1)
```

The downloaded NIfTI images are decompressed for SPM. BIDS physiology remains
in its original `.tsv.gz` representation with the adjacent JSON sidecar. The
recordings contain cardiac and respiratory columns without a scanner-trigger
column, which current PhysIO versions support directly.
