function results = physio4all_run(exampleID, options)
%PHYSIO4ALL_RUN Run a PhysIO-4-All example pipeline.
%
%   results = physio4all_run("brainhack23")
%   results = physio4all_run("fastfmri", ...
%       Subject="sub-46", Run=1)
%   results = physio4all_run("fastfmri", Model="model-002", QuickCheck=true)
%   processes the first 100 volumes in a separate quick-check output folder.
%   QuickCheckVolumes changes this limit. OverwriteFrom="none" reuses
%   compatible outputs. Select a stage to force it and subsequent stages
%   within the requested pipeline; "all" is an alias for "preprocess".
%   NormalizeMaps=true exports 3-D assessment maps on the SPM MNI grid.
%
% See also physio4all.run, physio4all_download_example_data

arguments
    exampleID {mustBeTextScalar}
    options.Subject {mustBeTextScalar} = ""
    options.Run (1,1) {mustBeNumeric, mustBeInteger, mustBePositive, mustBeReal} = 1
    options.Model {mustBeTextScalar} = ""
    options.Stages {mustBeText} = ...
        ["preprocess", "compute_physio", "fit_glm", "assess_physio"]
    options.DataRoot {mustBeTextScalar} = ""
    options.WorkRoot {mustBeTextScalar} = ""
    options.DerivativesRoot {mustBeTextScalar} = ""
    options.OverwriteFrom {mustBeTextScalar} = "none"
    options.QuickCheck (1,1) logical = false
    options.QuickCheckVolumes (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 100
    options.EnableDiary (1,1) logical = true
    options.LogFile {mustBeTextScalar} = ""
    options.ComputeTsnrGains (1,1) logical = true
    options.NormalizeMaps (1,1) logical = false
    options.Verbose (1,1) logical = true
end

optionCells = namedargs2cell(options);
results = physio4all.run(string(exampleID), optionCells{:});

end
