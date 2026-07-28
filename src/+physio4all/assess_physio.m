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
end

assessmentFolder = string(assessmentFolder);
if ~isfolder(assessmentFolder)
    mkdir(assessmentFolder);
end

reportFile = fullfile(assessmentFolder, ...
    sprintf("%s_run-%02d_desc-physioAssessment_report.ps", ...
    runInfo.subjectID, runInfo.runNumber));

if isfile(preprocessOutputs.meanBoldFile)
    structuralFile = preprocessOutputs.meanBoldFile;
else
    structuralFile = preprocessOutputs.workingBoldFile;
end

reportArguments = tapas_physio_report_contrasts( ...
    "fileReport", reportFile, ...
    "fileSpm", glmOutputs.spmFile, ...
    "filePhysIO", physioOutputs.physioFile, ...
    "fileStructural", structuralFile);

if options.ComputeTsnrGains
    previousFolder = pwd;
    restoreFolder = onCleanup(@() cd(previousFolder));
    cd(assessmentFolder);
    tapas_physio_compute_tsnr_gains( ...
        physioOutputs.physioFile, ...
        glmOutputs.spmFile, ...
        example.assessment.tsnrReferenceContrast, ...
        cellstr(example.assessment.tsnrContrastNames));
end

outputs.outputFolder = assessmentFolder;
outputs.reportFile = string(reportFile);
outputs.reportArguments = reportArguments;

end
