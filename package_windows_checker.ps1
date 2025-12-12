param(
    [string]$Output = 'requirements-checker-windows.zip'
)

$items = @(
    'run_checker.cmd',
    'checker.js',
    'checker.exe',
    'build_exe.cmd',
    'package.json',
    'README.md',
    'logs',
    'runtime'
) | Where-Object { Test-Path $_ }

if ($items.Count -eq 0) {
    Write-Error 'Nothing to package. Ensure the script files exist in the current folder.'
    exit 1
}

if (Test-Path $Output) {
    Remove-Item $Output -Force
}

Compress-Archive -Path $items -DestinationPath $Output
Write-Host "Created $Output with: $($items -join ', ')" -ForegroundColor Green
