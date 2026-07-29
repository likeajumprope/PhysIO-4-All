function logFile = get_log_file( ...
        derivativesRunFolder, subjectID, runNumber, modelID)
%GET_LOG_FILE Return the predictable model-specific pipeline diary path.

arguments
    derivativesRunFolder {mustBeTextScalar}
    subjectID {mustBeTextScalar}
    runNumber (1,1) ...
        {mustBeNumeric, mustBeInteger, mustBePositive, mustBeReal}
    modelID {mustBeTextScalar}
end

logFile = fullfile(derivativesRunFolder, "logs", string(modelID), ...
    sprintf("%s_run-%02d_%s_pipeline.log", ...
    subjectID, runNumber, modelID));

end
