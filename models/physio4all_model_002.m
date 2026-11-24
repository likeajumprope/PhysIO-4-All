function model = physio4all_model_002()
%PHYSIO4ALL_MODEL_002 Anatomical CompCor with five regressors per tissue.
%   Use separate WM and CSF masks and unsmoothed, realigned BOLD data.
%   PhysIO adds each tissue mean to the requested four PCA components.
%   See models/README.md for the methodological choices and CONN differences.

model = physio4all_model_001();
model.id = "model-002";
model.name = "PhysIO aCompCor (CONN Toolbox Style) with five WM and five CSF regressors";
model.description = "Anatomical noise-ROI PCA and movement regressors, " + ...
    "with RETROICOR, RVT, and HRV disabled.";
model.physio.method = "acompcor";
model.physio.includeRetroicor = false;
model.physio.includeRvt = false;
model.physio.includeHrv = false;
model.physio.noiseComponents = [4 4];
model.physio.noiseThresholds = [0.5 0.5];
model.physio.noiseVoxelCrop = [1 1];
model.assessment.tsnrContrastNames = "Noise Rois";

end
