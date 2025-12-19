function New-LogFile {
  param(
    [Parameter(Mandatory)]
    [string]$LogDirectory,
    [string]$Prefix = "onboarding"
  )

  if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
  }

  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $logPath = Join-Path $LogDirectory "$Prefix`_$timestamp.log"
  New-Item -ItemType File -Path $logPath -Force | Out-Null
  return $logPath
}

function Write-Log {
  param(
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet("INFO","WARN","ERROR","DEBUG")]
    [string]$Level = "INFO",
    [string]$LogPath
  )

  $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
  Write-Host $line

  if ($LogPath) {
    Add-Content -Path $LogPath -Value $line
  }
}

Export-ModuleMember -Function New-LogFile, Write-Log
