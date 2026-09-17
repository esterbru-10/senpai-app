param(
    [string]$MatlabPath = "",
    [ValidateSet("web", "installer", "none")]
    [string]$RuntimeDelivery = "web"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($MatlabPath)) {
    $candidates = @(
        "C:\Program Files\MATLAB\R2025b\bin\matlab.exe",
        "C:\MATLAB\R2025b-SENPAI\bin\matlab.exe"
    )
    $MatlabPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $MatlabPath)) {
    throw "MATLAB R2025b with MATLAB Compiler was not found: $MatlabPath"
}

$projectDir = $PSScriptRoot.Replace("'", "''")
$batchCommand = "cd('$projectDir'); buildSenpaiStandalone(Package=true,RuntimeDelivery=`"$RuntimeDelivery`")"

& $MatlabPath -batch $batchCommand
if ($LASTEXITCODE -ne 0) {
    throw "SENPAI Windows build failed with exit code $LASTEXITCODE"
}
