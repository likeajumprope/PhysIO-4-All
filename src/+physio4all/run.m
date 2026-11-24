function results = run(exampleID, options)
%RUN Execute selected stages of a PhysIO-4-All example.

arguments
    exampleID {mustBeTextScalar}
    options.Subject {mustBeTextScalar} = ""
    options.Run (1,1) {mustBeNumeric, mustBeInteger, mustBePositive, mustBeReal} = 1
    options.Model {mustBeTextScalar} = ""
    options.Stages {mustBeText} = ...
        ["preprocess", "compute_physio", "fit_glm", "assess_physio"]
    options.DataRoot {mustBeTextScalar} = ""
    options.WorkRoot {mustBeTextScalar} = ""
    options.DerivativesRoot {mustBeTextScalar} = ""
    options.OverwriteFrom {mustBeTextScalar} = "none"
    options.QuickCheck (1,1) logical = false
    options.QuickCheckVolumes (1,1) double {mustBeInteger, mustBePositive, mustBeFinite} = 100
    options.EnableDiary (1,1) logical = true
    options.LogFile {mustBeTextScalar} = ""
    options.ComputeTsnrGains (1,1) logical = true
    options.Verbose (1,1) logical = true
end

example = physio4all.get_example(exampleID);
modelID = string(options.Model);
if strlength(modelID) == 0
    modelID = example.defaultModel;
end
model = physio4all.get_model(example, modelID);
example = physio4all.configure_model(example, model);
example.modelID = model.id;
subjectID = string(options.Subject);
if strlength(subjectID) == 0
    subjectID = example.defaultSubject;
end

dataRoot = resolveRoot(options.DataRoot, example.repoRoot, "data");
workRoot = resolveRoot(options.WorkRoot, example.repoRoot, "work");
derivativesRoot = resolveRoot( ...
    options.DerivativesRoot, example.repoRoot, "derivatives");
runLabel = sprintf("run-%02d", options.Run);
if options.QuickCheck
    runLabel = string(runLabel) + sprintf("_quickcheck-%04d", options.QuickCheckVolumes);
end
workFolder = fullfile(workRoot, example.id, subjectID, runLabel, "preproc");
derivativeRunFolder = fullfile( ...
    derivativesRoot, example.id, subjectID, runLabel);
preprocessFolder = fullfile(derivativeRunFolder, "preproc");
physioFolder = fullfile(derivativeRunFolder, "physio");
% Preserve the legacy model-001 cache; other models must never reuse it.
if model.id ~= "model-001"
    physioFolder = fullfile(physioFolder, model.id);
end
glmFolder = fullfile(derivativeRunFolder, "glm", model.id);
assessmentFolder = fullfile(derivativeRunFolder, "assessment", ...
    model.id);

plan = physio4all.plan_stages(options.Stages, options.OverwriteFrom);

logFile = string(options.LogFile);
if options.EnableDiary
    if strlength(logFile) == 0
        logFile = physio4all.get_log_file( ...
            derivativeRunFolder, subjectID, options.Run, model.id);
    end
    logFolder = fileparts(logFile);
    if ~isfolder(logFolder)
        mkdir(logFolder);
    end
    diary(char(logFile));
    diaryCleanup = onCleanup(@stopDiary);
    fprintf("\n=== Pipeline invocation started: %s ===\n", ...
        char(datetime("now")));
else
    logFile = "";
end

initializeDependencies(example.repoRoot);

runInfo = physio4all.resolve_files( ...
    example, subjectID, options.Run, dataRoot);
runInfo.fullNVolumes = runInfo.nVolumes;
if options.QuickCheck
    runInfo.nVolumes = min(runInfo.fullNVolumes, options.QuickCheckVolumes);
end
% Cache namespaces exclude the model ID, so compatible models share images.
preprocessingSignature.version = 1;
preprocessingSignature.bold = physio4all.input_signature(runInfo.boldFile);
preprocessingSignature.json = physio4all.input_signature(runInfo.boldJsonFile);
preprocessingSignature.nVolumes = runInfo.nVolumes;
preprocessingSignature.settings = example.preprocessing;
preprocessingSignature.spm = string(spm('Dir'));
preprocessingKey = physio4all.cache_key(preprocessingSignature);
workFolder = fullfile(workFolder, preprocessingKey);
preprocessFolder = fullfile(preprocessFolder, preprocessingKey);
analysisSignature.version = 1;
analysisSignature.preprocessing = preprocessingKey;
analysisSignature.glm = example.glm;
analysisSignature.assessment = example.assessment;
analysisSignature.physio = example.physio;
analysisSignature.cardiac = physio4all.input_signature(runInfo.cardiacFile);
analysisSignature.respiration = physio4all.input_signature(runInfo.respirationFile);
analysisSignature.timing = physio4all.input_signature(runInfo.scanTimingFile);
if isfield(runInfo, "anatomicalFile")
    analysisSignature.anatomical = physio4all.input_signature(runInfo.anatomicalFile);
end
analysisKey = physio4all.cache_key(analysisSignature);

