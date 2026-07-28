function example = get_example(exampleID)
%GET_EXAMPLE Return a validated PhysIO-4-All example configuration.

arguments
    exampleID {mustBeTextScalar}
end

exampleID = lower(string(exampleID));
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

switch exampleID
    case {"brainhack23_ds004808", "brainhack_physio_ds004808", "ds004808"}
        configFolder = fullfile(repoRoot, "examples", "brainhack23_ds004808");
        originalPath = path;
        restorePath = onCleanup(@() path(originalPath));
        addpath(configFolder);
        example = physio4all_example_brainhack23_ds004808();
    otherwise
        error("physio4all:UnknownExample", ...
            "Unknown example '%s'.", exampleID);
end

example.repoRoot = string(repoRoot);
example = physio4all.validate_example(example);

end
