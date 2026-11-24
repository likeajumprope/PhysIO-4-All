function outputs = compute_physio(runInfo, preprocessOutputs, ...
        example, outputFolder, options)
%COMPUTE_PHYSIO Compute physiological nuisance regressors with PhysIO.

arguments
    runInfo (1,1) struct
    preprocessOutputs (1,1) struct
    example (1,1) struct
    outputFolder {mustBeTextScalar}
    options.Overwrite (1,1) logical = false
end

outputFolder = string(outputFolder);
if options.Overwrite && isfolder(outputFolder)
    rmdir(outputFolder, "s");
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

physioFile = fullfile(outputFolder, "physio.mat");
regressorsFile = fullfile(outputFolder, "multiple_regressors.txt");

if ~isfile(physioFile) || ~isfile(regressorsFile)
    if isfield(example.physio, "method") && ...
            example.physio.method == "acompcor"
        preprocessOutputs.noiseRoiFiles = physio4all.prepare_noise_rois( ...
            runInfo, preprocessOutputs, example.physio, ...
            fullfile(outputFolder, "noise_rois"));
    end
    matlabbatch = physio4all.build_physio_batch( ...
        runInfo, preprocessOutputs, example, outputFolder);
    spm_jobman("run", matlabbatch);
    if isfield(preprocessOutputs, "noiseRoiFiles")
        % PhysIO writes PCA loading maps beside its BOLD input. Move these
        % diagnostics into the model output; mask basenames isolate models.
        moveNoiseLoadingMaps(preprocessOutputs, outputFolder);
    end
end
regressors = readmatrix(regressorsFile);
if size(regressors, 1) ~= runInfo.nVolumes || ...
        any(~isfinite(regressors), "all")
    error("physio4all:InvalidRegressors", ...
        "PhysIO regressors must have one finite row per BOLD volume. " + ...
        "Inspect the inputs and recompute with Overwrite=true.");
end

outputs.outputFolder = outputFolder;
outputs.physioFile = string(physioFile);
outputs.regressorsFile = string(regressorsFile);

end

function moveNoiseLoadingMaps(preprocessing, outputFolder)
sourceFolder = fileparts(preprocessing.realignedBoldFile);
destinationFolder = fullfile(outputFolder, "noise_rois");
for roiFile = reshape(string(preprocessing.noiseRoiFiles), 1, [])
    [~, roiName] = fileparts(roiFile);
    maps = dir(fullfile(sourceFolder, "pc*_scores_noiseROI_" + roiName + ".nii"));
    for mapIndex = 1:numel(maps)
        movefile(fullfile(maps(mapIndex).folder, maps(mapIndex).name), ...
            fullfile(destinationFolder, maps(mapIndex).name), 'f');
    end
end
end
