function outputs = normalize_maps(anatomy, glm, assessment, includeTsnr, exportRoot)
%NORMALIZE_MAPS Export native first-level summaries to the SPM TPM (MNI) grid.
%   Warp signed T-contrast estimates for conventional second-level models.
%   Keep test statistics and denoising metrics identifiable as separate outputs.

data = load(glm.spmFile, "SPM");
contrasts = data.SPM.xCon;
effects = strings(0,1);
effectNames = strings(0,1);
statistics = strings(0,1);
statisticNames = strings(0,1);
for k = 1:numel(contrasts)
    con = contrasts(k);
    if strcmp(con.STAT, 'T') && ~isempty(con.Vcon)
        effects(end+1,1) = fullfile(glm.outputFolder, spm_file(con.Vcon.fname, 'filename'));
        effectNames(end+1,1) = string(con.name);
    end
    if ~isempty(con.Vspm)
        statistics(end+1,1) = fullfile(glm.outputFolder, spm_file(con.Vspm.fname, 'filename'));
        statisticNames(end+1,1) = string(con.name);
    end
end
metrics = strings(0,1);
if includeTsnr
    metrics = assessment.tsnrFiles(:);
end
mask = fullfile(glm.outputFolder, "mask.nii");
sources = [effects; statistics; metrics; mask];
signature.version = 1;
signature.segmentation = physio4all.input_signature(anatomy.segmentationFile);
signature.registration = physio4all.input_signature(anatomy.transformFile);
for k = 1:numel(sources)
    signature.maps(k) = physio4all.input_signature(sources(k));
end
folder = fullfile(exportRoot, physio4all.cache_key(signature));
[~, names, extensions] = fileparts(sources);
warped = fullfile(folder, "w" + names + extensions);
outputs.outputFolder = folder;
outputs.effectNames = effectNames;
outputs.effectFiles = warped(1:numel(effects));
outputs.statisticNames = statisticNames;
outputs.statisticFiles = warped(numel(effects)+(1:numel(statistics)));
outputs.tsnrFiles = warped(numel(effects)+numel(statistics)+(1:numel(metrics)));
outputs.maskFile = warped(end);
checkpoint = fullfile(folder, "normalization.mat");
if isfile(checkpoint) && all(isfile(warped))
    fprintf('Reusing standard-space maps: %s\n', folder);
    return
end
if ~isfolder(folder)
    mkdir(folder);
end

% Write the forward normalization field from SPM's saved segmentation
% parameters. Its lattice is in MNI space and its values are T1 world mm.
% This needs neither another segmentation nor a normalized BOLD series.
anatFolder = fileparts(anatomy.segmentationFile);
fieldFile = fullfile(anatFolder, "y_T1w.nii");
if ~isfile(fieldFile)
    pending = string(tempname(anatFolder));
    mkdir(pending);
    segment = load(anatomy.segmentationFile);
    spm_preproc_write8(segment, false(6,4), false(1,2), [0 1], ...
        1, 1, nan(2,3), nan, char(pending));
    movefile(fullfile(pending, "y_T1w.nii"), fieldFile, 'f');
    rmdir(pending);
end
field = nifti(char(fieldFile));
t1mm = reshape(single(field.dat(:,:,:,1,:)), [], 3);
transform = load(anatomy.transformFile, "t1ToBold");
rigid = single(transform.t1ToBold);
% Pull MNI voxels directly from the BOLD-space map. Applying the rigid
% transform to sample coordinates avoids a second image interpolation.
boldmm = t1mm * rigid(1:3,1:3).' + rigid(1:3,4).';
job.comp{1}.supplied.Def = reshape(boldmm, [size(field.dat,1:3), 3]);
job.comp{1}.supplied.mat = field.mat;
pull.savedir.saveusr = cellstr(folder);
pull.prefix = 'w';
pull.mask = 1;
pull.fwhm = [0 0 0];
pull.interp = 1;
pull.fnames = cellstr(sources(1:end-1));
job.out{1}.pull = pull;
% Nearest-neighbour resampling preserves the binary GLM coverage mask.
pull.interp = 0;
pull.fnames = cellstr(mask);
job.out{2}.pull = pull;
spm_deformations(job);
save(checkpoint, "signature", "outputs", "fieldFile");
end
