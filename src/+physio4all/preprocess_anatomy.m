function anatomy = preprocess_anatomy(anatomicalFile, subjectFolder, preprocessing, overwrite)
%PREPROCESS_ANATOMY Segment the subject T1w and align it to the run's mean BOLD.
%   Native WM and CSF probabilities are shared across runs and excerpts.
%   Each mean BOLD needs its own rigid transform, shared by both tissues.

batch = segmentationBatch(anatomicalFile);
signature.t1 = physio4all.input_signature(anatomicalFile);
signature.template = physio4all.input_signature(fullfile(spm('Dir'), 'tpm', 'TPM.nii'));
signature.segment = batch{1}.spm.spatial.preproc;
folder = fullfile(subjectFolder, "anat", physio4all.cache_key(signature));
if ~isfolder(folder)
    mkdir(folder);
end
checkpoint = fullfile(folder, "segmentation.mat");
generation = "";
if ~overwrite && isfile(checkpoint)
    saved = load(checkpoint, "generation");
    generation = saved.generation;
end
nativeFolder = fullfile(folder, generation);
tissueNames = ["c2T1w.nii"; "c3T1w.nii"];
requiredImages = [tissueNames; "mT1w.nii"; "T1w_seg8.mat"];
if generation == "" || ~all(isfile(fullfile(nativeFolder, requiredImages)))
    % SPM writes beside its input. A private generation protects the raw T1
    % and keeps older runs usable if an explicit rebuild is interrupted.
    nativeFolder = string(tempname(folder));
    mkdir(nativeFolder);
    [~, generation] = fileparts(nativeFolder);
    t1Copy = fullfile(nativeFolder, "T1w.nii");
    copyfile(anatomicalFile, t1Copy);
    batch{1}.spm.spatial.preproc.channel.vols = cellstr(t1Copy);
    spm_jobman('run', batch);
    if ~all(isfile(fullfile(nativeFolder, requiredImages)))
        error("physio4all:IncompleteSegmentation", ...
            "SPM did not produce all expected anatomical images in %s.", nativeFolder);
    end
    pending = fullfile(nativeFolder, "segmentation.mat");
    save(pending, "generation");
    movefile(pending, checkpoint, 'f');
else
    fprintf('Reusing native WM/CSF probability maps: %s\n', nativeFolder);
end
anatomy.tissueFiles = fullfile(nativeFolder, tissueNames);
anatomy.biasCorrectedT1 = fullfile(nativeFolder, "mT1w.nii");
anatomy.segmentationFile = fullfile(nativeFolder, "T1w_seg8.mat");

% BOLD realignment only registers volumes within a run. Estimate the
% between-modality transform from the whole bias-corrected T1. spm_coreg
% returns parameters without modifying the shared anatomical headers.
estimate = spm_get_defaults('coreg.estimate');
registration.t1 = physio4all.input_signature(anatomy.biasCorrectedT1);
registration.reference = physio4all.input_signature(preprocessing.meanBoldFile);
registration.settings = estimate;
coregFolder = fullfile(preprocessing.outputFolder, "coreg");
if ~isfolder(coregFolder)
    mkdir(coregFolder);
end
anatomy.transformFile = fullfile(coregFolder, physio4all.cache_key(registration) + ".mat");
if isfile(anatomy.transformFile) && ~overwrite
    fprintf('Reusing T1w-to-mean-BOLD transform: %s\n', anatomy.transformFile);
else
    parameters = spm_coreg(char(preprocessing.meanBoldFile), char(anatomy.biasCorrectedT1), estimate);
    % SPM estimates reference-to-source parameters. Invert for mapping
    % T1 world coordinates into BOLD world coordinates (see spm_run_coreg).
    t1ToBold = spm_matrix(parameters) \ eye(4);
    pending = string(tempname(coregFolder)) + ".mat";
    save(pending, "t1ToBold", "registration");
    movefile(pending, anatomy.transformFile, 'f');
end
% A small view on the mean-BOLD grid makes alignment inspectable while the
% original high-resolution T1 and its subject-space header remain reusable.
anatomy.alignedT1 = replace(anatomy.transformFile, ".mat", "_T1w.nii");
if ~isfile(anatomy.alignedT1) || overwrite
    transform = load(anatomy.transformFile, "t1ToBold");
    source = spm_vol(char(anatomy.biasCorrectedT1));
    source.mat = transform.t1ToBold * source.mat;
    ref = spm_vol(char(preprocessing.meanBoldFile));
    pending = string(tempname(coregFolder)) + ".nii";
    output = struct('fname', char(pending), 'dim', ref.dim, 'mat', ref.mat, ...
        'dt', [spm_type('float32') 0], 'pinfo', [1;0;0]);
    spm_imcalc(source, output, 'i1', {0,0,1,'float32'});
    movefile(pending, anatomy.alignedT1, 'f');
end
end

function batch = segmentationBatch(anatomicalFile)
tpmFile = fullfile(spm('Dir'), 'tpm', 'TPM.nii');
segment.channel.vols = cellstr(anatomicalFile);
segment.channel.biasreg = 0.001;
segment.channel.biasfwhm = 60;
% Save the bias-corrected T1w and native c2 (WM) and c3 (CSF) posteriors.
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
