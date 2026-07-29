function model = get_model(example, modelID)
%GET_MODEL Return a model configuration for an example dataset.

arguments
    example (1,1) struct
    modelID {mustBeTextScalar}
end

modelID = lower(string(modelID));
if isempty(regexp(modelID, "^model-[0-9]{3}$", "once"))
    error("physio4all:InvalidModelID", ...
        "Model IDs must use the form 'model-001'.");
end

modelsFolder = fullfile(example.repoRoot, "models");
functionName = "physio4all_" + replace(modelID, "-", "_");
configFile = fullfile(modelsFolder, functionName + ".m");
if ~isfile(configFile)
    error("physio4all:UnknownModel", ...
        "Model configuration '%s' was not found for example '%s'.", ...
        modelID, example.id);
end

originalPath = path;
restorePath = onCleanup(@() path(originalPath));
addpath(modelsFolder);
model = feval(functionName);
if string(model.id) ~= modelID
    error("physio4all:ModelIDMismatch", ...
        "Configuration %s declares model ID '%s'.", configFile, model.id);
end
requiredSections = ["preprocessing", "physio", "glm", "assessment"];
if any(~isfield(model, requiredSections))
    error("physio4all:InvalidModel", ...
        "Model configuration '%s' is missing a required section.", modelID);
end

end
