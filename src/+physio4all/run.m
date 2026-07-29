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
subjectID = string(options.Subject);
if strlength(subjectID) == 0
    subjectID = example.defaultSubject;
end

dataRoot = resolveRoot(options.DataRoot, example.repoRoot, "data");
workRoot = resolveRoot(options.WorkRoot, example.repoRoot, "work");
derivativesRoot = resolveRoot( ...
    options.DerivativesRoot, example.repoRoot, "derivatives");

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

physio4all_setup();
spm_jobman("initcfg");

runInfo = physio4all.resolve_files( ...
    example, subjectID, options.Run, dataRoot);
runLabel = sprintf("run-%02d", options.Run);
workFolder = fullfile(workRoot, example.id, subjectID, runLabel, "preproc");
derivativeRunFolder = fullfile( ...
    derivativesRoot, example.id, subjectID, runLabel);
preprocessFolder = fullfile(derivativeRunFolder, "preproc");
physioFolder = fullfile(derivativeRunFolder, "physio");
glmFolder = fullfile(derivativeRunFolder, "glm", model.id);
assessmentFolder = fullfile(derivativeRunFolder, "assessment", ...
    model.id);

if options.Verbose
    fprintf("\n=== PhysIO-4-All: %s / %s / %s ===\n", ...
        example.id, subjectID, runLabel);
    fprintf("Model: %s (%s)\n", model.id, model.name);
    fprintf("BOLD: %s\n", runInfo.boldFile);
    fprintf("Volumes: %d, TR: %.3f s, slices/events: %d/%d\n", ...
        runInfo.nVolumes, runInfo.repetitionTime, ...
        runInfo.nSlices, runInfo.nSliceEvents);
end

needsPreprocessing = any(ismember(stages, ...
    ["preprocess", "compute_physio", "fit_glm", "assess_physio"]));
if needsPreprocessing
    preprocessOutputs = physio4all.preprocess( ...
        runInfo, example, workFolder, preprocessFolder, ...
        Overwrite=options.Overwrite, ...
        SmoothingFwhm=model.preprocessing.smoothingFwhm);
end

needsPhysio = any(ismember(stages, ...
    ["compute_physio", "fit_glm", "assess_physio"]));
if needsPhysio
    physioOutputs = physio4all.compute_physio( ...
        runInfo, preprocessOutputs, example, physioFolder, ...
        Overwrite=options.Overwrite);
end

needsGlm = any(ismember(stages, ["fit_glm", "assess_physio"]));
if needsGlm
    glmOutputs = physio4all.fit_glm( ...
        runInfo, preprocessOutputs, physioOutputs, example, glmFolder, ...
        Overwrite=options.Overwrite);
end

if ismember("assess_physio", stages)
    assessmentOutputs = physio4all.assess_physio( ...
        runInfo, preprocessOutputs, physioOutputs, glmOutputs, ...
        example, assessmentFolder, ...
        ComputeTsnrGains=options.ComputeTsnrGains, ...
        Overwrite=options.Overwrite);
end

results.example = example;
results.model = model;
results.runInfo = runInfo;
results.paths.dataRoot = string(dataRoot);
results.paths.workRoot = string(workRoot);
results.paths.derivativesRoot = string(derivativesRoot);
results.paths.logFile = logFile;
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
