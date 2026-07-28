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
    matlabbatch = physio4all.build_physio_batch( ...
        runInfo, preprocessOutputs, example, outputFolder);
    spm_jobman("run", matlabbatch);
end

outputs.outputFolder = outputFolder;
outputs.physioFile = string(physioFile);
outputs.regressorsFile = string(regressorsFile);

end
