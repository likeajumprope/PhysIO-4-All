function physio4all_setup()
%PHYSIO4ALL_SETUP Add pinned SPM and PhysIO dependencies to the MATLAB path.

%% Define dependency locations within repository
repo_root = fileparts(mfilename('fullpath'));
spm_dir = fullfile(repo_root, 'external', 'spm');
physio_dir = fullfile(repo_root, 'external', 'PhysIO');

%% Ensure submodules are available before adding paths
ensure_submodules_present(repo_root, {spm_dir, physio_dir});

assert_dependency_present(spm_dir, 'SPM');
assert_dependency_present(physio_dir, 'PhysIO');

%% Add core SPM and PhysIO folders to Matlab path
addpath(spm_dir);
addpath(genpath(physio_dir));

%% Make PhysIO visible inside SPM/toolbox for Batch Editor integration
current_dir = pwd;
[~, spm_physio_dir] = ensure_physio_spm_toolbox_integration(spm_dir, physio_dir);

%% Add SPM toolboxes after potential PhysIO integration step and remove original PhysIO folder from path
if isfolder(spm_physio_dir)
    addpath(genpath(spm_physio_dir));
    rmpath(genpath(physio_dir));
end

%% Report resulting setup status
fprintf('Added SPM to path: %s\n', spm_dir);
fprintf('Added PhysIO to path: %s\n', physio_dir);

if exist('spm', 'file') ~= 2
    warning('SPM does not appear to be available on the MATLAB path.');
end

if exist('tapas_physio_new', 'file') ~= 2
    warning('PhysIO does not appear to be available on the MATLAB path.');
end

end

function isSuccessful = ensure_submodules_present(repo_root, dependency_dirs)
% Try to initialize missing git submodules when repository metadata exists.

isSuccessful = true;

missing_dependencies = dependency_dirs(~cellfun(@isfolder, dependency_dirs));
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
