function source = select_anatomy_source(runInfo, preprocessing)
%SELECT_ANATOMY_SOURCE Choose the subject T1w or the unsmoothed run mean.
arguments
    runInfo (1,1) struct
    preprocessing (1,1) struct
end
source = preprocessing.meanBoldFile;
if isfield(runInfo, "anatomicalFile") && strlength(runInfo.anatomicalFile) > 0
    source = runInfo.anatomicalFile;
end
end
