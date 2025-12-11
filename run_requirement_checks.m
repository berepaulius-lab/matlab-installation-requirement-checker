function report = run_requirement_checks()
%RUN_REQUIREMENT_CHECKS Shared logic for MATLAB prerequisite checks.
%   REPORT = RUN_REQUIREMENT_CHECKS() returns a struct containing the
%   detected MATLAB release, Java JDK, .NET runtime, and supported compiler
%   status. The checks are lightweight and can be used by command-line
%   scripts or UI wrappers.
%
%   This function centralizes the requirement logic used by both the
%   command-line snapshot (QUICK_REQUIREMENTS_CHECK) and the UI experience
%   (REQUIREMENTS_CHECKER_UI).

    latestMatlabRelease = 'R2024b';
    minJavaMajor = 8; % MATLAB Compiler SDK requires a JDK (Java 8+)

    report = struct();
    report.matlab = checkMatlabVersion(latestMatlabRelease);
    report.java = checkJavaJDK(minJavaMajor);
    report.dotnet = checkDotnetRuntime();
    report.compiler = checkMexCompiler();
    report.hardwareSetup = struct('required', true, ...
        'note', 'C2000 Microcontroller Blockset requires Hardware Setup.');
    report.notes = [ ...
        "Fixed-Point Designer and SimBiology: compiler recommended."; ...
        "Embedded/MATLAB/Simulink Coder: compiler required."; ...
        "MATLAB Compiler: compiler required for Excel add-ins."; ...
        "MATLAB Compiler SDK: .NET, compiler, Java JDK required."; ...
        "C2000 Microcontroller Blockset: run Hardware Setup."; ...
        "Documentation: online by default; install locally for offline use." ...
    ];
end

function status = checkMatlabVersion(latestRelease)
    installedRelease = version('-release');
    installedNumeric = matlabVersionToNumber(installedRelease);
    latestNumeric = matlabReleaseToNumber(latestRelease);

    status = struct();
    status.release = installedRelease;
    status.numeric = installedNumeric;
    status.latestKnown = latestRelease;
    status.upToDate = installedNumeric >= latestNumeric;
end

function status = checkJavaJDK(minMajor)
    status = struct('found', false, 'versionString', '', 'meetsMinimum', false);
    candidates = {
        'javac -version', ...
        'java -version'
    };

    for idx = 1:numel(candidates)
        [ok, output] = runCommand(candidates{idx});
        if ok
            status.found = true;
            status.versionString = extractFirstVersion(output);
            break;
        end
    end

    status.meetsMinimum = status.found && parseMajor(status.versionString) >= minMajor;
end

function status = checkDotnetRuntime()
    status = struct('found', false, 'versionString', '');
    [ok, output] = runCommand('dotnet --list-runtimes');
    if ~ok
        [ok, output] = runCommand('dotnet --info');
    end

    status.found = ok;
    status.versionString = extractFirstVersion(output);
end

function status = checkMexCompiler()
    status = struct('found', false, 'details', '');
    try
        configs = mex.getCompilerConfigurations('C', 'Installed');
        status.found = ~isempty(configs);
        if status.found
            names = arrayfun(@(c) c.Name, configs, 'UniformOutput', false);
            status.details = strjoin(names, ', ');
        end
    catch ME
        status.details = sprintf('Check failed: %s', ME.message);
    end
end

function num = matlabVersionToNumber(releaseStr)
    tokens = regexp(releaseStr, 'R(\d{4})([ab])', 'tokens', 'once');
    if isempty(tokens)
        num = 0;
        return;
    end
    year = str2double(tokens{1});
    half = tokens{2};
    num = year + (half == 'b') * 0.5;
end

function num = matlabReleaseToNumber(releaseStr)
    num = matlabVersionToNumber(releaseStr);
end

function [ok, output] = runCommand(cmd)
    [statusCode, output] = system(cmd);
    ok = statusCode == 0 && ~isempty(strtrim(output));
    output = strtrim(output);
end

function versionStr = extractFirstVersion(text)
    match = regexp(text, '(\d+[\.\_]?\d*(?:\.\d+)*)', 'match', 'once');
    if isempty(match)
        versionStr = '';
    else
        versionStr = match;
    end
end

function major = parseMajor(versionStr)
    if isempty(versionStr)
        major = 0;
        return;
    end
    numbers = regexp(versionStr, '\d+', 'match');
    if isempty(numbers)
        major = 0;
    else
        major = str2double(numbers{1});
    end
end
