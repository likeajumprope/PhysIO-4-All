function outputs = assess_physio(runInfo, preprocessOutputs, ...
        physioOutputs, glmOutputs, example, assessmentFolder, options)
%ASSESS_PHYSIO Create PhysIO statistical reports and tSNR-gain maps.

arguments
    runInfo (1,1) struct
    preprocessOutputs (1,1) struct
    physioOutputs (1,1) struct
    glmOutputs (1,1) struct
    example (1,1) struct
    assessmentFolder {mustBeTextScalar}
    options.ComputeTsnrGains (1,1) logical = true
    options.Overwrite (1,1) logical = false
end

assessmentFolder = string(assessmentFolder);
if options.Overwrite && isfolder(assessmentFolder)
    rmdir(assessmentFolder, "s");
end
if ~isfolder(assessmentFolder)
    mkdir(assessmentFolder);
end

[~, modelLabel] = fileparts(glmOutputs.outputFolder);
filePrefix = sprintf("%s_run-%02d_%s", ...
    runInfo.subjectID, runInfo.runNumber, modelLabel);
statMapFolder = fullfile(assessmentFolder, "statistical_maps");
tsnrFolder = fullfile(assessmentFolder, "tsnr_maps");
reportCheckpointFile = fullfile(assessmentFolder, ...
    filePrefix + "_desc-statisticalMaps_checkpoint.json");
tsnrCheckpointFile = fullfile(assessmentFolder, ...
    filePrefix + "_desc-tsnr_checkpoint.json");

if isfile(preprocessOutputs.meanBoldFile)
    structuralFile = preprocessOutputs.meanBoldFile;
else
    structuralFile = preprocessOutputs.workingBoldFile;
end

if ~isfile(reportCheckpointFile)
    reportFiles = exportStatisticalMaps( ...
        glmOutputs.spmFile, physioOutputs.physioFile, structuralFile, ...
        example.assessment.tsnrContrastNames, statMapFolder, filePrefix);
    checkpoint.completedAt = datetime("now");
    checkpoint.modelLabel = string(modelLabel);
    checkpoint.stage = "statistical_maps";
    checkpoint.files = reportFiles;
    spm_jsonwrite(char(reportCheckpointFile), checkpoint, ...
        struct('indent', '  '));
else
    checkpoint = spm_jsonread(char(reportCheckpointFile));
    reportFiles = string(checkpoint.files);
end

if options.ComputeTsnrGains && ~isfile(tsnrCheckpointFile)
    if ~isfolder(tsnrFolder)
        mkdir(tsnrFolder);
    end
    previousFolder = pwd;
    restoreFolder = onCleanup(@() cd(previousFolder));
    cd(assessmentFolder);
    referenceContrast = example.assessment.tsnrReferenceContrast;
    referenceTsnrFile = fullfile(fileparts(glmOutputs.spmFile), ...
        sprintf("tSNR_con%04d.nii", referenceContrast));
    if ~isfile(referenceTsnrFile)
        % PhysIO's gains helper has a recursive-call argument-order bug when
        % it must create the reference map. Compute and cache it explicitly.
        tapas_physio_compute_tsnr_spm( ...
            char(glmOutputs.spmFile), referenceContrast, []);
    end
    [~, sourceTsnrFiles, ~, sourceRatioFiles] = ...
        tapas_physio_compute_tsnr_gains( ...
        char(physioOutputs.physioFile), ...
        char(glmOutputs.spmFile), ...
        referenceContrast, ...
        cellstr(example.assessment.tsnrContrastNames));
    tsnrFiles = promoteTsnrMaps( ...
        sourceTsnrFiles, sourceRatioFiles, referenceTsnrFile, ...
        example.assessment.tsnrContrastNames, tsnrFolder, filePrefix);
    checkpoint.completedAt = datetime("now");
    checkpoint.modelLabel = string(modelLabel);
    checkpoint.stage = "tsnr";
    checkpoint.referenceContrast = ...
        example.assessment.tsnrReferenceContrast;
    checkpoint.contrastNames = example.assessment.tsnrContrastNames;
    checkpoint.files = tsnrFiles;
    spm_jsonwrite(char(tsnrCheckpointFile), checkpoint, ...
        struct('indent', '  '));
