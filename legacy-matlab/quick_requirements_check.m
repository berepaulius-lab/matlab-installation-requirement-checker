function report = quick_requirements_check()
%QUICK_REQUIREMENTS_CHECK Instant snapshot of MATLAB-related prerequisites.
%   REPORT = QUICK_REQUIREMENTS_CHECK() scans for MATLAB, Java, .NET,
%   compilers, and hardware setup needs, printing an emoji-driven summary
%   suitable for a quick command-line check.
%
%   The function returns a struct REPORT with detected versions and booleans
%   indicating whether minimum expectations were met.

    fprintf('MATLAB Quick Requirement Snapshot\n');
    fprintf('===================================\n');

    report = run_requirement_checks();

    describeMatlab(report.matlab);
    describeJava(report.java);
    describeDotnet(report.dotnet);
    describeCompiler(report.compiler);

    fprintf('\nRequirement highlights (from MATLAB products):\n');
    for idx = 1:numel(report.notes)
        fprintf('  • %s\n', report.notes(idx));
    end

    if nargout == 0
        clear report;
    end
end

function describeMatlab(status)
    fprintf('\nMATLAB release      : %s %s\n', ...
        formatEmoji(status.upToDate), status.release);
    fprintf('Latest known release: %s\n', status.latestKnown);
end

function describeJava(status)
    fprintf('Java JDK            : %s %s\n', ...
        formatEmoji(status.meetsMinimum), fallbackText(status.versionString, 'not detected'));
    fprintf('  - Minimum expected: Java 8 for MATLAB Compiler SDK Java packages.\n');
end

function describeDotnet(status)
    fprintf('.NET runtime        : %s %s\n', ...
        formatEmoji(status.found), fallbackText(status.versionString, 'not detected'));
    fprintf('  - Needed for: MATLAB Compiler SDK .NET assemblies and Excel integration.\n');
end

function describeCompiler(status)
    fprintf('Supported compiler  : %s %s\n', ...
        formatEmoji(status.found), fallbackText(status.details, 'not found'));
    fprintf('  - Required for: Embedded/MATLAB/Simulink Coder; MATLAB Compiler add-ins.\n');
    fprintf('  - Recommended for: Fixed-Point Designer, SimBiology acceleration.\n');
end

function textOut = fallbackText(value, fallback)
    if isempty(value)
        textOut = fallback;
    else
        textOut = value;
    end
end

function emoji = formatEmoji(passed)
    if isequal(passed, true)
        emoji = '✅';
    elseif isequal(passed, false)
        emoji = '❌';
    else
        emoji = '⚠️';
    end
end
