function outputs = preprocess(runInfo, example, workFolder, options)
%PREPROCESS Copy raw BOLD data and run lightweight SPM preprocessing.

arguments
    runInfo (1,1) struct
    example (1,1) struct
    workFolder {mustBeTextScalar}
    options.Overwrite (1,1) logical = false
    options.SmoothingFwhm (1,3) {mustBeNumeric, mustBeNonnegative, mustBeReal} = [3 3 3]
end

workFolder = string(workFolder);
if options.Overwrite && isfolder(workFolder)
    rmdir(workFolder, "s");
end
if ~isfolder(workFolder)
    mkdir(workFolder);
end

[~, boldName, boldExtension] = fileparts(runInfo.boldFile);
workingBoldFile = fullfile(workFolder, boldName + boldExtension);
workingJsonFile = fullfile(workFolder, boldName + ".json");

if ~isfile(workingBoldFile)
    copyfile(runInfo.boldFile, workingBoldFile);
end
if ~isfile(workingJsonFile)
    copyfile(runInfo.boldJsonFile, workingJsonFile);
end

realignedBoldFile = fullfile(workFolder, "r" + boldName + boldExtension);
motionFile = fullfile(workFolder, "rp_" + boldName + ".txt");
meanBoldFile = fullfile(workFolder, "mean" + boldName + boldExtension);

if ~isfile(realignedBoldFile) || ~isfile(motionFile)
    matlabbatch = physio4all.build_preprocess_batch( ...
        runInfo, workingBoldFile, example);
    spm_jobman("run", matlabbatch);
end

if any(options.SmoothingFwhm > 0)
    smoothedBoldFile = fullfile(workFolder, ...
        "s" + "r" + boldName + boldExtension);
    if ~isfile(smoothedBoldFile)
        runSmoothing(realignedBoldFile, runInfo.nVolumes, ...
            options.SmoothingFwhm);
    end
    glmBoldFile = smoothedBoldFile;
else
    smoothedBoldFile = "";
    glmBoldFile = realignedBoldFile;
end

outputs.workingBoldFile = string(workingBoldFile);
outputs.realignedBoldFile = string(realignedBoldFile);
outputs.smoothedBoldFile = string(smoothedBoldFile);
outputs.glmBoldFile = string(glmBoldFile);
outputs.motionFile = string(motionFile);
outputs.meanBoldFile = string(meanBoldFile);
outputs.workFolder = workFolder;

end

function runSmoothing(realignedBoldFile, nVolumes, smoothingFwhm)
scans = arrayfun(@(iVolume) sprintf("%s,%d", ...
    realignedBoldFile, iVolume), (1:nVolumes)', UniformOutput=false);
matlabbatch{1}.spm.spatial.smooth.data = scans;
matlabbatch{1}.spm.spatial.smooth.fwhm = smoothingFwhm;
matlabbatch{1}.spm.spatial.smooth.dtype = 0;
matlabbatch{1}.spm.spatial.smooth.im = false;
matlabbatch{1}.spm.spatial.smooth.prefix = "s";
spm_jobman("run", matlabbatch);
end
