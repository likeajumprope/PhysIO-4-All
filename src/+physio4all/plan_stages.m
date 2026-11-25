function plan = plan_stages(stages, overwriteFrom)
%PLAN_STAGES Resolve the requested endpoint and forced-recomputation boundary.
arguments
    stages {mustBeText}
    overwriteFrom {mustBeTextScalar} = "none"
end
order = ["preprocess", "compute_physio", "fit_glm", "assess_physio"];
stages = lower(string(stages));
if any(~ismember(stages, order))
    error("physio4all:InvalidStage", ...
        "Stages must be selected from: %s.", strjoin(order, ", "));
end
overwriteFrom = lower(string(overwriteFrom));
if overwriteFrom == "all"
    overwriteFrom = "preprocess";
end
if ~ismember(overwriteFrom, ["none", order])
    error("physio4all:InvalidOverwriteFrom", ...
        "OverwriteFrom must be none, all, preprocess, compute_physio, " + ...
        "fit_glm, or assess_physio.");
end
endpoint = find(ismember(order, stages), 1, "last");
plan.required = false(1, 4);
plan.overwrite = false(1, 4);
plan.overwriteFrom = overwriteFrom;
if ~isempty(endpoint)
    plan.required(1:endpoint) = true;
end
if overwriteFrom ~= "none"
    startIndex = find(order == overwriteFrom);
    if isempty(endpoint) || startIndex > endpoint
        error("physio4all:OverwriteOutsideStages", ...
            "OverwriteFrom is beyond the endpoint selected by Stages.");
    end
    plan.overwrite(startIndex:endpoint) = true;
end
end
