function outputs = fit_glm(runInfo, preprocessOutputs, physioOutputs, ...
        example, glmFolder, options)
%FIT_GLM Fit a nuisance-only SPM GLM using PhysIO regressors.

arguments
    runInfo (1,1) struct
    preprocessOutputs (1,1) struct
    physioOutputs (1,1) struct
    example (1,1) struct
    glmFolder {mustBeTextScalar}
    options.Overwrite (1,1) logical = false
end

glmFolder = string(glmFolder);
if options.Overwrite && isfolder(glmFolder)
    rmdir(glmFolder, "s");
end
if ~isfolder(glmFolder)
    mkdir(glmFolder);
end

spmFile = fullfile(glmFolder, "SPM.mat");
if ~isfile(spmFile)
    specificationBatch = physio4all.build_glm_batch( ...
        runInfo, preprocessOutputs, physioOutputs, example, glmFolder);
    spm_jobman("run", specificationBatch);
end

residualMeanSquareFile = fullfile(glmFolder, "ResMS.nii");
if ~isfile(residualMeanSquareFile)
    estimationBatch{1}.spm.stats.fmri_est.spmmat = cellstr(spmFile);
    estimationBatch{1}.spm.stats.fmri_est.write_residuals = false;
    estimationBatch{1}.spm.stats.fmri_est.method.Classical = 1;
    spm_jobman("run", estimationBatch);
end

outputs.outputFolder = glmFolder;
outputs.spmFile = string(spmFile);
outputs.residualMeanSquareFile = string(residualMeanSquareFile);

end
