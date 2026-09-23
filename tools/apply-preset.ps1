param(
  [Parameter(Mandatory=$true)]
  [string]$Preset,

  [Parameter(Mandatory=$true)]
  [string]$ToolboxRoot
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $Preset)) {
  throw "Preset not found: $Preset"
}

$target = Join-Path $ToolboxRoot "Toolbox\apps\mmi-mirror\config.local"
$targetDir = Split-Path $target -Parent

if (!(Test-Path $targetDir)) {
  throw "MMI Mirror target directory not found: $targetDir"
}

if (Test-Path $target) {
  $backup = "$target.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
  Copy-Item $target $backup
  Write-Host "Backup created: $backup"
}

Copy-Item $Preset $target -Force
Write-Host "Applied preset:"
Write-Host "  $Preset"
Write-Host "to:"
Write-Host "  $target"
Write-Host ""
Write-Host "Only config.local was changed. Runtime binaries were not touched."
