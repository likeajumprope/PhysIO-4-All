function physio4all_download_example_data(exampleIDs, subjectIDs, dataRoot, doOverwrite)
%PHYSIO4ALL_DOWNLOAD_EXAMPLE_DATA Download example datasets for PhysIO-4-All.
%
% Usage:
%   physio4all_download_example_data
%   physio4all_download_example_data("info")
%   physio4all_download_example_data("brainhack23_ds004808")
%   physio4all_download_example_data("brainhack23_ds004808", 44)
%   physio4all_download_example_data("brainhack23_ds004808", [44 46])
%   physio4all_download_example_data("openneuro_ds004645", 1)
%
% Inputs:
%   exampleIDs  Dataset ID(s) to download, or "info"
%   subjectIDs  Subject ID(s) to download for dataset-specific downloaders
%               (default depends on dataset)
%   dataRoot    Root folder for downloaded data (default: <repo_root>/data)
%   doOverwrite Whether to overwrite existing dataset folders (default: false)

registry = availableDatasets();

if nargin >= 1 && ~isempty(exampleIDs)
    if any(strcmpi(string(exampleIDs), ["info", "-info", "--info"]))
        printAvailableDatasets(registry);
        return
    end
end

if nargin < 1 || isempty(exampleIDs)
    exampleIDs = registry.ids(1);
end

if nargin < 2
    subjectIDs = [];
end

if nargin < 3 || isempty(dataRoot)
    repoRoot = fileparts(mfilename('fullpath'));
    dataRoot = fullfile(repoRoot, 'data');
end

if nargin < 4 || isempty(doOverwrite)
    doOverwrite = false;
end

if ischar(exampleIDs)
    exampleIDs = string(exampleIDs);
end

if ~isfolder(dataRoot)
    mkdir(dataRoot);
end

fprintf('\n=== PhysIO-4-All Example Data Downloader ===\n');
fprintf('Target directory: %s\n', dataRoot);
fprintf('Overwrite existing: %d\n\n', doOverwrite);

for iExample = 1:numel(exampleIDs)
    exampleID = lower(string(exampleIDs(iExample)));
    iRegistry = find(strcmpi(registry.ids, exampleID), 1);

    if isempty(iRegistry)
        error('Unknown example dataset: %s\nUse "info" to list available datasets.', exampleID);
    end

    fprintf('Downloading: %s\n', exampleID);

    switch exampleID
        case "brainhack23_ds004808"
            destRoot = fullfile(dataRoot, 'brainhack_physio', 'ds004808');
            physio4all_download_example_data_brainhack23_ds004808( ...
                destRoot, subjectIDs, doOverwrite);
        case "openneuro_ds004645"
            destRoot = fullfile(dataRoot, 'openneuro', 'ds004645');
            physio4all_download_example_data_openneuro_ds004645( ...
                destRoot, subjectIDs, doOverwrite);
    end

    fprintf('\n');
end

fprintf('=== Done ===\n\n');

end

function registry = availableDatasets()
registry.ids = ["brainhack23_ds004808", "openneuro_ds004645"];

registry.description = [ ...
    "BrainHack 2023 example based on OpenNeuro ds004808 plus OSF physio logs", ...
    "OpenNeuro ds004645 7T resting-state fMRI with BIDS physiology"];
end

function printAvailableDatasets(registry)
fprintf('\n=== Available PhysIO-4-All Example Datasets ===\n\n');

for iDataset = 1:numel(registry.ids)
    fprintf('  %-28s  %s\n', registry.ids(iDataset), registry.description(iDataset));
end

fprintf('\nUse:\n');
fprintf('  physio4all_download_example_data("<dataset_id>")\n\n');
fprintf('  physio4all_download_example_data("<dataset_id>", [44 46])\n\n');
end
