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
        end

        function testExampleAliasesResolveToCanonicalID(testCase)
            canonical = physio4all.get_example("brainhack23_ds004808");
            legacy = physio4all.get_example("brainhack_physio_ds004808");

            testCase.verifyEqual(canonical.id, "brainhack23_ds004808");
            testCase.verifyEqual(legacy.id, canonical.id);
        end

        function testResolveFilesReadsMetadata(testCase)
            fixture = testCase.createDatasetFixture();
            example = physio4all.get_example("brainhack23_ds004808");

            runInfo = physio4all.resolve_files( ...
                example, "sub-46", 1, fixture.DataRoot);

            testCase.verifyEqual(runInfo.nVolumes, 3);
            testCase.verifyEqual(runInfo.repetitionTime, 1.25, AbsTol=1e-12);
            testCase.verifyEqual(runInfo.nSlices, 4);
            testCase.verifyEqual(runInfo.nSliceEvents, 2);
            testCase.verifyEqual(runInfo.multibandFactor, 2);
        end

        function testBatchBuildersReturnExpectedModules(testCase)
            fixture = testCase.createDatasetFixture();
            example = physio4all.get_example("brainhack23_ds004808");
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
            testCase.verifyTrue(isfield(physioBatch{1}.spm.tools, "physio"));
            testCase.verifyTrue(isfield(glmBatch{1}.spm.stats, "fmri_spec"));
        end

        function testInvalidStageIsRejected(testCase)
            testCase.verifyError(@() physio4all_run( ...
                "brainhack23_ds004808", Stages="invalid"), ...
                "physio4all:InvalidStage");
        end
    end

    methods (Access = private)
        function fixture = createDatasetFixture(testCase)
            fixture.Root = string(tempname);
            fixture.DataRoot = fullfile(fixture.Root, "data");
            subjectRoot = fullfile(fixture.DataRoot, ...
                "brainhack_physio", "ds004808", "sub-46");
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
    end
end
