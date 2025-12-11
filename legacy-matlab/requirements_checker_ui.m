function fig = requirements_checker_ui()
%REQUIREMENTS_CHECKER_UI Interactive dashboard for MATLAB requirement checks.
%   REQUIREMENTS_CHECKER_UI() opens a simple clickable UI that can run each
%   prerequisite check independently or scan everything at once. Each tile
%   shows an emoji status indicator and a "Scan" button for quick updates.
%
%   Buttons:
%     • Scan All: runs every check and updates the dashboard.
%     • Individual Scan buttons: refresh only the selected area by
%       re-running the full scan and extracting the relevant result.
%
%   To build a standalone executable (MATLAB Compiler required), run the
%   helper script BUILD_REQUIREMENTS_CHECKER_EXE.

    fig = uifigure('Name', 'MATLAB Requirements Checker', ...
        'Position', [100 100 640 520], ...
        'Color', [0.12 0.14 0.18]);

    grid = uigridlayout(fig, [6, 1]);
    grid.RowHeight = {60, 80, 80, 80, 80, '1x'};
    grid.Padding = [16 16 16 16];
    grid.RowSpacing = 12;

    header = uilabel(grid, 'Text', 'MATLAB Installation Requirements', ...
        'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    header.FontColor = [1 1 1];

    scanAllBtn = uibutton(grid, 'Text', 'Scan All (Emoji Report)', ...
        'ButtonPushedFcn', @(src, evt) scanAll());
    scanAllBtn.FontSize = 14;

    sections = {
        struct('key', 'matlab', 'title', 'MATLAB Release', ...
            'detail', 'Checks your installed release versus the latest known (R2024b).'), ...
        struct('key', 'java', 'title', 'Java JDK', ...
            'detail', 'Needed for MATLAB Compiler SDK Java packages (Java 8+).'), ...
        struct('key', 'dotnet', 'title', '.NET Runtime', ...
            'detail', 'Needed for MATLAB Compiler SDK .NET assemblies.'), ...
        struct('key', 'compiler', 'title', 'Supported Compiler', ...
            'detail', 'Required for Embedded/MATLAB/Simulink Coder and Compiler add-ins.') ...
    };

    rows = struct();
    for idx = 1:numel(sections)
        rows.(sections{idx}.key) = createRow(grid, sections{idx}.title, sections{idx}.detail, ...
            @(key) scanSingle(key), sections{idx}.key);
    end

    notesBox = uitextarea(grid, 'Editable', 'off');
    notesBox.Value = { ...
        'Fixed-Point Designer and SimBiology: compiler recommended.'; ...
        'Embedded/MATLAB/Simulink Coder: compiler required.'; ...
        'MATLAB Compiler: compiler required for Excel add-ins.'; ...
        'MATLAB Compiler SDK: .NET, compiler, Java JDK required.'; ...
        'C2000 Microcontroller Blockset: run Hardware Setup.'; ...
        'Documentation: online by default; install locally for offline use.' ...
    };
    notesBox.FontSize = 12;
    notesBox.BackgroundColor = [0.08 0.1 0.14];
    notesBox.FontColor = [0.9 0.9 0.9];
    notesBox.Layout.Row = 6;
    notesBox.Layout.Column = 1;

    scanAll();

    function scanAll()
        report = run_requirement_checks();
        updateRow(rows.matlab, formatMatlab(report.matlab));
        updateRow(rows.java, formatJava(report.java));
        updateRow(rows.dotnet, formatDotnet(report.dotnet));
        updateRow(rows.compiler, formatCompiler(report.compiler));
        notesBox.Value = cellstr(report.notes);
    end

    function scanSingle(key)
        report = run_requirement_checks();
        switch key
            case 'matlab'
                updateRow(rows.matlab, formatMatlab(report.matlab));
            case 'java'
                updateRow(rows.java, formatJava(report.java));
            case 'dotnet'
                updateRow(rows.dotnet, formatDotnet(report.dotnet));
            case 'compiler'
                updateRow(rows.compiler, formatCompiler(report.compiler));
        end
    end
end

function row = createRow(parent, titleText, detailText, cb, key)
    panel = uipanel(parent, 'BackgroundColor', [0.08 0.1 0.14]);
    panel.Layout.Column = 1;
    panel.Layout.Row = [];

    gl = uigridlayout(panel, [2 3]);
    gl.ColumnWidth = {60, '1x', 120};
    gl.RowHeight = {'fit', 'fit'};
    gl.RowSpacing = 4;
    gl.Padding = [12 8 12 8];

    emojiLabel = uilabel(gl, 'Text', '⚙️', 'FontSize', 32, 'HorizontalAlignment', 'center');
    emojiLabel.Layout.Row = [1 2];
    emojiLabel.Layout.Column = 1;
    emojiLabel.FontColor = [1 1 1];

    titleLabel = uilabel(gl, 'Text', titleText, 'FontSize', 15, 'FontWeight', 'bold');
    titleLabel.Layout.Row = 1;
    titleLabel.Layout.Column = 2;
    titleLabel.FontColor = [1 1 1];

    detailLabel = uilabel(gl, 'Text', detailText, 'FontSize', 12, 'WordWrap', 'on');
    detailLabel.Layout.Row = 2;
    detailLabel.Layout.Column = 2;
    detailLabel.FontColor = [0.8 0.8 0.8];

    valueLabel = uilabel(gl, 'Text', 'Click Scan to update', 'FontSize', 13, ...
        'HorizontalAlignment', 'right');
    valueLabel.Layout.Row = 1;
    valueLabel.Layout.Column = 3;
    valueLabel.FontColor = [0.9 0.9 0.9];

    btn = uibutton(gl, 'Text', 'Scan', 'FontSize', 12, ...
        'ButtonPushedFcn', @(src, evt) cb(key));
    btn.Layout.Row = 2;
    btn.Layout.Column = 3;

    row = struct('emoji', emojiLabel, 'value', valueLabel, 'panel', panel);
end

function updateRow(row, data)
    row.emoji.Text = data.emoji;
    row.value.Text = data.text;
    if data.pass
        row.emoji.FontColor = [0.5 1 0.5];
    else
        row.emoji.FontColor = [1 0.6 0.6];
    end
end

function out = formatMatlab(status)
    out.emoji = formatEmoji(status.upToDate);
    out.text = sprintf('Installed %s (latest known %s)', status.release, status.latestKnown);
    out.pass = status.upToDate;
end

function out = formatJava(status)
    out.emoji = formatEmoji(status.meetsMinimum);
    versionText = fallbackText(status.versionString, 'not detected');
    out.text = sprintf('Detected: %s (needs 8+)', versionText);
    out.pass = status.meetsMinimum;
end

function out = formatDotnet(status)
    out.emoji = formatEmoji(status.found);
    out.text = sprintf('Detected: %s', fallbackText(status.versionString, 'not detected'));
    out.pass = status.found;
end

function out = formatCompiler(status)
    out.emoji = formatEmoji(status.found);
    out.text = fallbackText(status.details, 'No supported compiler found');
    out.pass = status.found;
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
