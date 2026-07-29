function matlabbatch = build_glm_batch(runInfo, preprocessOutputs, ...
        physioOutputs, example, glmFolder)
%BUILD_GLM_BATCH Build a nuisance-only first-level SPM GLM batch.

arguments
    runInfo (1,1) struct
    preprocessOutputs (1,1) struct
    physioOutputs (1,1) struct
    example (1,1) struct
    glmFolder {mustBeTextScalar}
end

scans = arrayfun(@(iVolume) sprintf('%s,%d', ...
    char(preprocessOutputs.glmBoldFile), iVolume), ...
    (1:runInfo.nVolumes)', UniformOutput=false);

matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(string(glmFolder));
matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'secs';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = runInfo.repetitionTime;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = runInfo.nSlices;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = runInfo.onsetSlice;
matlabbatch{1}.spm.stats.fmri_spec.sess.scans = scans;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond = struct( ...
    "name", {}, "onset", {}, "duration", {}, "tmod", {}, ...
    "pmod", {}, "orth", {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress = ...
    struct("name", {}, "val", {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg = ...
    cellstr(physioOutputs.regressorsFile);
matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = ...
    example.glm.highPassFilter;
matlabbatch{1}.spm.stats.fmri_spec.fact = ...
    struct("name", {}, "levels", {});
matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
matlabbatch{1}.spm.stats.fmri_spec.mthresh = ...
    example.glm.maskThreshold;
matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
matlabbatch{1}.spm.stats.fmri_spec.cvi = ...
    char(example.glm.serialCorrelations);

end
