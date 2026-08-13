function example = physio4all_example_openneuro_ds004645_fastfmri()
%PHYSIO4ALL_EXAMPLE_OPENNEURO_DS004645_FASTFMRI Configure fast fMRI.

example.id = "openneuro_ds004645_fastfmri";
example.name = "OpenNeuro ds004645 resting-state fMRI example";
example.description = [ ...
    "OpenNeuro ds004645 7T resting-state fMRI with pulse oximetry " ...
    "and respiratory-belt recordings in BIDS format"];
example.source = "OpenNeuro";
example.accession = "ds004645";
example.snapshot = "1.0.0";
example.shortName = "Fast fMRI";
example.authors = "Lewis et al.";
example.purpose = "7T fast resting-state fMRI with BIDS physiology";
example.aliases = "fastfmri";
example.dataRelativePath = fullfile("openneuro", "ds004645");
example.defaultSubject = "sub-01";
example.defaultModel = "model-001";
example.availableRuns = 1:2;

example.files.bold = "%s_task-rest_run-%02d_bold.nii";
example.files.boldJson = "%s_task-rest_run-%02d_bold.json";
example.files.physioFolder = "func";
example.files.cardiac = ".*task-rest_run-%02d_physio[.]tsv[.]gz";
example.files.respiration = ".*task-rest_run-%02d_physio[.]tsv[.]gz";
example.files.scanTiming = ".*task-rest_run-%02d_physio[.]json";

example.preprocessing.realignQuality = 0.9;
example.preprocessing.realignSeparation = 4;
example.preprocessing.realignFwhm = 5;
example.preprocessing.registerToMean = true;
example.preprocessing.interpolation = 4;

example.physio.vendor = "BIDS";
example.physio.alignScan = "first";
example.physio.multibandFactor = 3;
example.physio.cardiacModality = "PPU";
end
