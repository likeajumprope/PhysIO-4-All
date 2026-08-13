function physio4all_download_openneuro_subset( ...
        datasetID, snapshot, destRoot, relativePaths, decompressNifti)
%PHYSIO4ALL_DOWNLOAD_OPENNEURO_SUBSET Download a version-guarded file subset.
%
% OpenNeuro exposes dataset objects at the dataset's public S3 root. This
% helper verifies that dataset_description.json declares the requested
% snapshot before downloading an explicit manifest. NIfTI files can be
% decompressed because SPM expects uncompressed .nii inputs.

if nargin < 5 || isempty(decompressNifti)
    decompressNifti = true;
end

datasetID = char(string(datasetID));
snapshot = char(string(snapshot));
destRoot = char(string(destRoot));
relativePaths = cellstr(string(relativePaths(:)));

if isempty(regexp(datasetID, '^ds\d{6}$', 'once'))
    error('datasetID must use the OpenNeuro form dsNNNNNN.');
end

rootBase = sprintf( ...
    'https://s3.amazonaws.com/openneuro.org/%s/', datasetID);
assertRequestedSnapshot(rootBase, datasetID, snapshot);

for iFile = 1:numel(relativePaths)
    relPath = relativePaths{iFile};
    assertSafeRelativePath(relPath);
    sourceUrl = [rootBase strrep(relPath, '\', '/')];
    outFile = fullfile(destRoot, relPath);
    isCompressedNifti = decompressNifti && endsWith(relPath, '.nii.gz');

    if isCompressedNifti
        finalFile = extractBefore(outFile, strlength(string(outFile)) - 2);
    else
        finalFile = string(outFile);
    end

    if isfile(finalFile)
        fprintf('  exists: %s\n', char(relativePathForDisplay( ...
            relPath, isCompressedNifti)));
        continue
    end

    outDir = fileparts(outFile);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end

    fprintf('  downloading: %s\n', relPath);
    websave(outFile, sourceUrl, weboptions('Timeout', 120));

    if isCompressedNifti
        fprintf('  decompressing: %s\n', relPath);
        gunzip(outFile, outDir);
        delete(outFile);
    end
end

end

function assertRequestedSnapshot(rootBase, datasetID, snapshot)
description = webread([rootBase 'dataset_description.json'], ...
    weboptions('Timeout', 60));
expectedDoi = sprintf('openneuro.%s.v%s', datasetID, snapshot);
if ~isfield(description, 'DatasetDOI') || ...
        ~contains(string(description.DatasetDOI), expectedDoi)
    error(['The public OpenNeuro %s objects do not declare snapshot %s. ' ...
        'Refusing to download an unverified dataset version.'], ...
        datasetID, snapshot);
end
end

function assertSafeRelativePath(relPath)
if isempty(relPath) || startsWith(relPath, {'/', '\'}) || ...
        ~isempty(regexp(relPath, '(^|[\\/])\.\.([\\/]|$)', 'once')) || ...
        ~isempty(regexp(relPath, '^[A-Za-z]:', 'once'))
    error('OpenNeuro manifest paths must be safe relative paths: %s', relPath);
end
end

function displayPath = relativePathForDisplay(relPath, isCompressedNifti)
displayPath = string(relPath);
if isCompressedNifti
    displayPath = extractBefore(displayPath, strlength(displayPath) - 2);
end
end
