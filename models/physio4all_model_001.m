function model = physio4all_model_001()
%PHYSIO4ALL_MODEL_001 Lightweight PhysIO nuisance-regression model.

model.id = "model-001";
model.name = "RETROICOR + HRV + RVT with 3 mm smoothing";
model.description = [ ...
    "Lightweight realignment and 3 mm smoothing followed by a " ...
    "nuisance-only SPM GLM with RETROICOR, HRV, RVT, and movement regressors."];

model.preprocessing.smoothingFwhm = [3 3 3];

model.physio.method = "recordings";
model.physio.includeRetroicor = true;
model.physio.includeRvt = true;
model.physio.includeHrv = true;
model.physio.cardiacOrder = 3;
model.physio.respiratoryOrder = 4;
model.physio.interactionOrder = 1;
model.physio.rvtMethod = "hilbert";
model.physio.rvtDelays = 0;
model.physio.hrvDelays = 0;
model.physio.movementOrder = 6;
% Spike regressors are optional; all derived models inherit this switch.
model.physio.movementCensoringEnabled = false;
model.physio.movementCensoringMethod = "MAXVAL";
model.physio.movementCensoringThreshold = [3 Inf];

model.glm.highPassFilter = 128;
model.glm.serialCorrelations = "AR(1)";
model.glm.maskThreshold = 0.8;

model.assessment.tsnrReferenceContrast = 0;
model.assessment.tsnrContrastNames = ...
    ["Cardiac", "RespiratoryVolumePerTime"];

end