elseif isfile(tsnrCheckpointFile)
    checkpoint = spm_jsonread(char(tsnrCheckpointFile));
    tsnrFiles = string(checkpoint.files);
else
    tsnrFiles = strings(0, 1);
end

outputs.outputFolder = assessmentFolder;
outputs.modelLabel = string(modelLabel);
outputs.statisticalMapFolder = string(statMapFolder);
outputs.statisticalMapFiles = reportFiles;
outputs.tsnrFolder = string(tsnrFolder);
outputs.tsnrFiles = tsnrFiles;
outputs.reportCheckpointFile = string(reportCheckpointFile);
outputs.tsnrCheckpointFile = string(tsnrCheckpointFile);

end

function reportFiles = exportStatisticalMaps( ...
        spmFile, physioFile, structuralFile, contrastNames, ...
        outputFolder, filePrefix)
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

spmData = load(spmFile, "SPM");
physioData = load(physioFile, "physio");
spmData.SPM = tapas_physio_create_missing_physio_contrasts( ...
    spmData.SPM, physioData.physio.model, ...
    tapas_physio_get_contrast_names_default());

previousPrintFormat = spm_get_defaults('ui.print');
restorePrintFormat = onCleanup( ...
    @() spm_get_defaults('ui.print', previousPrintFormat));
spm_get_defaults('ui.print', 'pdf');

nContrasts = numel(contrastNames);
reportFiles = strings(2 * nContrasts, 1);
for contrastIndex = 1:nContrasts
    contrastName = contrastNames(contrastIndex);
    spmContrastIndex = tapas_physio_check_get_xcon_index( ...
        spmData.SPM, char(contrastName));
    if spmContrastIndex == 0
        error("physio4all:MissingAssessmentContrast", ...
            "PhysIO did not create assessment contrast '%s'.", ...
            contrastName);
    end
    filenameLabel = makeFilenameLabel(contrastName);
    pdfFile = fullfile(outputFolder, sprintf( ...
        "%s_desc-%s_statmap.pdf", filePrefix, filenameLabel));
    pngFile = fullfile(outputFolder, sprintf( ...
        "%s_desc-%s_statmap.png", filePrefix, filenameLabel));

    tapas_physio_overlay_contrasts( ...
        'idxContrasts', spmContrastIndex, ...
        'fileReport', char(pdfFile), ...
        'fileSpm', char(spmFile), ...
        'fileStructural', char(structuralFile));
    pdfFile = string(spm_print( ...
        char(pdfFile), 'Graphics', 'pdf'));
    pngFile = string(spm_print( ...
        char(pngFile), 'Graphics', 'png'));
    reportFiles(2 * contrastIndex - 1:2 * contrastIndex) = ...
        [pdfFile; pngFile];
end
end

function outputFiles = promoteTsnrMaps( ...
        sourceTsnrFiles, sourceRatioFiles, referenceFile, ...
        contrastNames, outputFolder, filePrefix)
nContrasts = numel(contrastNames);
outputFiles = strings(2 * nContrasts + 1, 1);
outputFiles(1) = moveMap(referenceFile, fullfile(outputFolder, ...
    filePrefix + "_desc-tsnrRaw_map.nii"));
for contrastIndex = 1:nContrasts
    filenameLabel = makeFilenameLabel(contrastNames(contrastIndex));
    outputFiles(2 * contrastIndex) = moveMap( ...
        sourceTsnrFiles{contrastIndex}, fullfile(outputFolder, sprintf( ...
        "%s_desc-tsnr%s_map.nii", filePrefix, filenameLabel)));
    outputFiles(2 * contrastIndex + 1) = moveMap( ...
        sourceRatioFiles{contrastIndex}, fullfile(outputFolder, sprintf( ...
        "%s_desc-tsnrRatio%sVsRaw_map.nii", ...
        filePrefix, filenameLabel)));
end
end

function destinationFile = moveMap(sourceFile, destinationFile)
sourceFile = string(sourceFile);
destinationFile = string(destinationFile);
if sourceFile ~= destinationFile
    movefile(sourceFile, destinationFile);
end
end

function label = makeFilenameLabel(value)
label = regexprep(string(value), "[^A-Za-z0-9]", "");
end