if options.Verbose
    fprintf("\n=== PhysIO-4-All: %s / %s / %s ===\n", ...
        example.id, subjectID, runLabel);
    fprintf("Model: %s (%s)\n", model.id, model.name);
    fprintf("BOLD: %s\n", runInfo.boldFile);
    fprintf("Volumes: %d, TR: %.3f s, physical/PhysIO slices: %d/%d\n", ...
        runInfo.nVolumes, runInfo.repetitionTime, ...
        runInfo.nSlices, runInfo.physioNSlices);
end

if plan.required(1)
    preprocessOutputs = physio4all.preprocess( ...
        runInfo, example, workFolder, preprocessFolder, ...
        Overwrite=plan.overwrite(1), ...
        SmoothingFwhm=model.preprocessing.smoothingFwhm);
    % A recording-based model needs only BOLD preprocessing. An aCompCor
    % preprocessing-only run also delivers native tissue maps and alignment.
    if isfield(runInfo, "anatomicalFile")
        subjectFolder = fullfile(derivativesRoot, example.id, subjectID);
        preprocessOutputs.anatomy = physio4all.preprocess_anatomy( ...
            runInfo.anatomicalFile, subjectFolder, preprocessOutputs, plan.overwrite(1));
    end
end

if plan.required(2)
    physioSignature.analysis = analysisKey;
    physioSignature.preprocessing = physio4all.input_signature(preprocessOutputs.checkpointFile);
    if isfield(preprocessOutputs, "anatomy")
        % Replacing the anatomical inputs also invalidates a cached PCA fit.
        anatomy = preprocessOutputs.anatomy;
        physioSignature.transform = physio4all.input_signature(anatomy.transformFile);
        physioSignature.wm = physio4all.input_signature(anatomy.tissueFiles(1));
        physioSignature.csf = physio4all.input_signature(anatomy.tissueFiles(2));
    end
    physioFolder = fullfile(physioFolder, physio4all.cache_key(physioSignature));
    physioOutputs = physio4all.compute_physio( ...
        runInfo, preprocessOutputs, example, physioFolder, ...
        Overwrite=plan.overwrite(2));
end

if plan.required(3)
    glmSignature.analysis = analysisKey;
    glmSignature.regressors = physio4all.input_signature(physioOutputs.regressorsFile);
    glmFolder = fullfile(glmFolder, physio4all.cache_key(glmSignature));
    glmOutputs = physio4all.fit_glm( ...
        runInfo, preprocessOutputs, physioOutputs, example, glmFolder, ...
        Overwrite=plan.overwrite(3));
end

if plan.required(4)
    assessmentSignature.analysis = analysisKey;
    assessmentSignature.fit = physio4all.input_signature(glmOutputs.residualMeanSquareFile);
    assessmentFolder = fullfile(assessmentFolder, physio4all.cache_key(assessmentSignature));
    assessmentOutputs = physio4all.assess_physio( ...
        runInfo, preprocessOutputs, physioOutputs, glmOutputs, ...
        example, assessmentFolder, ...
        ComputeTsnrGains=options.ComputeTsnrGains, ...
        Overwrite=plan.overwrite(4));
end

results.example = example;
results.model = model;
results.plan = plan;
results.runInfo = runInfo;
results.paths.dataRoot = string(dataRoot);
results.paths.workRoot = string(workRoot);
results.paths.derivativesRoot = string(derivativesRoot);
results.paths.logFile = logFile;
results.paths.preprocessingKey = preprocessingKey;
results.paths.analysisKey = analysisKey;
results.quickCheck.enabled = options.QuickCheck;
results.quickCheck.requestedVolumes = options.QuickCheckVolumes;
results.quickCheck.processedVolumes = runInfo.nVolumes;
results.quickCheck.fullRunVolumes = runInfo.fullNVolumes;
if exist("preprocessOutputs", "var")
    results.preprocess = preprocessOutputs;
end
if exist("physioOutputs", "var")
    results.physio = physioOutputs;
end
if exist("glmOutputs", "var")
    results.glm = glmOutputs;
end
if exist("assessmentOutputs", "var")
    results.assessment = assessmentOutputs;
end
fprintf("=== Pipeline invocation completed: %s ===\n", ...
    char(datetime("now")));

end

function initializeDependencies(repoRoot)
% Avoid repeatedly rebuilding SPM's registry during a model comparison.
persistent initializedRoot
expectedSpm = fullfile(repoRoot, "external", "spm", "spm.m");
expectedPhysio = fullfile(repoRoot, "external", "PhysIO", "tapas_physio_new.m");
if isempty(initializedRoot) || initializedRoot ~= string(repoRoot) || ...
        ~strcmpi(which('spm'), expectedSpm) || ...
        ~strcmpi(which('tapas_physio_new'), expectedPhysio)
    physio4all_setup();
    spm_jobman("initcfg");
    initializedRoot = string(repoRoot);
end
end

function stopDiary()
fprintf("=== Pipeline invocation ended: %s ===\n", ...
    char(datetime("now")));
diary("off");
end

function rootPath = resolveRoot(requestedPath, repoRoot, defaultName)
if strlength(string(requestedPath)) == 0
    rootPath = fullfile(repoRoot, defaultName);
else
    rootPath = string(requestedPath);
end
end
