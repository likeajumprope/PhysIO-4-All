function outputs = preprocess(runInfo, example, workFolder, ...
        derivativeFolder, options)
%PREPROCESS Copy raw BOLD data and run lightweight SPM preprocessing.

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
if isComplete(derivativeOutputs, options.SmoothingFwhm)
    outputs = derivativeOutputs;
    outputs.workFolder = workFolder;
    outputs.workingBoldFile = string(runInfo.boldFile);
    return
end

if ~isfile(workingBoldFile)
    copyfile(runInfo.boldFile, workingBoldFile);
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

checkpoint.runInfo = runInfo;
checkpoint.smoothingFwhm = options.SmoothingFwhm;
checkpoint.completedAt = datetime("now");
save(derivativeOutputs.checkpointFile, "checkpoint");

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
    derivativeFolder, "preprocessing_complete.mat");
if any(smoothingFwhm > 0)
    outputs.glmBoldFile = outputs.smoothedBoldFile;
else
    outputs.smoothedBoldFile = "";
    outputs.glmBoldFile = outputs.realignedBoldFile;
end
end

function tf = isComplete(outputs, smoothingFwhm)
requiredFiles = [ ...
    outputs.realignedBoldFile, outputs.motionFile, ...
    outputs.meanBoldFile, outputs.boldJsonFile, outputs.checkpointFile];
if any(smoothingFwhm > 0)
    requiredFiles(end + 1) = outputs.smoothedBoldFile;
end
tf = all(isfile(requiredFiles));
end

function promoteFile(sourceFile, destinationFile)
if ~isfolder(fileparts(destinationFile))
    mkdir(fileparts(destinationFile));
end
if ~isfile(destinationFile)
    copyfile(sourceFile, destinationFile);
end
end
