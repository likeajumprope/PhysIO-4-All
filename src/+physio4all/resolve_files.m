function runInfo = resolve_files(example, subjectID, runNumber, dataRoot)
%RESOLVE_FILES Resolve imaging, physiology, and acquisition metadata.

arguments
    example (1,1) struct
    subjectID {mustBeTextScalar}
    runNumber (1,1) {mustBeNumeric, mustBeInteger, mustBePositive, mustBeReal}
    dataRoot {mustBeTextScalar}
end

subjectID = string(subjectID);
dataRoot = string(dataRoot);

if ~ismember(runNumber, example.availableRuns)
    error("physio4all:UnavailableRun", ...
        "Run %d is not configured for example '%s'.", runNumber, example.id);
end

datasetRoot = fullfile(dataRoot, example.dataRelativePath);
subjectRoot = fullfile(datasetRoot, subjectID);
funcFolder = fullfile(subjectRoot, "func");
physioFolder = fullfile(subjectRoot, "physio");

boldBaseName = sprintf(example.files.bold, subjectID, runNumber);
boldJsonBaseName = sprintf(example.files.boldJson, subjectID, runNumber);
boldFile = fullfile(funcFolder, boldBaseName);
boldJsonFile = fullfile(funcFolder, boldJsonBaseName);

assertFileExists(boldFile, "BOLD image");
assertFileExists(boldJsonFile, "BOLD JSON sidecar");

cardiacFile = selectOneFile(physioFolder, ...
    sprintf(example.files.cardiac, runNumber), "cardiac log");
respirationFile = selectOneFile(physioFolder, ...
    sprintf(example.files.respiration, runNumber), "respiration log");
scanTimingFile = selectOneFile(physioFolder, ...
    sprintf(example.files.scanTiming, runNumber), "scan-timing log");

metadata = jsondecode(fileread(boldJsonFile));
niftiMetadata = niftiinfo(boldFile);

if numel(niftiMetadata.ImageSize) < 4
    error("physio4all:InvalidBoldImage", ...
        "Expected a 4-D BOLD image: %s", boldFile);
end

runInfo.exampleID = example.id;
runInfo.subjectID = subjectID;
runInfo.runNumber = runNumber;
runInfo.datasetRoot = string(datasetRoot);
runInfo.subjectRoot = string(subjectRoot);
runInfo.boldFile = string(boldFile);
runInfo.boldJsonFile = string(boldJsonFile);
runInfo.cardiacFile = string(cardiacFile);
runInfo.respirationFile = string(respirationFile);
runInfo.scanTimingFile = string(scanTimingFile);
runInfo.nVolumes = niftiMetadata.ImageSize(4);
runInfo.repetitionTime = metadata.RepetitionTime;
runInfo.nSlices = numel(metadata.SliceTiming);
runInfo.multibandFactor = getOptionalField(metadata, ...
    "MultibandAccelerationFactor", 1);
runInfo.nSliceEvents = numel(unique(metadata.SliceTiming));
runInfo.onsetSlice = ceil(runInfo.nSliceEvents / 2);
runInfo.taskName = string(getOptionalField(metadata, "TaskName", "unknown"));

end

function value = getOptionalField(inputStruct, fieldName, defaultValue)
if isfield(inputStruct, fieldName)
    value = inputStruct.(fieldName);
else
    value = defaultValue;
end
end

function filePath = selectOneFile(folderPath, pattern, description)
files = dir(fullfile(folderPath, "*"));
files = files(~[files.isdir]);
isMatch = ~cellfun("isempty", regexp({files.name}, pattern, "once"));
matches = files(isMatch);

if numel(matches) ~= 1
    error("physio4all:FileSelection", ...
        "Expected exactly one %s matching '%s' under %s; found %d.", ...
        description, pattern, folderPath, numel(matches));
end

filePath = fullfile(matches.folder, matches.name);
end

function assertFileExists(filePath, description)
if ~isfile(filePath)
    error("physio4all:MissingFile", ...
        "Missing %s: %s", description, filePath);
end
end
