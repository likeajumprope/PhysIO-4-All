function results = physio4all_run(exampleID, options)
%PHYSIO4ALL_RUN Run a PhysIO-4-All example pipeline.
%
%   results = physio4all_run("brainhack23_ds004808")
%   results = physio4all_run("brainhack23_ds004808", ...
%       Subject="sub-46", Run=1)
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
    options.Overwrite (1,1) logical = false
    options.ComputeTsnrGains (1,1) logical = true
    options.Verbose (1,1) logical = true
end

optionCells = namedargs2cell(options);
results = physio4all.run(string(exampleID), optionCells{:});

end
