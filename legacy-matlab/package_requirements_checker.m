function outputZip = package_requirements_checker(exeDir, outputZip)
%PACKAGE_REQUIREMENTS_CHECKER Create a shareable zip bundle.
%   PACKAGE_REQUIREMENTS_CHECKER(EXEDIR, OUTPUTZIP) collects the built
%   executable (from EXEDIR) plus friendly start files into OUTPUTZIP so
%   end users can download, unzip, and run. If EXEDIR is missing, source
%   files are bundled so MATLAB users can still launch the UI.
%
%   Example:
%     package_requirements_checker('dist', fullfile(pwd, 'requirements-checker-bundle.zip'))

    if nargin < 1 || isempty(exeDir)
        exeDir = fullfile(pwd, 'dist');
    end

    if nargin < 2 || isempty(outputZip)
        outputZip = fullfile(pwd, 'requirements-checker-bundle.zip');
    end

    stagingDir = fullfile(tempdir, 'requirements_checker_bundle');
    if isfolder(stagingDir)
        rmdir(stagingDir, 's');
    end
    mkdir(stagingDir);

    % Always include friendly docs and source entry points.
    copyIfExists('START_HERE.txt', stagingDir);
    copyIfExists('README.md', stagingDir);

    sourceFiles = {
        'launch_requirements_checker.m', ...
        'requirements_checker_ui.m', ...
        'quick_requirements_check.m', ...
        'run_requirement_checks.m', ...
        'build_requirements_checker_exe.m', ...
        'main.m'
    };

    srcDest = fullfile(stagingDir, 'source');
    mkdir(srcDest);
    for i = 1:numel(sourceFiles)
        copyIfExists(sourceFiles{i}, srcDest);
    end

    % Include the compiled app if present.
    if isfolder(exeDir)
        copyfile(exeDir, fullfile(stagingDir, 'dist'));
    else
        warning('Executable folder not found: %s. Only MATLAB source files included.', exeDir);
    end

    % Create the zip archive.
    if isfile(outputZip)
        delete(outputZip);
    end
    filesToZip = dir(stagingDir);
    names = {filesToZip(~ismember({filesToZip.name}, {'.', '..'})).name};
    zip(outputZip, names, stagingDir);

    fprintf('Packaged bundle created: %s\n', outputZip);
    fprintf('Contents are staged in %s (safe to delete).\n', stagingDir);
end

function copyIfExists(name, destDir)
    if isfile(name)
        copyfile(name, destDir);
    elseif isfolder(name)
        copyfile(name, destDir);
    else
        warning('Missing file or folder: %s (skipped)', name);
    end
end
