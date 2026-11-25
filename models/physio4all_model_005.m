function model = physio4all_model_005()
%PHYSIO4ALL_MODEL_005 RETROICOR, RVT, and movement, without HRV.

model = physio4all_model_001();
model.id = "model-005";
model.name = "RETROICOR + RVT with 3 mm smoothing";
model.description = "RETROICOR, RVT, and movement regressors; HRV disabled.";
model.physio.includeHrv = false;
model.assessment.tsnrContrastNames = ...
    ["Cardiac", "Respiratory", "RespiratoryVolumePerTime"];

end
