function outputs = preprocess(runInfo, example, workFolder, ...
        derivativeFolder, options)
%PREPROCESS Copy raw BOLD data and run lightweight SPM preprocessing.
%   Realignment estimates motion between volumes of this functional run.
%   Keep its unsmoothed series for tissue PCA and its mean as the anatomical
%   registration target. The pipeline calls preprocess_anatomy for aCompCor.

arguments
    runInfo (1,1) struct
    example (1,1) struct
    workFolder {mustBeTextScalar}
    derivativeFolder {mustBeTextScalar}
    options.Overwrite (1,1) logical = false
    options.SmoothingFwhm (1,3) {mustBeNumeric, mustBeNonnegative, mustBeReal} = [3 3 3]
end

workFolder = string(workFolder);
derivativeFolder = string(derivativeFolder);

if options.Overwrite && isfolder(workFolder)
    rmdir(workFolder, "s");
end
if options.Overwrite && isfolder(derivativeFolder)
    rmdir(derivativeFolder, "s");
end
if ~isfolder(workFolder)
    mkdir(workFolder);
end

[~, boldName, boldExtension] = fileparts(runInfo.boldFile);
workingBoldFile = fullfile(workFolder, boldName + boldExtension);
workingJsonFile = fullfile(workFolder, boldName + ".json");
realignedBoldFile = string(spm_file( ...
    char(workingBoldFile), 'prefix', 'r'));
smoothedBoldFile = string(spm_file( ...
    char(realignedBoldFile), 'prefix', 's'));
motionFile = fullfile(workFolder, "rp_" + boldName + ".txt");
meanBoldFile = fullfile(workFolder, "mean" + boldName + boldExtension);

derivativeOutputs = expectedDerivativeOutputs( ...
    derivativeFolder, boldName, boldExtension, options.SmoothingFwhm);
signature.bold = physio4all.input_signature(runInfo.boldFile);
signature.json = physio4all.input_signature(runInfo.boldJsonFile);
signature.nVolumes = runInfo.nVolumes;
signature.settings = example.preprocessing;
signature.smoothingFwhm = options.SmoothingFwhm;
if isComplete(derivativeOutputs, options.SmoothingFwhm, signature)
    fprintf('Reusing preprocessing: %s\n', derivativeFolder);
    outputs = derivativeOutputs;
    outputs.workFolder = workFolder;
    outputs.workingBoldFile = string(runInfo.boldFile);
    outputs.reused = true;
    return
end

if ~isfile(workingBoldFile)
    if isfield(runInfo, "fullNVolumes") && runInfo.nVolumes < runInfo.fullNVolumes
        scans = arrayfun(@(k) sprintf('%s,%d', runInfo.boldFile, k), ...
            (1:runInfo.nVolumes)', UniformOutput=false);
        spm_file_merge(char(scans), char(workingBoldFile), 0, runInfo.repetitionTime);
    else
        copyfile(runInfo.boldFile, workingBoldFile);
    end
end
if ~isfile(workingJsonFile)
    copyfile(runInfo.boldJsonFile, workingJsonFile);
end

if ~isfile(realignedBoldFile) || ~isfile(motionFile) || ~isfile(meanBoldFile)
    matlabbatch = physio4all.build_preprocess_batch( ...
        runInfo, workingBoldFile, example);
    spm_jobman("run", matlabbatch);
end

if any(options.SmoothingFwhm > 0)
    if ~isfile(smoothedBoldFile)
        runSmoothing(realignedBoldFile, runInfo.nVolumes, ...
            options.SmoothingFwhm);
    end
end

promoteFile(realignedBoldFile, derivativeOutputs.realignedBoldFile);
promoteFile(motionFile, derivativeOutputs.motionFile);
promoteFile(meanBoldFile, derivativeOutputs.meanBoldFile);
promoteFile(workingJsonFile, derivativeOutputs.boldJsonFile);
if any(options.SmoothingFwhm > 0)
    promoteFile(smoothedBoldFile, derivativeOutputs.smoothedBoldFile);
end

outputs = derivativeOutputs;
outputs.workingBoldFile = string(workingBoldFile);
outputs.workFolder = workFolder;
outputs.glmBoldFile = derivativeOutputs.glmBoldFile;
outputs.reused = false;

checkpoint.runInfo = runInfo;
checkpoint.smoothingFwhm = options.SmoothingFwhm;
checkpoint.settings = example.preprocessing;
checkpoint.signature = signature;
checkpoint.completedAt = datetime("now");
checkpoint.stage = "preprocess";
spm_jsonwrite(char(derivativeOutputs.checkpointFile), checkpoint, ...
    struct('indent', '  '));

end

function runSmoothing(realignedBoldFile, nVolumes, smoothingFwhm)
scans = arrayfun(@(iVolume) sprintf('%s,%d', ...
    char(realignedBoldFile), iVolume), (1:nVolumes)', UniformOutput=false);
matlabbatch{1}.spm.spatial.smooth.data = scans;
matlabbatch{1}.spm.spatial.smooth.fwhm = smoothingFwhm;
matlabbatch{1}.spm.spatial.smooth.dtype = 0;
matlabbatch{1}.spm.spatial.smooth.im = false;
matlabbatch{1}.spm.spatial.smooth.prefix = 's';
spm_jobman("run", matlabbatch);
end

function outputs = expectedDerivativeOutputs( ...
        derivativeFolder, boldName, boldExtension, smoothingFwhm)
outputs.outputFolder = derivativeFolder;
outputs.realignedBoldFile = fullfile( ...
    derivativeFolder, "r" + boldName + boldExtension);
outputs.smoothedBoldFile = fullfile( ...
    derivativeFolder, "sr" + boldName + boldExtension);
outputs.motionFile = fullfile( ...
    derivativeFolder, "rp_" + boldName + ".txt");
outputs.meanBoldFile = fullfile( ...
    derivativeFolder, "mean" + boldName + boldExtension);
outputs.boldJsonFile = fullfile( ...
    derivativeFolder, boldName + ".json");
outputs.checkpointFile = fullfile( ...
    derivativeFolder, "preprocessing_checkpoint.json");
if any(smoothingFwhm > 0)
    outputs.glmBoldFile = outputs.smoothedBoldFile;
else
    outputs.smoothedBoldFile = "";
    outputs.glmBoldFile = outputs.realignedBoldFile;
end
end

function tf = isComplete(outputs, smoothingFwhm, signature)
requiredFiles = [ ...
    outputs.realignedBoldFile, outputs.motionFile, ...
    outputs.meanBoldFile, outputs.boldJsonFile, outputs.checkpointFile];
if any(smoothingFwhm > 0)
    requiredFiles(end + 1) = outputs.smoothedBoldFile;
end
tf = all(isfile(requiredFiles));
if tf
    checkpoint = jsondecode(fileread(outputs.checkpointFile));
    if ~isfield(checkpoint, "signature") || ...
            ~isequal(jsonencode(checkpoint.signature), jsonencode(signature))
        error("physio4all:PreprocessingCacheMismatch", ...
            "Preprocessing inputs/settings differ or provenance is missing. " + ...
            "Use a fresh output folder or OverwriteFrom=""preprocess"" in the pipeline.");
    end
end
end

function promoteFile(sourceFile, destinationFile)
if ~isfolder(fileparts(destinationFile))
    mkdir(fileparts(destinationFile));
end
if ~isfile(destinationFile)
    copyfile(sourceFile, destinationFile);
end
end
