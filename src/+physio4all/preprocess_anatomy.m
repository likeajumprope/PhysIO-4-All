function anatomy = preprocess_anatomy(anatomicalFile, subjectFolder, preprocessing, overwrite)
%PREPROCESS_ANATOMY Segment a T1w or the run mean and establish image geometry.
%   T1w maps can be shared across runs. Mean-EPI maps belong to one run.

arguments
    anatomicalFile (1,1) string
    subjectFolder (1,1) string
    preprocessing (1,1) struct
    overwrite (1,1) logical
end
useMean = anatomicalFile == preprocessing.meanBoldFile;
name = "T1w";
if useMean
    name = "meanBOLD";
end
anatomy.sourceType = name;
anatomy.sourceFile = anatomicalFile;
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
tissueNames = ["c2"; "c3"] + name + ".nii";
requiredImages = [tissueNames; "m" + name + ".nii"; name + "_seg8.mat"];
if generation == "" || ~all(isfile(fullfile(nativeFolder, requiredImages)))
    % SPM writes beside its input. A private generation protects the raw T1
    % and keeps older runs usable if an explicit rebuild is interrupted.
    nativeFolder = string(tempname(folder));
    mkdir(nativeFolder);
    [~, generation] = fileparts(nativeFolder);
    sourceCopy = fullfile(nativeFolder, name + ".nii");
    copyfile(anatomicalFile, sourceCopy);
    fprintf('Segmenting %s: %s\n', name, anatomicalFile);
    batch{1}.spm.spatial.preproc.channel.vols = cellstr(sourceCopy);
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
anatomy.biasCorrectedFile = fullfile(nativeFolder, "m" + name + ".nii");
anatomy.segmentationFile = fullfile(nativeFolder, name + "_seg8.mat");
if useMean
    % Segmentation leaves the tissue maps on the source grid.
    anatomy.sourceToBold = eye(4);
    anatomy.transformFile = "";
else
    anatomy = registerT1(anatomy, preprocessing, overwrite);
end

% SPM stores a source-world to template-world affine in the segmentation.
% Keep its nearest proper rotation; anchor the rigid frame at the native
% point that the full affine maps to MNI [0 0 0].
segment = load(anatomy.segmentationFile, "Affine");
affine = segment.Affine / anatomy.sourceToBold;
[u,~,v] = svd(affine(1:3,1:3));
rotation = u * diag([1 1 sign(det(u*v'))]) * v';
origin = affine \ [0;0;0;1];
anatomy.boldToDisplay = [rotation, -rotation*origin(1:3); 0 0 0 1];

% The report background and SPM results must use the same mm coordinates.
% Change a copy of the small mean image's header; no voxel interpolation.
displayKey = physio4all.cache_key(anatomy.boldToDisplay);
displayFolder = fullfile(preprocessing.outputFolder, "coreg");
if ~isfolder(displayFolder)
    mkdir(displayFolder);
end
anatomy.displayMean = fullfile(displayFolder, displayKey + "_mean.nii");
if ~isfile(anatomy.displayMean)
    pending = string(tempname(displayFolder)) + ".nii";
    copyfile(preprocessing.meanBoldFile, pending);
    mat = spm_get_space(char(pending));
    spm_get_space(char(pending), anatomy.boldToDisplay * mat);
    movefile(pending, anatomy.displayMean, 'f');
end
end

function anatomy = registerT1(anatomy, preprocessing, overwrite)
anatomy.biasCorrectedT1 = anatomy.biasCorrectedFile;
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
transform = load(anatomy.transformFile, "t1ToBold");
anatomy.sourceToBold = transform.t1ToBold;
if ~isfile(anatomy.alignedT1) || overwrite
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
