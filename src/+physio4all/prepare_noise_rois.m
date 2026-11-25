function roiFiles = prepare_noise_rois(preprocessing, settings)
%PREPARE_NOISE_ROIS Build WM and CSF masks from preprocessed tissue maps.
%   Erode on the segmentation grid (T1w or mean EPI).

arguments
    preprocessing (1,1) struct
    settings (1,1) struct
end
anatomy = preprocessing.anatomy;
signature.transform = physio4all.input_signature(anatomy.transformFile);
signature.wm = physio4all.input_signature(anatomy.tissueFiles(1));
signature.csf = physio4all.input_signature(anatomy.tissueFiles(2));
signature.thresholds = settings.noiseThresholds;
signature.crop = settings.noiseVoxelCrop;
folder = fullfile(preprocessing.outputFolder, "noise_rois", physio4all.cache_key(signature));
maskNames = ["wm_mask.nii"; "csf_mask.nii"];
maskFiles = fullfile(folder, maskNames);
reslice = anatomy.sourceType == "T1w";
roiFiles = maskFiles;
if reslice
    roiFiles = fullfile(folder, "r" + maskNames);
end
checkpointFile = fullfile(folder, "noise_rois_checkpoint.mat");
if isfile(checkpointFile) && all(isfile(roiFiles))
    validateMasks(roiFiles, preprocessing.realignedBoldFile, settings);
    fprintf('Reusing WM/CSF masks: %s\n', folder);
    return
end
if ~isfolder(folder)
    mkdir(folder);
end

for tissue = 1:2
    volume = spm_vol(char(anatomy.tissueFiles(tissue)));
    probability = spm_read_vols(volume);
    mask = double(isfinite(probability) & ...
        probability > settings.noiseThresholds(tissue));
    for iteration = 1:settings.noiseVoxelCrop(tissue)
        mask = spm_erode(mask);
    end
    % Apply the estimated transform only to the new binary mask header.
    volume.mat = anatomy.sourceToBold * volume.mat;
    volume.fname = char(maskFiles(tissue));
    volume.dt = [spm_type('uint8') 0];
    volume.pinfo = [1; 0; 0];
    spm_write_vol(volume, mask);
end

% Both masks are now in BOLD world coordinates. Sample the binary labels
% on the mean BOLD grid using nearest-neighbour interpolation.
flags = struct('interp', 0, 'mask', false, 'mean', false, 'which', 1, ...
    'wrap', [0 0 0], 'prefix', 'r');
if reslice
    spm_reslice(cellstr([preprocessing.meanBoldFile; maskFiles]), flags);
end
validateMasks(roiFiles, preprocessing.realignedBoldFile, settings);
save(checkpointFile, "signature", "roiFiles");
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
