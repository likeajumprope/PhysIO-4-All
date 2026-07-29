function model = physio4all_model_001()
%PHYSIO4ALL_MODEL_001 Lightweight PhysIO nuisance-regression model.

model.id = "model-001";
model.name = "PhysIO nuisance model with 3 mm smoothing";
model.description = [ ...
    "Lightweight realignment and 3 mm smoothing followed by a " ...
    "nuisance-only SPM GLM with RETROICOR, RVT, and movement regressors."];

model.preprocessing.smoothingFwhm = [3 3 3];

model.physio.cardiacOrder = 3;
model.physio.respiratoryOrder = 4;
model.physio.interactionOrder = 1;
model.physio.rvtMethod = "hilbert";
model.physio.rvtDelays = 0;
model.physio.hrvDelays = 0;
model.physio.movementOrder = 6;
model.physio.movementCensoringMethod = "MAXVAL";
model.physio.movementCensoringThreshold = [3 Inf];

model.glm.highPassFilter = 128;
model.glm.serialCorrelations = "AR(1)";
model.glm.maskThreshold = 0.8;

model.assessment.tsnrReferenceContrast = 0;
model.assessment.tsnrContrastNames = ...
    ["Cardiac", "RespiratoryVolumePerTime"];

end
