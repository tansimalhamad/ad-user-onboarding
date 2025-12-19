[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Medium")]
param(
  [Parameter(Mandatory)]
  [ValidateScript({ Test-Path $_ })]
  [string]$CsvPath,

  [Parameter()]
  [string]$OutputDir = (Join-Path $PSScriptRoot "..\output"),

  [Parameter()]
  [switch]$DemoMode,

  [Parameter()]
  [string]$Domain = "example.local",

  [Parameter()]
  [string]$DefaultOU = "OU=Users,DC=example,DC=local",

  [Parameter()]
  [string]$HomeRoot = "\\fileserver\home",

  [Parameter()]
  [switch]$EnableUser,

  [Parameter()]
  [switch]$ForcePasswordChangeAtLogon
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Modules\Logging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Modules\Password.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Modules\Validation.psm1") -Force

$logPath = New-LogFile -LogDirectory $OutputDir -Prefix "ad_onboarding"
Write-Log -LogPath $logPath -Level INFO -Message "Starting onboarding. CsvPath=$CsvPath DemoMode=$DemoMode"

$result = New-Object System.Collections.Generic.List[object]

if (-not $DemoMode) {
  try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log -LogPath $logPath -Level INFO -Message "ActiveDirectory module loaded."
  } catch {
    Write-Log -LogPath $logPath -Level ERROR -Message "ActiveDirectory module not available. Use -DemoMode or install RSAT/AD module."
    throw
  }
}

$rows = Import-Csv -Path $CsvPath

foreach ($row in $rows) {
  try {
    Assert-UserRowValid -Row $row

    $first = $row.FirstName.Trim()
    $last  = $row.LastName.Trim()
    $dept  = $row.Department.Trim()
    $loc   = $row.Location.Trim()
    $role  = $row.Role.Trim()

    $sam = $row.SamAccountName
    if ([string]::IsNullOrWhiteSpace($sam)) {
      $sam = New-SamAccountName -FirstName $first -LastName $last
    }

    $displayName = "$first $last"
    $upn = "$sam@$Domain"
    $passwordPlain = New-RandomPassword -Length 14

    Write-Log -LogPath $logPath -Level INFO -Message "Prepared user: $displayName (sam=$sam, upn=$upn, dept=$dept, loc=$loc, role=$role)"

    if ($DemoMode) {
      if ($PSCmdle
