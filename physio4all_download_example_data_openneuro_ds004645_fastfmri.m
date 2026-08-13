function physio4all_download_example_data_openneuro_ds004645_fastfmri( ...
        destRoot, subjectIDs, doOverwrite)
%PHYSIO4ALL_DOWNLOAD_EXAMPLE_DATA_OPENNEURO_DS004645_FASTFMRI Download data.
%
% Downloads the T1w image plus both resting-state BOLD and BIDS physiology
% runs for selected subjects from the pinned OpenNeuro 1.0.0 snapshot.

if nargin < 1 || isempty(destRoot)
    repoRoot = fileparts(mfilename('fullpath'));
    destRoot = fullfile(repoRoot, 'data', 'openneuro', 'ds004645');
end
if nargin < 2 || isempty(subjectIDs)
    subjectIDs = 1;
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
manifest = rootManifest();
for iSubject = 1:numel(subjectIDs)
    manifest = [manifest; subjectManifest(subjectIDs(iSubject))]; %#ok<AGROW>
end

fprintf('  OpenNeuro subset: ds004645 snapshot 1.0.0\n');
fprintf('  Subjects: %s\n\n', strjoin( ...
    cellstr(compose("sub-%02d", subjectIDs)), ', '));
physio4all_download_openneuro_subset( ...
    'ds004645', '1.0.0', destRoot, manifest, true);
fprintf('\n  Saved ds004645 example data under:\n    %s\n', destRoot);

end

function subjectIDs = normalizeSubjectIDs(subjectIDs)
if ischar(subjectIDs) || isstring(subjectIDs)
    subjectIDs = str2double(string(subjectIDs));
end
subjectIDs = unique(subjectIDs(:))';
if any(~isfinite(subjectIDs)) || any(mod(subjectIDs, 1) ~= 0) || ...
        any(subjectIDs < 1 | subjectIDs > 15)
    error('ds004645 subjectIDs must be integers from 1 through 15.');
end
end

function manifest = rootManifest()
manifest = {
    'CHANGES'
    'README'
    'dataset_description.json'
    'participants.json'
    'participants.tsv'
    'task-rest_bold.json'
    };
end

function manifest = subjectManifest(subjectID)
subject = sprintf('sub-%02d', subjectID);
manifest = cell(9, 1);
manifest{1} = sprintf('%s/anat/%s_T1w.nii.gz', subject, subject);
for runNumber = 1:2
    stem = sprintf('%s/func/%s_task-rest_run-%02d', ...
        subject, subject, runNumber);
    firstIndex = 2 + 4 * (runNumber - 1);
    manifest(firstIndex:firstIndex + 3) = { ...
        [stem '_bold.json']
        [stem '_bold.nii.gz']
        [stem '_physio.json']
        [stem '_physio.tsv.gz']
        };
end
end
