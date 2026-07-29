function physio4all_download_example_data_brainhack23_ds004808( ...
        destRoot, subjectIDs, doOverwrite)
%PHYSIO4ALL_DOWNLOAD_EXAMPLE_DATA_BRAINHACK_PHYSIO_DS004808
% Download the first PhysIO-4-All example dataset.
%
% This downloads a small, reproducible subset of OpenNeuro ds004808 for
% selected subjects, together with OSF physio log files when available.
%
% Output layout under destRoot preserves a BIDS-like structure:
%   destRoot/
%     dataset_description.json
%     participants.tsv
%     sub-XX/
%       anat/
%       func/
%       physio/   (if OSF files are available)
%
% Notes:
%   - Default subject is sub-46.
%   - If no OSF physio files are found for a requested subject, a warning
%     is issued and only the OpenNeuro imaging files are downloaded.

if nargin < 1 || isempty(destRoot)
    repoRoot = fileparts(mfilename('fullpath'));
    destRoot = fullfile(repoRoot, 'data', 'brainhack_physio', 'ds004808');
end

if nargin < 2 || isempty(subjectIDs)
    subjectIDs = 46;
end

if nargin < 3 || isempty(doOverwrite)
    doOverwrite = false;
end

if doOverwrite && isfolder(destRoot)
    rmdir(destRoot, 's');
end

if ~isfolder(destRoot)
    mkdir(destRoot);
end

subjectIDs = normalizeSubjectIDs(subjectIDs);
subjectLabels = compose("sub-%02d", subjectIDs);

openNeuroFiles = getOpenNeuroManifest(subjectIDs);
osfFiles = getOsfManifest(subjectIDs);

fprintf('  OpenNeuro subset: ds004808 snapshot 1.0.0\n');
fprintf('  OSF physio logs: project td5kp\n');
fprintf('  Subjects: %s\n\n', strjoin(cellstr(subjectLabels), ', '));

downloadManifest(destRoot, openNeuroFiles);
downloadManifest(destRoot, osfFiles);

fprintf('\n  Saved BrainHack example data under:\n    %s\n', destRoot);

end

function subjectIDs = normalizeSubjectIDs(subjectIDs)
if ischar(subjectIDs) || isstring(subjectIDs)
    subjectIDs = str2double(string(subjectIDs));
end

subjectIDs = unique(subjectIDs(:))';

if any(~isfinite(subjectIDs)) || any(mod(subjectIDs, 1) ~= 0) || any(subjectIDs < 1)
    error('subjectIDs must be positive integer subject numbers, e.g. 46 or [44 46].');
end
end

function manifest = getOpenNeuroManifest(subjectIDs)
rootBase = 'https://s3.amazonaws.com/openneuro.org/ds004808/';
manifest = {
    '.bidsignore', [rootBase '.bidsignore']
    'CHANGES', [rootBase 'CHANGES']
    'README', [rootBase 'README']
    'dataset_description.json', [rootBase 'dataset_description.json']
    'participants.tsv', [rootBase 'participants.tsv']
    };

for iSubject = 1:numel(subjectIDs)
    subLabel = sprintf('sub-%02d', subjectIDs(iSubject));
    manifest = [manifest; getOpenNeuroSubjectManifest(rootBase, subLabel)]; %#ok<AGROW>
end
end

function manifest = getOpenNeuroSubjectManifest(rootBase, subLabel)
manifest = {
    sprintf('%s/anat/%s_TSE-LCarea.json', subLabel, subLabel), [rootBase sprintf('%s/anat/%s_TSE-LCarea.json', subLabel, subLabel)]
    sprintf('%s/anat/%s_TSE-LCarea.nii', subLabel, subLabel), [rootBase sprintf('%s/anat/%s_TSE-LCarea.nii', subLabel, subLabel)]
    sprintf('%s/anat/%s_TSE-VTAarea.json', subLabel, subLabel), [rootBase sprintf('%s/anat/%s_TSE-VTAarea.json', subLabel, subLabel)]
    sprintf('%s/anat/%s_TSE-VTAarea.nii', subLabel, subLabel), [rootBase sprintf('%s/anat/%s_TSE-VTAarea.nii', subLabel, subLabel)]
    sprintf('%s/anat/%s_run-01_T1w.json', subLabel, subLabel), [rootBase sprintf('%s/anat/%s_run-01_T1w.json', subLabel, subLabel)]
    sprintf('%s/anat/%s_run-01_T1w.nii', subLabel, subLabel), [rootBase sprintf('%s/anat/%s_run-01_T1w.nii', subLabel, subLabel)]
    };

