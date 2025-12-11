% main.m - MATLAB Installation Requirement Checker
%
% Usage:
%   main                 - run checks with default requirements
%   main(requirements)   - run checks using a struct with fields:
%                           .minMatlabVersion (string, e.g. '9.8')
%                           .requiredToolboxes (cell array of toolbox names)
%                           .requireMEX (logical)
%                           .requireSimulink (logical)
%
% Outputs a summary to the console and writes requirements_report.json to
% the current folder.

function summary = main(requirements)
    if nargin < 1 || isempty(requirements)
        requirements = struct();
        % Default minimum MATLAB version (as numeric release, e.g. 9.8 for R2020a)
        requirements.minMatlabVersion = '9.8'; % set to R2020a by default
        % Default list of required toolboxes (customize as needed)
        requirements.requiredToolboxes = { ...
            'Signal Processing Toolbox', ...
            'Image Processing Toolbox', ...
            'Statistics and Machine Learning Toolbox' ...
        };
        requirements.requireMEX = false;
        requirements.requireSimulink = false;
    end

    fprintf('MATLAB Installation Requirement Checker\n');
    fprintf('====================================\n');

    % MATLAB version check
    currentVerStr = version('-release');
    currentVerNum = matlabVersionToNumber(currentVerStr);
    minVerNum = str2double(requirements.minMatlabVersion);

    matlabOk = currentVerNum >= minVerNum;
    fprintf('MATLAB release: %s (numeric: %.2f)\n', currentVerStr, currentVerNum);
    fprintf('Required minimum numeric version: %.2f\n', minVerNum);
    fprintf('MATLAB version requirement: %s\n', tfToPassFail(matlabOk));

    % Toolboxes
    installedToolboxes = getInstalledToolboxNames();
    toolboxResults = struct();
    for i = 1:numel(requirements.requiredToolboxes)
        name = requirements.requiredToolboxes{i};
        installed = ismember(name, installedToolboxes);
        toolboxResults.(matlab.lang.makeValidName(name)) = installed;
        fprintf('Toolbox: %-35s : %s\n', name, tfToPassFail(installed));
    end

    % MEX compiler check
    mexOk = true;
    if isfield(requirements, 'requireMEX') && requirements.requireMEX
        try
            % mex -setup -check is not always available; use mex.getCompilerConfigurations
            configs = mex.getCompilerConfigurations('C', 'Installed');
            mexOk = ~isempty(configs);
        catch
            % older MATLAB variations: try calling mex with -setup flag
            try
                out = evalc('mex -setup');
                mexOk = ~isempty(out) && ~contains(out, 'No supported compilers');
            catch
                mexOk = false;
            end
        end
        fprintf('MEX compiler available: %s\n', tfToPassFail(mexOk));
    end

    % Simulink check
    simulinkOk = true;
    if isfield(requirements, 'requireSimulink') && requirements.requireSimulink
        simulinkOk = ismember('Simulink', installedToolboxes);
        fprintf('Simulink installed: %s\n', tfToPassFail(simulinkOk));
    end

    % Java version
    try
        javaVer = version('-java');
    catch
        javaVer = 'unknown';
    end
    fprintf('Java runtime: %s\n', javaVer);

    % Build summary struct
    summary = struct();
    summary.timestamp = datetime('now');
    summary.matlab = struct('release', currentVerStr, 'numeric', currentVerNum, 'ok', matlabOk);
    summary.requiredToolboxes = requirements.requiredToolboxes;
    summary.installedToolboxes = installedToolboxes;
    summary.toolboxResults = toolboxResults;
    summary.requireMEX = requirements.requireMEX;
    summary.mexOk = mexOk;
    summary.requireSimulink = requirements.requireSimulink;
    summary.simulinkOk = simulinkOk;
    summary.java = javaVer;

    % Write report JSON (MATLAB 2016b+ has jsonencode)
    try
        json = jsonencode(summary);
        fid = fopen('requirements_report.json', 'w');
        if fid ~= -1
            fwrite(fid, json, 'char');
            fclose(fid);
            fprintf('Wrote requirements_report.json to %s\n', pwd);
        else
            warning('Could not write requirements_report.json');
        end
    catch ME
        warning('Could not produce JSON report: %s', ME.message);
    end

    % Final overall result
    overallOk = matlabOk && all(struct2array(toolboxResults));
    if isfield(summary, 'mexOk') && requirements.requireMEX
        overallOk = overallOk && summary.mexOk;
    end
    if isfield(summary, 'simulinkOk') && requirements.requireSimulink
        overallOk = overallOk && summary.simulinkOk;
    end

    fprintf('\nOverall requirements status: %s\n', tfToPassFail(overallOk));

    if nargout == 0
        clear summary;
    end
end

%% Helper functions
function num = matlabVersionToNumber(releaseStr)
    % Convert release like 'R2020a' to numeric approximate (9.8)
    % This mapping covers common releases but falls back to version function
    try
        verStr = version; % e.g. '9.8.0.1323502 (R2020a)'
        tokens = regexp(verStr, '^(\d+\.\d+)', 'tokens');
        if ~isempty(tokens)
            num = str2double(tokens{1}{1});
            return;
        end
    catch
        % fall through
    end
    % As a fallback, try extracting digits from releaseStr
    nums = regexp(releaseStr, '\d+', 'match');
    if ~isempty(nums)
        major = str2double(nums{1});
        % crude mapping: R2019b -> 9.7, R2020a -> 9.8, R2020b -> 9.9
        % attempt to compute from year
        if major >= 2014
            num = 8 + (major - 2014) * 0.1; % approximate for many releases
        else
            num = 7.0;
        end
    else
        num = 0;
    end
end

function names = getInstalledToolboxNames()
    v = ver;
    names = cell(1, numel(v));
    for k = 1:numel(v)
        names{k} = v(k).Name;
    end
end

function s = tfToPassFail(tf)
    if isequal(tf, true) || (isnumeric(tf) && tf ~= 0)
        s = 'PASS';
    else
        s = 'FAIL';
    end
end
