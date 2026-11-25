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
spec = load(spmFile, "SPM");
SPM = spec.SPM;
% SPM allocates ResMS before fitting any voxels. The fitted model fields
% are saved at the end; also check its image files before resuming.
estimated = all(isfield(SPM, {'Vbeta','VM','VResMS','xVol'})) && ...
    isfield(SPM.xVol, 'VRpv');
if estimated
    fitFiles = [string({SPM.Vbeta.fname}), string(SPM.VM.fname), ...
        string(SPM.VResMS.fname), string(SPM.xVol.VRpv.fname)];
    [~, names, extensions] = fileparts(fitFiles);
    estimated = all(isfile(fullfile(glmFolder, names + extensions)));
end
if ~estimated
    % SPM takes its results geometry from xY.VY(1).mat and reads data by
    % voxel index. Orient the scan descriptors before estimation so mask,
    % betas, contrasts and the glass brain all use the same rigid frame.
    % Keep the shared 4-D BOLD data on their original grid.
    if ~isfield(SPM, 'physio4allBoldToDisplay')
        rigid = preprocessOutputs.anatomy.boldToDisplay;
        for scan = 1:numel(SPM.xY.VY)
            SPM.xY.VY(scan).mat = rigid * SPM.xY.VY(scan).mat;
        end
        SPM.physio4allBoldToDisplay = rigid;
        pending = string(tempname(glmFolder)) + ".mat";
        save(pending, "SPM", spm_get_defaults('mat.format'));
        movefile(pending, spmFile, 'f');
    end
    estimationBatch{1}.spm.stats.fmri_est.spmmat = cellstr(spmFile);
    estimationBatch{1}.spm.stats.fmri_est.write_residuals = false;
    estimationBatch{1}.spm.stats.fmri_est.method.Classical = 1;
    spm_jobman("run", estimationBatch);
end

outputs.outputFolder = glmFolder;
outputs.spmFile = string(spmFile);
outputs.residualMeanSquareFile = string(residualMeanSquareFile);

end
