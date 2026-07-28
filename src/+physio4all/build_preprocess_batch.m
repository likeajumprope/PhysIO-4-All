function matlabbatch = build_preprocess_batch(runInfo, workingBoldFile, example)
%BUILD_PREPROCESS_BATCH Build the SPM realignment batch.

arguments
    runInfo (1,1) struct
    workingBoldFile {mustBeTextScalar}
    example (1,1) struct
end

scans = volumeList(string(workingBoldFile), runInfo.nVolumes);
settings = example.preprocessing;

matlabbatch{1}.spm.spatial.realign.estwrite.data = {cellstr(scans)};
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = ...
    settings.realignQuality;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = ...
    settings.realignSeparation;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = ...
    settings.realignFwhm;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = ...
    settings.registerToMean;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = ...
    settings.interpolation;
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = "";
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = ...
    settings.interpolation;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = true;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = "r";

end

function scans = volumeList(filePath, nVolumes)
scans = arrayfun(@(iVolume) sprintf("%s,%d", filePath, iVolume), ...
    (1:nVolumes)', UniformOutput=false);
scans = string(scans);
end
