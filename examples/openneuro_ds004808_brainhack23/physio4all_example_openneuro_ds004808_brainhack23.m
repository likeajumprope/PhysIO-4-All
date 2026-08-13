function example = physio4all_example_openneuro_ds004808_brainhack23()
%PHYSIO4ALL_EXAMPLE_OPENNEURO_DS004808_BRAINHACK23 Configure BrainHack.

example.id = "openneuro_ds004808_brainhack23";
example.name = "BrainHack 2023 brainstem fMRI example";
example.description = [ ...
    "OpenNeuro ds004808 imaging with Siemens physiological recordings " ...
    "from the BrainHack PhysIO workshop"];
example.source = "OpenNeuro";
example.accession = "ds004808";
example.snapshot = "1.0.0";
example.shortName = "BrainHack 2023";
example.authors = "BrainHack 2023 PhysIO workshop";
example.purpose = "Brainstem fMRI with Siemens physiology";
example.aliases = "brainhack23";
example.dataRelativePath = fullfile("openneuro", "ds004808");
example.defaultSubject = "sub-46";
example.defaultModel = "model-001";
example.availableRuns = 1:4;

example.files.bold = ...
    "%s_task-NAconf_run-%02d_bold.nii";
example.files.boldJson = ...
    "%s_task-NAconf_run-%02d_bold.json";
example.files.cardiac = "Physio_.*_sess%d_PULS[.]log";
example.files.respiration = "Physio_.*_sess%d_RESP[.]log";
example.files.scanTiming = "Physio_.*_sess%d_Info[.]log";

example.preprocessing.realignQuality = 0.9;
example.preprocessing.realignSeparation = 4;
example.preprocessing.realignFwhm = 5;
example.preprocessing.registerToMean = true;
example.preprocessing.interpolation = 4;

example.physio.vendor = "Siemens_Tics";
example.physio.alignScan = "last";
% HACK for now because of a bug in tapas_physio_get_onsets_from_locs.
% This should be nSlicesTotal/multibandFactor.
example.physio.nSlices = 28;
example.physio.cardiacModality = "PPU";
end
