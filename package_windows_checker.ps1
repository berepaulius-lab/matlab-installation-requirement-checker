param(
    [string]$Output = 'requirements-checker-windows.zip'
)

$items = @(
    'requirements_checker.ps1',
    'requirements_checker.cmd',
    'requirements_dashboard.ps1',
    'start_dashboard.cmd',
    'README.md',
    'START_HERE.txt'
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
