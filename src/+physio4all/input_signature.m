function signature = input_signature(filename)
%INPUT_SIGNATURE Identify an input by absolute path, size, and modification time.
arguments
    filename {mustBeTextScalar}
end
signature.path = string(filename);
if strlength(signature.path) == 0
    return
end
information = dir(filename);
if numel(information) ~= 1 || information.isdir
    error("physio4all:MissingFile", "Expected one input file: %s", filename);
end
signature.bytes = information.bytes;
signature.modified = information.datenum;
end
