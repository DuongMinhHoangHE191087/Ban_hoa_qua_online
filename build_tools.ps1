param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$scriptRoot = $PSScriptRoot
$targetScript = Join-Path $scriptRoot "build-tools.ps1"

if (-not (Test-Path $targetScript)) {
    throw "Missing delegated script: $targetScript"
}

Push-Location $scriptRoot
try {
    & $targetScript @Arguments
}
finally {
    Pop-Location
}
