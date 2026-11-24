function key = cache_key(configuration)
%CACHE_KEY Stable identifier for processing inputs and explicit settings.
arguments
    configuration
end
% Independent modular rolling hashes; no JVM or optional toolbox required.
% Products stay below flintmax, preserving integer arithmetic in doubles.
bytes = unicode2native(jsonencode(configuration), 'UTF-8');
state = [0 0 0];
primes = [4294967291 4294967279 4294967231];
for value = bytes
    state = mod(state.*[65599 131071 524287] + double(value), primes);
end
key = string(lower(reshape(dec2hex(state, 8).', 1, [])));
end
