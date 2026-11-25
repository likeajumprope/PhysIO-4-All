function model = physio4all_model_004()
%PHYSIO4ALL_MODEL_004 RETROICOR and movement, without HRV or RVT.

model = physio4all_model_001();
model.id = "model-004";
model.name = "RETROICOR with 3 mm smoothing";
model.description = "RETROICOR and movement regressors; HRV and RVT disabled.";
model.physio.includeRvt = false;
model.physio.includeHrv = false;
model.assessment.tsnrContrastNames = ["Cardiac", "Respiratory"];

end
