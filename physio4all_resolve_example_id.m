function exampleID = physio4all_resolve_example_id(identifier)
%PHYSIO4ALL_RESOLVE_EXAMPLE_ID Resolve a canonical example ID or mnemonic.

arguments
    identifier {mustBeTextScalar}
end

identifier = lower(string(identifier));
registry = physio4all_example_registry();
ids = [registry.id];
mnemonics = [registry.mnemonic];
index = find(strcmpi(identifier, ids) | strcmpi(identifier, mnemonics), 1);
if isempty(index)
    error("physio4all:UnknownExample", "Unknown example '%s'.", identifier);
end
exampleID = ids(index);
end
