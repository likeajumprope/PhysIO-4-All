function configuredExample = configure_model(example, model)
%CONFIGURE_MODEL Apply a model configuration to a dataset example.

arguments
    example (1,1) struct
    model (1,1) struct
end

configuredExample = example;
sections = ["preprocessing", "physio", "glm", "assessment"];
for section = sections
    fields = fieldnames(model.(section));
    for fieldIndex = 1:numel(fields)
        field = fields{fieldIndex};
        configuredExample.(section).(field) = model.(section).(field);
    end
end

end