for iRun = 1:4
    manifest = [manifest; {
        sprintf('%s/func/%s_task-NAconf_ep2d-AP.json', subLabel, subLabel), [rootBase sprintf('%s/func/%s_task-NAconf_ep2d-AP.json', subLabel, subLabel)]
        sprintf('%s/func/%s_task-NAconf_ep2d-AP.nii', subLabel, subLabel), [rootBase sprintf('%s/func/%s_task-NAconf_ep2d-AP.nii', subLabel, subLabel)]
        sprintf('%s/func/%s_task-NAconf_ep2d-PA.json', subLabel, subLabel), [rootBase sprintf('%s/func/%s_task-NAconf_ep2d-PA.json', subLabel, subLabel)]
        sprintf('%s/func/%s_task-NAconf_ep2d-PA.nii', subLabel, subLabel), [rootBase sprintf('%s/func/%s_task-NAconf_ep2d-PA.nii', subLabel, subLabel)]
        sprintf('%s/func/%s_task-NAconf_run-%02d_bold.json', subLabel, subLabel, iRun), [rootBase sprintf('%s/func/%s_task-NAconf_run-%02d_bold.json', subLabel, subLabel, iRun)]
        sprintf('%s/func/%s_task-NAconf_run-%02d_bold.nii', subLabel, subLabel, iRun), [rootBase sprintf('%s/func/%s_task-NAconf_run-%02d_bold.nii', subLabel, subLabel, iRun)]
        }]; %#ok<AGROW>
end
end

function manifest = getOsfManifest(subjectIDs)
manifest = {
    'acq_param.txt', 'https://osf.io/download/epajd/'
    };

for iSubject = 1:numel(subjectIDs)
    subLabel = sprintf('sub-%02d', subjectIDs(iSubject));
    subjectManifest = getOsfSubjectManifest(subLabel);
    if isempty(subjectManifest)
        warning('No OSF physio files found for %s. Downloading imaging files only.', subLabel);
        continue
    end
    manifest = [manifest; subjectManifest]; %#ok<AGROW>
end
end

function manifest = getOsfSubjectManifest(subLabel)
manifest = {};

osfSubjectFiles = listOsfSubjectFiles(subLabel);
if isempty(osfSubjectFiles)
    return
end

for iFile = 1:numel(osfSubjectFiles)
    fileInfo = osfSubjectFiles(iFile);
    fileName = string(fileInfo.attributes.name);
    downloadUrl = string(fileInfo.links.download);

    if strlength(downloadUrl) == 0
        continue
    end

    manifest(end+1, :) = {fullfile(subLabel, 'physio', char(fileName)), char(downloadUrl)}; %#ok<AGROW>
end
end

function files = listOsfSubjectFiles(subLabel)
files = struct([]);

physioRootUrl = 'https://api.osf.io/v2/nodes/td5kp/files/osfstorage/6522f2c58440e502c37d87e6/?page[size]=200';
rootResponse = webread(physioRootUrl, weboptions('Timeout', 60));
rootData = rootResponse.data;

subjectFolderUrl = '';
for iEntry = 1:numel(rootData)
    if strcmp(char(rootData(iEntry).attributes.name), subLabel)
        subjectFolderUrl = rootData(iEntry).relationships.files.links.related.href;
        break
    end
end

if isempty(subjectFolderUrl)
    return
end

subjectResponse = webread([char(subjectFolderUrl) '?page[size]=200'], weboptions('Timeout', 60));
if isfield(subjectResponse, 'data')
    files = subjectResponse.data;
end
end

function downloadManifest(destRoot, manifest)
for iFile = 1:size(manifest, 1)
    relPath = manifest{iFile, 1};
    url = manifest{iFile, 2};
    outFile = fullfile(destRoot, relPath);

    if isfile(outFile)
        fprintf('  exists: %s\n', relPath);
        continue
    end

    outDir = fileparts(outFile);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end

    fprintf('  downloading: %s\n', relPath);
    websave(outFile, url, weboptions('Timeout', 120));
end
end
