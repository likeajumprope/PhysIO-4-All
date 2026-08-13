classdef physio4allPipelineTest < matlab.unittest.TestCase
    %PHYSIO4ALLPIPELINETEST Tests for the public PhysIO-4-All interfaces.

    properties (SetAccess = private)
        RepoRoot
    end

    methods (TestClassSetup)
        function addRepositoryPaths(testCase)
            testCase.RepoRoot = fileparts(fileparts(mfilename("fullpath")));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.RepoRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.RepoRoot, "src")));
        end
    end

    methods (Test)
        function testSetupAddsNamespaceParentOnly(testCase)
            physio4all_setup();
            pathEntries = string(strsplit(path, pathsep));
            sourceFolder = string(fullfile(testCase.RepoRoot, "src"));
            namespaceFolder = fullfile(sourceFolder, "+physio4all");

            testCase.verifyTrue(any(pathEntries == sourceFolder));
            testCase.verifyFalse(any(pathEntries == namespaceFolder));
            testCase.verifyEqual(which("physio4all.run"), ...
                char(fullfile(namespaceFolder, "run.m")));
            testCase.verifyEqual(which("tapas_physio_new"), ...
                char(fullfile(testCase.RepoRoot, "external", "PhysIO", ...
                "tapas_physio_new.m")));
        end

        function testResolveFilesReadsMetadata(testCase)
            fixture = testCase.createDatasetFixture();
            example = physio4all.get_example("brainhack23");
            example.physio = rmfield(example.physio, "nSlices");

            runInfo = physio4all.resolve_files( ...
                example, "sub-46", 1, fixture.DataRoot);

            testCase.verifyEqual(runInfo.nVolumes, 3);
            testCase.verifyEqual(runInfo.repetitionTime, 1.25, AbsTol=1e-12);
            testCase.verifyEqual(runInfo.nSlices, 4);
            testCase.verifyEqual(runInfo.nSliceEvents, 2);
            testCase.verifyEqual(runInfo.onsetSlice, 2);
            testCase.verifyEqual(runInfo.physioNSlices, 2);
            testCase.verifyEqual(runInfo.physioOnsetSlice, 1);
            testCase.verifyEqual(runInfo.multibandFactor, 2);
        end

        function testBrainhackExampleUsesPhysioSliceWorkaround(testCase)
            fixture = testCase.createDatasetFixture();
            example = physio4all.get_example("brainhack23");

            runInfo = physio4all.resolve_files( ...
                example, "sub-46", 1, fixture.DataRoot);

            testCase.verifyEqual(example.physio.nSlices, 28);
            testCase.verifyEqual(runInfo.physioNSlices, 28);
            testCase.verifyEqual(runInfo.physioOnsetSlice, 14);
        end

        function testOpenNeuroDs004645ExampleConfiguration(testCase)
            example = physio4all.get_example("fastfmri");

            testCase.verifyEqual(example.id, ...
                "openneuro_ds004645_fastfmri");
            testCase.verifyEqual(example.source, "OpenNeuro");
            testCase.verifyEqual(example.accession, "ds004645");
            testCase.verifyEqual(example.aliases, "fastfmri");
            testCase.verifyEqual(example.defaultSubject, "sub-01");
            testCase.verifyEqual(example.availableRuns, 1:2);
            testCase.verifyEqual(example.dataRelativePath, ...
                string(fullfile("openneuro", "ds004645")));
            testCase.verifyEqual(example.files.physioFolder, "func");
            testCase.verifyEqual(example.physio.vendor, "BIDS");
            testCase.verifyEqual(example.physio.multibandFactor, 3);
        end

        function testDatasetMnemonicsResolveToCanonicalIDs(testCase)
            testCase.verifyEqual( ...
                physio4all_resolve_example_id("fastfmri"), ...
                "openneuro_ds004645_fastfmri");
            testCase.verifyEqual( ...
                physio4all_resolve_example_id("brainhack23"), ...
                "openneuro_ds004808_brainhack23");
        end

        function testBatchBuildersReturnExpectedModules(testCase)
            fixture = testCase.createDatasetFixture();
            example = physio4all.get_example("brainhack23");
            model = physio4all.get_model(example, example.defaultModel);
            example = physio4all.configure_model(example, model);
            runInfo = physio4all.resolve_files( ...
                example, "sub-46", 1, fixture.DataRoot);
            preprocessing = struct( ...
                motionFile=fullfile(fixture.Root, "rp_bold.txt"), ...
                glmBoldFile=runInfo.boldFile);
            physioOutputs = struct( ...
                regressorsFile=fullfile(fixture.Root, ...
                "multiple_regressors.txt"));

            preprocessingBatch = physio4all.build_preprocess_batch( ...
                runInfo, runInfo.boldFile, example);
            physioBatch = physio4all.build_physio_batch( ...
                runInfo, preprocessing, example, fixture.Root);
            glmBatch = physio4all.build_glm_batch( ...
                runInfo, preprocessing, physioOutputs, example, fixture.Root);

            testCase.verifyTrue(isfield(preprocessingBatch{1}.spm.spatial, ...
                "realign"));
            testCase.verifyTrue(iscellstr( ...
                preprocessingBatch{1}.spm.spatial.realign.estwrite.data{1}));
            testCase.verifyClass( ...
                preprocessingBatch{1}.spm.spatial.realign.estwrite. ...
                roptions.prefix, "char");
            testCase.verifyEqual( ...
                preprocessingBatch{1}.spm.spatial.realign.estwrite. ...
                eoptions.weight, {''});
            testCase.verifyTrue(isfield(physioBatch{1}.spm.tools, "physio"));
            testCase.verifyTrue(isfield(glmBatch{1}.spm.stats, "fmri_spec"));
            testCase.verifyTrue(iscellstr( ...
                glmBatch{1}.spm.stats.fmri_spec.sess.scans));
            testCase.verifyEqual( ...
                glmBatch{1}.spm.stats.fmri_spec.timing.fmri_t, 4);
            testCase.verifyEqual( ...
                glmBatch{1}.spm.stats.fmri_spec.timing.fmri_t0, 2);
            testCase.verifyEqual( ...
                physioBatch{1}.spm.tools.physio.scan_timing.sqpar.Nslices, 28);
            testCase.verifyEqual( ...
                physioBatch{1}.spm.tools.physio.scan_timing.sqpar.onset_slice, 14);
        end

        function testPreprocessingPromotesAndReusesCheckpoint(testCase)
            fixture = testCase.createDatasetFixture();
            example = physio4all.get_example("brainhack23");
            runInfo = physio4all.resolve_files( ...
                example, "sub-46", 1, fixture.DataRoot);
            workFolder = fullfile(fixture.Root, "work");
            derivativeFolder = fullfile(fixture.Root, "derivatives", "preproc");
            testCase.createCompletedRealignment( ...
                runInfo, workFolder);

            firstOutputs = physio4all.preprocess( ...
                runInfo, example, workFolder, derivativeFolder, ...
                SmoothingFwhm=[0 0 0]);
            rmdir(workFolder, "s");
            reusedOutputs = physio4all.preprocess( ...
                runInfo, example, workFolder, derivativeFolder, ...
                SmoothingFwhm=[0 0 0]);
            checkpoint = jsondecode(fileread(firstOutputs.checkpointFile));
            [~, checkpointName, checkpointExtension] = ...
                fileparts(firstOutputs.checkpointFile);

            testCase.verifyTrue(isfile(firstOutputs.realignedBoldFile));
            testCase.verifyTrue(isfile(firstOutputs.motionFile));
            testCase.verifyTrue(isfile(firstOutputs.meanBoldFile));
            testCase.verifyTrue(isfile(firstOutputs.checkpointFile));
            testCase.verifyEqual(checkpointName, "preprocessing_checkpoint");
            testCase.verifyEqual(checkpointExtension, ".json");
            testCase.verifyEqual(string(checkpoint.stage), "preprocess");
            testCase.verifyEqual(checkpoint.smoothingFwhm(:)', [0 0 0]);
            testCase.verifyEqual(checkpoint.runInfo.nVolumes, 3);
            testCase.verifyEqual( ...
                reusedOutputs.glmBoldFile, firstOutputs.glmBoldFile);
        end

        function testInvalidStageIsRejected(testCase)
            testCase.verifyError(@() physio4all_run( ...
                "brainhack23", Stages="invalid"), ...
                "physio4all:InvalidStage");
        end

        function testModelConfigurationLoadsByID(testCase)
            example = physio4all.get_example("brainhack23");

            model = physio4all.get_model(example, "model-001");

            testCase.verifyEqual(model.id, "model-001");
            testCase.verifyEqual( ...
                model.preprocessing.smoothingFwhm, [3 3 3]);
            testCase.verifyEqual(model.glm.highPassFilter, 128);
        end

        function testInvalidModelIDIsRejected(testCase)
            example = physio4all.get_example("brainhack23");

            testCase.verifyError( ...
                @() physio4all.get_model(example, "smooth-3mm"), ...
                "physio4all:InvalidModelID");
        end

        function testLogFileIsModelSpecific(testCase)
            derivativesRunFolder = fullfile( ...
                "derivatives", "example-001", "sub-01", "run-02");

            logFile = physio4all.get_log_file( ...
                derivativesRunFolder, "sub-01", 2, "model-003");

            expected = fullfile(derivativesRunFolder, "logs", ...
                "model-003", ...
                "sub-01_run-02_model-003_pipeline.log");
            testCase.verifyEqual(logFile, expected);
        end

        function testAutomaticDiaryInitializesBeforeDataResolution(testCase)
            fixtureRoot = string(tempname);
            mkdir(fixtureRoot);
            testCase.addTeardown(@() rmdir(fixtureRoot, "s"));

            testCase.verifyError(@() physio4all_run( ...
                "brainhack23", ...
                DataRoot=fullfile(fixtureRoot, "missing-data"), ...
                DerivativesRoot=fullfile(fixtureRoot, "derivatives"), ...
                EnableDiary=true, Verbose=false), ...
                "physio4all:MissingFile");
        end
    end

    methods (Access = private)
        function fixture = createDatasetFixture(testCase)
            fixture.Root = string(tempname);
            fixture.DataRoot = fullfile(fixture.Root, "data");
            subjectRoot = fullfile(fixture.DataRoot, ...
                "openneuro", "ds004808", "sub-46");
            funcFolder = fullfile(subjectRoot, "func");
            physioFolder = fullfile(subjectRoot, "physio");
            mkdir(funcFolder);
            mkdir(physioFolder);
            testCase.addTeardown(@() rmdir(fixture.Root, "s"));

            boldBase = "sub-46_task-NAconf_run-01_bold";
            niftiwrite(zeros(2, 2, 4, 3, "single"), ...
                fullfile(funcFolder, boldBase + ".nii"));
            metadata = struct( ...
                RepetitionTime=1.25, ...
                SliceTiming=[0 0.5 0 0.5], ...
                MultibandAccelerationFactor=2, ...
                TaskName="NAconf");
            writelines(jsonencode(metadata), ...
                fullfile(funcFolder, boldBase + ".json"));
            writelines("test", fullfile(physioFolder, ...
                "Physio_fixture_sess1_PULS.log"));
            writelines("test", fullfile(physioFolder, ...
                "Physio_fixture_sess1_RESP.log"));
            writelines("test", fullfile(physioFolder, ...
                "Physio_fixture_sess1_Info.log"));
        end

        function createCompletedRealignment(~, runInfo, workFolder)
            mkdir(workFolder);
            [~, boldName, boldExtension] = fileparts(runInfo.boldFile);
            workingBoldFile = fullfile( ...
                workFolder, boldName + boldExtension);
            realignedBoldFile = fullfile( ...
                workFolder, "r" + boldName + boldExtension);
            meanBoldFile = fullfile( ...
                workFolder, "mean" + boldName + boldExtension);
            workingJsonFile = fullfile(workFolder, boldName + ".json");
            motionFile = fullfile(workFolder, "rp_" + boldName + ".txt");

            copyfile(runInfo.boldFile, workingBoldFile);
            copyfile(runInfo.boldFile, realignedBoldFile);
            copyfile(runInfo.boldFile, meanBoldFile);
            copyfile(runInfo.boldJsonFile, workingJsonFile);
            writematrix(zeros(runInfo.nVolumes, 6), motionFile);
        end
    end
end
