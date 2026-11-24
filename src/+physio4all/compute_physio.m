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
        maskSignature.anatomical = physio4all.input_signature(runInfo.anatomicalFile);
        maskSignature.thresholds = example.physio.noiseThresholds;
        maskSignature.crop = example.physio.noiseVoxelCrop;
        maskFolder = fullfile(preprocessOutputs.outputFolder, "noise_rois", ...
            physio4all.cache_key(maskSignature));
        preprocessOutputs.noiseRoiFiles = physio4all.prepare_noise_rois( ...
            runInfo, preprocessOutputs, example.physio, ...
            maskFolder);
    end
    matlabbatch = physio4all.build_physio_batch( ...
        runInfo, preprocessOutputs, example, outputFolder);
    isRecordingExcerpt = isfield(runInfo, "fullNVolumes") && ...
        runInfo.nVolumes < runInfo.fullNVolumes && ...
        ~(isfield(example.physio, "method") && example.physio.method == "acompcor");
    if isRecordingExcerpt
        % Synchronize against the complete acquisition, particularly for
        % vendors aligned to its end. Then select the FIRST N scan rows.
        movement = matlabbatch{1}.spm.tools.physio.model.movement.yes;
        matlabbatch{1}.spm.tools.physio.model.movement = struct('no', struct([]));
        matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.Nscans = runInfo.fullNVolumes;
    end
    spm_jobman("run", matlabbatch);
    if isRecordingExcerpt
        finishRecordingExcerpt(physioFile, regressorsFile, movement, runInfo.nVolumes);
    end
    if isfield(preprocessOutputs, "noiseRoiFiles")
        % PhysIO writes PCA loading maps beside its BOLD input. Move these
        % diagnostics into the model output after each extraction.
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
if ~isfolder(destinationFolder)
    mkdir(destinationFolder);
end
for roiFile = reshape(string(preprocessing.noiseRoiFiles), 1, [])
    [~, roiName] = fileparts(roiFile);
    maps = dir(fullfile(sourceFolder, "pc*_scores_noiseROI_" + roiName + ".nii"));
    for mapIndex = 1:numel(maps)
        movefile(fullfile(maps(mapIndex).folder, maps(mapIndex).name), ...
            fullfile(destinationFolder, maps(mapIndex).name), 'f');
    end
end
end

function finishRecordingExcerpt(physioFile, regressorsFile, movement, nVolumes)
data = load(physioFile, "physio");
physio = data.physio;
movement.include = true;
movement.file_realignment_parameters = movement.file_realignment_parameters{1};
[motionR, movement] = tapas_physio_create_movement_regressors( ...
    movement, struct('level', 0));
names = [repmat({'Movement'}, 1, movement.order), ...
    repmat({'Motion outliers'}, 1, size(motionR, 2)-movement.order)];
physio.model.R = [physio.model.R(1:nVolumes, :), motionR];
physio.model.R_column_names = [physio.model.R_column_names, names];
physio.model.movement = movement;
physio.scan_timing.sqpar.Nscans = nVolumes;
physio.quickCheck.nVolumes = nVolumes;
physio.quickCheck.recordingTiming = "synchronized to full acquisition before selecting first N rows";
R = physio.model.R;
save(physioFile, "physio");
save(regressorsFile, 'R', '-ascii', '-double', '-tabs');
end
