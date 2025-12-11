function build_requirements_checker_exe(outputDir)
%BUILD_REQUIREMENTS_CHECKER_EXE Package the UI as a standalone executable.
%   BUILD_REQUIREMENTS_CHECKER_EXE(OUTPUTDIR) uses MATLAB Compiler (mcc) to
%   generate an executable for REQUIREMENTS_CHECKER_UI. If OUTPUTDIR is not
%   provided, the current folder is used. MATLAB Compiler must be installed.
%
%   Example:
%     build_requirements_checker_exe(fullfile(pwd, 'dist'))

    if nargin < 1 || isempty(outputDir)
        outputDir = pwd;
    end

    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    fprintf('Building executable into %s ...\n', outputDir);
    mcc('-m', 'requirements_checker_ui.m', ...
        '-o', 'requirements_checker', ...
        '-d', outputDir);
    fprintf('Done. Launch \'requirements_checker\' from %s (MATLAB Runtime required).\n', outputDir);
end
