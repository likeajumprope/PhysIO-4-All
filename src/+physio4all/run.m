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
    options.Overwrite (1,1) logical = false
    options.OverwritePreprocessing (1,1) logical = false
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

stages = lower(string(options.Stages));
validStages = ["preprocess", "compute_physio", "fit_glm", "assess_physio"];
if any(~ismember(stages, validStages))
    error("physio4all:InvalidStage", ...
        "Stages must be selected from: %s.", strjoin(validStages, ", "));
end

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
physioFolder = fullfile(physioFolder, analysisKey);
glmFolder = fullfile(glmFolder, analysisKey);
assessmentFolder = fullfile(assessmentFolder, analysisKey);

if options.Verbose
    fprintf("\n=== PhysIO-4-All: %s / %s / %s ===\n", ...
        example.id, subjectID, runLabel);
    fprintf("Model: %s (%s)\n", model.id, model.name);
    fprintf("BOLD: %s\n", runInfo.boldFile);
    fprintf("Volumes: %d, TR: %.3f s, physical/PhysIO slices: %d/%d\n", ...
        runInfo.nVolumes, runInfo.repetitionTime, ...
        runInfo.nSlices, runInfo.physioNSlices);
end

needsPreprocessing = any(ismember(stages, ...
    ["preprocess", "compute_physio", "fit_glm", "assess_physio"]));
if needsPreprocessing
    preprocessOutputs = physio4all.preprocess( ...
        runInfo, example, workFolder, preprocessFolder, ...
        Overwrite=options.OverwritePreprocessing, ...
        SmoothingFwhm=model.preprocessing.smoothingFwhm);
end

needsPhysio = any(ismember(stages, ...
    ["compute_physio", "fit_glm", "assess_physio"]));
if needsPhysio
    physioOutputs = physio4all.compute_physio( ...
        runInfo, preprocessOutputs, example, physioFolder, ...
        Overwrite=options.Overwrite || options.OverwritePreprocessing);
end

needsGlm = any(ismember(stages, ["fit_glm", "assess_physio"]));
if needsGlm
    glmOutputs = physio4all.fit_glm( ...
        runInfo, preprocessOutputs, physioOutputs, example, glmFolder, ...
        Overwrite=options.Overwrite || options.OverwritePreprocessing);
end

if ismember("assess_physio", stages)
    assessmentOutputs = physio4all.assess_physio( ...
        runInfo, preprocessOutputs, physioOutputs, glmOutputs, ...
        example, assessmentFolder, ...
        ComputeTsnrGains=options.ComputeTsnrGains, ...
        Overwrite=options.Overwrite || options.OverwritePreprocessing);
end

results.example = example;
results.model = model;
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
