param(
    [switch]$ScanAll,
    [switch]$Quiet
)

$latestMatlabRelease = 'R2024b'

function Write-Header {
    param([string]$Title)
    Write-Host "==============================" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor DarkCyan
}

function Write-Status {
    param(
        [string]$Label,
        [string]$Emoji,
        [string]$Value,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )
    $padded = ($Label + ':').PadRight(22)
    Write-Host " $Emoji  $padded $Value" -ForegroundColor $Color
}

function Get-MatlabStatus {
    $matlabCmd = Get-Command matlab -ErrorAction SilentlyContinue
    if ($null -eq $matlabCmd) {
        return [PSCustomObject]@{
            Label = 'MATLAB'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
        }
    }

    return [PSCustomObject]@{
        Label = 'MATLAB'
        Emoji = '✅'
        Value = "Found (`$($matlabCmd.Source)`), latest known $latestMatlabRelease"
        Color = [ConsoleColor]::Green
    }
}

function Get-JavaStatus {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $javaCmd) {
        return [PSCustomObject]@{
            Label = 'Java JDK'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
        }
    }

    $versionLine = (java -version 2>&1 | Select-Object -First 1)
    if ($versionLine -match '"([0-9]+(?:\\.[0-9]+)*)"') {
        $version = $Matches[1]
    } else {
        $version = $versionLine
    }

    $emoji = '✅'
    $color = [ConsoleColor]::Green
    if ($version -lt '1.8') {
        $emoji = '⚠️'
        $color = [ConsoleColor]::Yellow
    }

    return [PSCustomObject]@{
        Label = 'Java JDK'
        Emoji = $emoji
        Value = "Detected ($version)"
        Color = $color
    }
}

function Get-DotNetStatus {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $dotnetCmd) {
        return [PSCustomObject]@{
            Label = '.NET Runtime'
            Emoji = '❌'
            Value = 'Not detected on PATH'
            Color = [ConsoleColor]::Red
        }
    }

    $version = (dotnet --version 2>&1 | Select-Object -First 1)
    return [PSCustomObject]@{
        Label = '.NET Runtime'
        Emoji = '✅'
        Value = "Detected ($version)"
        Color = [ConsoleColor]::Green
    }
}

function Get-CompilerStatus {
    $found = @()
    foreach ($name in 'cl','gcc','clang') {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            $found += $name
        }
    }

    if ($found.Count -eq 0) {
        return [PSCustomObject]@{
            Label = 'C/C++ Compiler'
            Emoji = '❌'
            Value = 'None detected (add MSVC, GCC, or Clang)'
            Color = [ConsoleColor]::Red
        }
    }

    return [PSCustomObject]@{
        Label = 'C/C++ Compiler'
        Emoji = '✅'
        Value = "Detected: $($found -join ', ')"
        Color = [ConsoleColor]::Green
    }
}

function Show-Checks {
    Write-Header 'MATLAB Requirement Checker (no MATLAB needed)'
    Write-Host "Press A then Enter to scan everything, or choose a specific check." -ForegroundColor White
    Write-Host "" 
    Write-Host "  [A] Scan all" -ForegroundColor Green
    Write-Host "  [1] MATLAB" -ForegroundColor Gray
    Write-Host "  [2] Java JDK" -ForegroundColor Gray
    Write-Host "  [3] .NET" -ForegroundColor Gray
    Write-Host "  [4] C/C++ compiler" -ForegroundColor Gray
    Write-Host "  [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host "Enter choice (default A)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = 'A' }

    switch ($choice.ToUpper()) {
        'A' { Run-AllChecks }
        '1' { Show-Result (Get-MatlabStatus) }
        '2' { Show-Result (Get-JavaStatus) }
        '3' { Show-Result (Get-DotNetStatus) }
        '4' { Show-Result (Get-CompilerStatus) }
        'Q' { return }
        Default {
            Write-Host "Unknown choice. Please try again." -ForegroundColor Yellow
            Show-Checks
        }
    }

    Write-Host ""
    Read-Host "Press Enter to return to the menu"
    Show-Checks
}

function Show-Result {
    param([PSCustomObject]$Status)
    Write-Host "" 
    Write-Status -Label $Status.Label -Emoji $Status.Emoji -Value $Status.Value -Color $Status.Color
}

function Run-AllChecks {
    Write-Host "" 
    Show-Result (Get-MatlabStatus)
    Show-Result (Get-JavaStatus)
    Show-Result (Get-DotNetStatus)
    Show-Result (Get-CompilerStatus)
}

if ($ScanAll) {
    Run-AllChecks
    if (-not $Quiet) {
        Write-Host "" 
        Write-Host "Done." -ForegroundColor Green
    }
    exit 0
}

Show-Checks
