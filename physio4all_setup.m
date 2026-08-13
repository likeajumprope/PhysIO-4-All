function physio4all_setup()
%PHYSIO4ALL_SETUP Add pinned SPM and PhysIO dependencies to the MATLAB path.

%% Define dependency locations within repository
repo_root = fileparts(mfilename('fullpath'));
src_dir = fullfile(repo_root, 'src');
spm_dir = fullfile(repo_root, 'external', 'spm');
physio_dir = fullfile(repo_root, 'external', 'PhysIO');

%% Ensure submodules are available before adding paths
ensure_submodules_present(repo_root, {spm_dir, physio_dir});

assert_dependency_present(spm_dir, 'SPM');
assert_dependency_present(physio_dir, 'PhysIO');
assert_dependency_present(src_dir, 'PhysIO-4-All source');

%% Add public entry points and namespace parent to MATLAB path
% Add src, not src/+physio4all. MATLAB resolves +physio4all as a namespace
% when its parent folder is on the path.
addpath(repo_root);
addpath(src_dir);

%% Add core SPM and PhysIO folders to MATLAB path
addpath(spm_dir);
addpath(genpath(physio_dir));

%% Make PhysIO visible inside SPM/toolbox for Batch Editor integration
[~, spm_physio_dir] = ensure_physio_spm_toolbox_integration(spm_dir, physio_dir);

%% Keep the vendored PhysIO checkout authoritative on the MATLAB path
% The SPM toolbox entry can be a junction to physio_dir. Adding the junction
% and then removing physio_dir is unreliable on Windows because both paths
% canonicalize to the same directory. Keep the junction for SPM discovery,
% but execute PhysIO directly from the pinned submodule.
if isfolder(spm_physio_dir)
    remove_other_physio_paths(physio_dir);
    addpath(genpath(physio_dir), '-begin');
end

assert_pinned_physio_on_path(physio_dir);

%% Report resulting setup status
fprintf('Added PhysIO-4-All entry points to path: %s\n', repo_root);
fprintf('Added PhysIO-4-All namespace parent to path: %s\n', src_dir);
fprintf('Added SPM to path: %s\n', spm_dir);
fprintf('Added PhysIO to path: %s\n', physio_dir);

if exist('spm', 'file') ~= 2
    warning('SPM does not appear to be available on the MATLAB path.');
end

if exist('tapas_physio_new', 'file') ~= 2
    warning('PhysIO does not appear to be available on the MATLAB path.');
end

if isempty(which('physio4all.run'))
    warning('The physio4all namespace does not appear to be available.');
end

end

function assert_pinned_physio_on_path(physio_dir)
% Verify that another installed PhysIO does not shadow the submodule.

resolved_file = which('tapas_physio_new');
expected_root = canonical_path(physio_dir);
resolved_root = canonical_path(fileparts(resolved_file));
if ~strcmpi(resolved_root, expected_root)
    error(['PhysIO path resolution escaped the pinned submodule.' newline ...
        'Expected: ' expected_root newline ...
        'Resolved: ' resolved_root]);
end

fprintf('Pinned PhysIO path check: OK (%s)\n', resolved_file);
end

function remove_other_physio_paths(physio_dir)
% Remove other installed PhysIO trees from this MATLAB session only.

expected_root = canonical_path(physio_dir);
init_files = which('tapas_physio_init', '-all');
if ischar(init_files)
    init_files = {init_files};
end

for iFile = 1:numel(init_files)
    active_root = fileparts(init_files{iFile});
    if ~strcmpi(canonical_path(active_root), expected_root)
        rmpath(genpath(active_root));
        fprintf('Removed competing PhysIO path: %s\n', active_root);
    end
end
end

function path_out = canonical_path(path_in)
% Resolve filesystem links for reliable path comparisons.

try
    path_out = char(java.io.File(path_in).getCanonicalPath());
catch
    path_out = char(path_in);
end
end

function isSuccessful = ensure_submodules_present(repo_root, dependency_dirs)
% Try to initialize missing git submodules when repository metadata exists.

isSuccessful = true;

missing_dependencies = dependency_dirs(~cellfun( @(X) (isfolder(X) && numel(dir(X))>2), dependency_dirs));
if isempty(missing_dependencies)
    fprintf('Git submodule check: OK.\n');
    return;
end

git_dir = fullfile(repo_root, '.git');
if ~isfolder(git_dir) && ~isfile(git_dir)
    fprintf('Git submodule check: skipped, repository metadata not found.\n');
    return;
end

fprintf(['Missing Git submodules detected. Attempting to initialize them via ' ...
    'git submodule update --init --recursive...\n']);
[status, cmdout] = system('git submodule update --init --recursive');
if status ~= 0
    error(['Unable to initialize Git submodules automatically.' newline ...
        strtrim(cmdout) newline ...
        'Please run: git submodule update --init --recursive']);
end
end

function assert_dependency_present(folder_path, dependency_name)
% Fail early with a helpful message when a required dependency is missing.

if ~isfolder(folder_path)
    error(['Missing ' dependency_name ' submodule at ' folder_path newline ...
        'Clone with --recurse-submodules or run:' newline ...
        'git submodule update --init --recursive']);
end

fprintf('%s dependency check: OK (%s)\n', dependency_name, folder_path);
end

function [isSuccessful, spm_physio_dir] = ensure_physio_spm_toolbox_integration(spm_dir, physio_dir)
% Ensure PhysIO is available in SPM/toolbox/PhysIO across operating systems.
%
% First, try PhysIO''s own OS-specific helper for creating the toolbox link.
% If that does not yield an accessible toolbox folder, fall back to calling
% tapas_physio_init() from within the vendored PhysIO checkout, which can
% perform the manual copy/setup logic used by PhysIO itself.

isSuccessful = true;

toolbox_dir = fullfile(spm_dir, 'toolbox');
if ~isfolder(toolbox_dir)
    fprintf('SPM toolbox integration check: skipped, toolbox folder not found.\n');
    isSuccessful = false;
    return;
end

spm_physio_dir = fullfile(toolbox_dir, 'PhysIO');
if exist(spm_physio_dir, 'dir')
    fprintf('SPM toolbox integration check: OK (%s)\n', spm_physio_dir);
    return;
end

% Use PhysIO's built-in link creation helper first.
fprintf('SPM toolbox integration check: creating PhysIO link in SPM toolbox...\n');
tapas_physio_create_spm_toolbox_link(physio_dir);
if exist(spm_physio_dir, 'dir')
    fprintf('SPM toolbox integration check: OK (%s)\n', spm_physio_dir);
    return;
end

% Fall back to PhysIO's full initialization routine if linking was insufficient.
fprintf(['SPM toolbox integration check: link helper did not create %s. ' ...
    'Falling back to tapas_physio_init()...\n'], spm_physio_dir);
original_dir = pwd;
restore_dir = onCleanup(@() cd(original_dir));
cd(physio_dir);
tapas_physio_init();

isSuccessful = exist(spm_physio_dir, 'dir') ~= 0;
if isSuccessful
    fprintf('SPM toolbox integration check: OK (%s)\n', spm_physio_dir);
else
    fprintf('SPM toolbox integration check: failed to create %s.\n', spm_physio_dir);
end
end
