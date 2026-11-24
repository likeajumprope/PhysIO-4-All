function roiFiles = prepare_noise_rois(runInfo, preprocessing, settings, folder)
%PREPARE_NOISE_ROIS Segment T1w and align eroded WM/CSF masks to BOLD.
%   Threshold and erode in native anatomical voxels. Estimate one rigid
%   transform from bias-corrected T1w to mean BOLD and apply it to both
%   masks, resampling with nearest-neighbour interpolation. Raw inputs
%   are copied before SPM can change their headers.

arguments
    runInfo (1,1) struct
    preprocessing (1,1) struct
    settings (1,1) struct
    folder {mustBeTextScalar}
end

folder = string(folder);
if ~isfolder(folder)
    mkdir(folder);
end
[~, modelLabel] = fileparts(fileparts(folder));
maskNames = modelLabel + ["_wm_mask.nii"; "_csf_mask.nii"];
roiFiles = fullfile(folder, "r" + maskNames);
checkpointFile = fullfile(folder, "noise_rois_checkpoint.mat");
signature.anatomicalFile = fileSignature(runInfo.anatomicalFile);
signature.meanBoldFile = fileSignature(preprocessing.meanBoldFile);
signature.thresholds = settings.noiseThresholds;
signature.crop = settings.noiseVoxelCrop;
if all(isfile(roiFiles)) && isfile(checkpointFile)
    previous = load(checkpointFile, "signature");
    if isequal(previous.signature, signature)
        validateMasks(roiFiles, preprocessing.realignedBoldFile, settings);
        return
    end
end

anatomicalFile = fullfile(folder, "T1w.nii");
copyfile(runInfo.anatomicalFile, anatomicalFile);
batch = segmentationBatch(anatomicalFile);
spm_jobman("run", batch);

tissueFiles = fullfile(folder, ["c2T1w.nii"; "c3T1w.nii"]);
maskFiles = fullfile(folder, maskNames);
for tissue = 1:2
    volume = spm_vol(char(tissueFiles(tissue)));
    probability = spm_read_vols(volume);
    mask = double(isfinite(probability) & ...
        probability > settings.noiseThresholds(tissue));
    for iteration = 1:settings.noiseVoxelCrop(tissue)
        mask = spm_erode(mask);
    end
    assertEnoughVoxels(mask, settings.noiseComponents(tissue), tissue);
    volume.fname = char(maskFiles(tissue));
    volume.dt = [spm_type('uint8') 0];
    volume.pinfo = [1; 0; 0];
    spm_write_vol(volume, mask);
end

% Register the anatomical image, never each binary mask independently.
clear batch
batch{1}.spm.spatial.coreg.estwrite.ref = ...
    cellstr(preprocessing.meanBoldFile);
batch{1}.spm.spatial.coreg.estwrite.source = ...
    cellstr(fullfile(folder, "mT1w.nii"));
batch{1}.spm.spatial.coreg.estwrite.other = cellstr(maskFiles);
batch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
batch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
batch{1}.spm.spatial.coreg.estwrite.eoptions.tol = ...
    [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
batch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
batch{1}.spm.spatial.coreg.estwrite.roptions.interp = 0;
batch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
batch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
batch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
spm_jobman("run", batch);
validateMasks(roiFiles, preprocessing.realignedBoldFile, settings);
save(checkpointFile, "signature", "roiFiles");
end

function batch = segmentationBatch(anatomicalFile)
tpmFile = fullfile(spm('Dir'), 'tpm', 'TPM.nii');
segment.channel.vols = cellstr(anatomicalFile);
segment.channel.biasreg = 0.001;
segment.channel.biasfwhm = 60;
segment.channel.write = [0 1];
gaussians = [1 1 2 3 4 2];
for tissue = 1:6
    segment.tissue(tissue).tpm = {sprintf('%s,%d', tpmFile, tissue)};
    segment.tissue(tissue).ngaus = gaussians(tissue);
    segment.tissue(tissue).native = [ismember(tissue, [2 3]) 0];
    segment.tissue(tissue).warped = [0 0];
end
segment.warp.mrf = 1;
segment.warp.cleanup = 1;
segment.warp.reg = [0 0.001 0.5 0.05 0.2];
segment.warp.affreg = 'mni';
segment.warp.fwhm = 0;
segment.warp.samp = 3;
segment.warp.write = [0 0];
batch{1}.spm.spatial.preproc = segment;
end

function validateMasks(roiFiles, boldFile, settings)
reference = spm_vol(sprintf('%s,1', boldFile));
for tissue = 1:2
    volume = spm_vol(char(roiFiles(tissue)));
    if ~isequal(volume.dim, reference.dim) || ...
            any(abs(volume.mat - reference.mat) > 1e-5, "all")
        error("physio4all:NoiseMaskGeometry", ...
            "Noise masks must match the unsmoothed BOLD voxel grid.");
    end
    mask = spm_read_vols(volume);
    assertEnoughVoxels(mask, settings.noiseComponents(tissue), tissue);
end
end

function assertEnoughVoxels(mask, nComponents, tissue)
if nnz(isfinite(mask) & mask > 0.5) < nComponents + 1
    error("physio4all:InsufficientNoiseVoxels", ...
        "Tissue %d has too few voxels after masking. " + ...
        "Inspect segmentation, erosion, alignment, and BOLD coverage.", tissue);
end
end

function signature = fileSignature(filename)
information = dir(filename);
signature.path = string(filename);
signature.bytes = information.bytes;
signature.modified = information.datenum;
end
