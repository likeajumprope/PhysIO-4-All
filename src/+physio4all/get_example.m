function example = get_example(exampleID)
%GET_EXAMPLE Return a validated PhysIO-4-All example configuration.

arguments
    exampleID {mustBeTextScalar}
end

exampleID = physio4all_resolve_example_id(exampleID);
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

% Resolve the registry ID first, then load its conventionally named file.
configFolder = fullfile(repoRoot, "examples", exampleID);
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(configFolder);
example = feval("physio4all_example_" + exampleID);

example.repoRoot = string(repoRoot);
example.configFolder = string(configFolder);
example = physio4all.validate_example(example);

end
