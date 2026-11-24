function model = physio4all_model_003()
%PHYSIO4ALL_MODEL_003 PhysIO aCompCor with a 50% variance target per tissue.
%   This adopts fMRIPrep's variance-based component selection, using PhysIO
%   throughout. PhysIO additionally includes each tissue's mean time series.
%   It is not an exact reproduction of fMRIPrep preprocessing or PCA.

model = physio4all_model_002();
model.id = "model-003";
model.name = "PhysIO aCompCor (fMRIPrep Style) with 50% variance per WM/CSF tissue";
model.description = "Separate WM/CSF PCA with a 50% variance target " + ...
    "and tissue means, plus movement; RETROICOR, HRV, and RVT disabled.";
% Values below one specify the fraction of cumulative PCA variance.
% PhysIO selects enough components to strictly exceed this fraction.
model.physio.noiseComponents = [0.5 0.5];

end
