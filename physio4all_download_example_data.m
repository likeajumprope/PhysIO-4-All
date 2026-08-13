function physio4all_download_example_data(exampleIDs, subjectIDs, dataRoot, doOverwrite)
%PHYSIO4ALL_DOWNLOAD_EXAMPLE_DATA Download example datasets for PhysIO-4-All.
%
% Usage:
%   physio4all_download_example_data
%   physio4all_download_example_data("info")
%   physio4all_download_example_data("brainhack23")
%   physio4all_download_example_data("brainhack23", [44 46])
%   physio4all_download_example_data("fastfmri", 1)
%
% Inputs:
%   exampleIDs  Dataset ID(s) to download, or "info"
%   subjectIDs  Subject ID(s) to download for dataset-specific downloaders
%               (default depends on dataset)
%   dataRoot    Root folder for downloaded data (default: <repo_root>/data)
%   doOverwrite Whether to overwrite existing dataset folders (default: false)

registry = physio4all_example_registry();

if nargin >= 1 && ~isempty(exampleIDs)
    if any(strcmpi(string(exampleIDs), ["info", "-info", "--info"]))
        printAvailableDatasets(registry);
        return
    end
end

if nargin < 1 || isempty(exampleIDs)
    exampleIDs = registry(1).id;
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
    requestedID = lower(string(exampleIDs(iExample)));
    try
        exampleID = physio4all_resolve_example_id(requestedID);
    catch exception
        if strcmp(exception.identifier, 'physio4all:UnknownExample')
            error('Unknown example dataset: %s\nUse "info" to list available datasets.', requestedID);
        end
        rethrow(exception);
    end
    iRegistry = find(strcmpi([registry.id], exampleID), 1);

    fprintf('Downloading: %s (%s)\n', ...
        registry(iRegistry).mnemonic, exampleID);

    switch exampleID
        case "openneuro_ds004808_brainhack23"
            destRoot = fullfile(dataRoot, 'openneuro', 'ds004808');
            physio4all_download_example_data_openneuro_ds004808_brainhack23( ...
                destRoot, subjectIDs, doOverwrite);
        case "openneuro_ds004645_fastfmri"
            destRoot = fullfile(dataRoot, 'openneuro', 'ds004645');
            physio4all_download_example_data_openneuro_ds004645_fastfmri( ...
                destRoot, subjectIDs, doOverwrite);
    end

    fprintf('\n');
end

fprintf('=== Done ===\n\n');

end

function printAvailableDatasets(registry)
fprintf('\n=== Available PhysIO-4-All Example Datasets ===\n\n');

for iDataset = 1:numel(registry)
    fprintf('  %-14s  %-38s  %s\n', registry(iDataset).mnemonic, ...
        registry(iDataset).id, registry(iDataset).description);
end

fprintf('\nUse:\n');
fprintf('  physio4all_download_example_data("<mnemonic_or_dataset_id>")\n\n');
fprintf('  physio4all_download_example_data("brainhack23", [44 46])\n\n');
end
