function model = physio4all_model_006()
%PHYSIO4ALL_MODEL_006 RETROICOR, HRV, and movement, without RVT.

model = physio4all_model_001();
model.id = "model-006";
model.name = "RETROICOR + HRV with 3 mm smoothing";
model.description = "RETROICOR, HRV, and movement regressors; RVT disabled.";
model.physio.includeRvt = false;
model.assessment.tsnrContrastNames = ...
    ["Cardiac", "Respiratory", "HeartRateVariability"];

end
