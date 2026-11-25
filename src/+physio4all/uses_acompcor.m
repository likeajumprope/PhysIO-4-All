function tf = uses_acompcor(settings)
%USES_ACOMPCOR Select tissue PCA from the model's PhysIO settings.
%   Configurations predating the method field use recorded physiology.
arguments
    settings (1,1) struct
end
tf = isfield(settings, "method") && strcmpi(settings.method, "acompcor");
end
