function example = get_example(exampleID)
%GET_EXAMPLE Return a validated PhysIO-4-All example configuration.

arguments
    exampleID {mustBeTextScalar}
end

exampleID = physio4all_resolve_example_id(exampleID);
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));

switch exampleID
    case "openneuro_ds004808_brainhack23"
        configFolder = fullfile(repoRoot, "examples", ...
            "openneuro_ds004808_brainhack23");
        originalPath = path;
        restorePath = onCleanup(@() path(originalPath));
        addpath(configFolder);
        example = physio4all_example_openneuro_ds004808_brainhack23();
    case "openneuro_ds004645_fastfmri"
        configFolder = fullfile(repoRoot, "examples", ...
            "openneuro_ds004645_fastfmri");
        originalPath = path;
        restorePath = onCleanup(@() path(originalPath));
        addpath(configFolder);
        example = physio4all_example_openneuro_ds004645_fastfmri();
end

example.repoRoot = string(repoRoot);
example.configFolder = string(configFolder);
example = physio4all.validate_example(example);

end
