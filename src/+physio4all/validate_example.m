function example = validate_example(example)
%VALIDATE_EXAMPLE Validate required fields in an example configuration.

arguments
    example (1,1) struct
end

requiredFields = [ ...
    "id", "name", "dataRelativePath", "defaultSubject", ...
    "defaultModel", "availableRuns", "files", "preprocessing", "physio", ...
    "repoRoot", "configFolder"];

for iField = 1:numel(requiredFields)
    fieldName = requiredFields(iField);
    if ~isfield(example, fieldName)
        error("physio4all:InvalidExample", ...
            "Example configuration is missing field '%s'.", fieldName);
    end
end

requiredFileFields = ...
    ["bold", "boldJson", "cardiac", "respiration", "scanTiming"];
for iField = 1:numel(requiredFileFields)
    fieldName = requiredFileFields(iField);
    if ~isfield(example.files, fieldName)
        error("physio4all:InvalidExample", ...
            "Example file configuration is missing field '%s'.", fieldName);
    end
end

example.id = string(example.id);
example.name = string(example.name);
example.repoRoot = string(example.repoRoot);
example.dataRelativePath = string(example.dataRelativePath);
example.defaultSubject = string(example.defaultSubject);
example.defaultModel = string(example.defaultModel);

end
