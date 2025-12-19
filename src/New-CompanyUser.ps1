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
      if ($PSCmdlet.ShouldProcess($displayName, "DEMO: simulate create user")) {
        Start-Sleep -Milliseconds 150
        Write-Log -LogPath $logPath -Level INFO -Message "DEMO: would create AD user '$sam' in '$DefaultOU'"
        Write-Log -LogPath $logPath -Level INFO -Message "DEMO: would create homefolder '$HomeRoot\$sam' and set ACLs"
        Write-Log -LogPath $logPath -Level INFO -Message "DEMO: would add groups based on dept/role"
      }

      $result.Add([pscustomobject]@{
        DisplayName = $displayName
        SamAccountName = $sam
        UPN = $upn
        Department = $dept
        Location = $loc
        Role = $role
        Mode = "DEMO"
        Status = "Simulated"
      })
      continue
    }

    $securePw = ConvertTo-SecureString -String $passwordPlain -AsPlainText -Force

    $groups = @()
    switch ($dept.ToLower()) {
      "it"    { $groups += "GG_IT_Standard" }
      "sales" { $groups += "GG_Sales_Standard" }
      "hr"    { $groups += "GG_HR_Standard" }
      default { $groups += "GG_Employees" }
    }
    if ($role.ToLower() -eq "admin") {
      $groups += "GG_IT_Admins"
    }

    if ($PSCmdlet.ShouldProcess($displayName, "Create AD user and configure resources")) {

      $existing = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
      if ($existing) {
        throw "User already exists in AD: SamAccountName=$sam"
      }

      New-ADUser `
        -Name $displayName `
        -GivenName $first `
        -Surname $last `
        -DisplayName $displayName `
        -SamAccountName $sam `
        -UserPrincipalName $upn `
        -AccountPassword $securePw `
        -Path $DefaultOU `
        -Enabled:([bool]$EnableUser) `
        -ChangePasswordAtLogon:([bool]$ForcePasswordChangeAtLogon)

      Write-Log -LogPath $logPath -Level INFO -Message "Created AD user: $sam"

      foreach ($g in $groups) {
        try {
          Add-ADGroupMember -Identity $g -Members $sam
          Write-Log -LogPath $logPath -Level INFO -Message "Added $sam to group $g"
        } catch {
          Write-Log -LogPath $logPath -Level WARN -Message "Could not add $sam to group $g. $_"
        }
      }

      $homePath = Join-Path $HomeRoot $sam
      Write-Log -LogPath $logPath -Level INFO -Message "Homefolder intended: $homePath (create + ACL not implemented in this repo for safety)."
    }

    $result.Add([pscustomobject]@{
      DisplayName = $displayName
      SamAccountName = $sam
      UPN = $upn
      Department = $dept
      Location = $loc
      Role = $role
      Mode = "AD"
      Status = "Created"
    })

  } catch {
    Write-Log -LogPath $logPath -Level ERROR -Message "Failed row: $($row.FirstName) $($row.LastName) -> $_"

    $result.Add([pscustomobject]@{
      DisplayName = "$($row.FirstName) $($row.LastName)"
      SamAccountName = $row.SamAccountName
      UPN = ""
      Department = $row.Department
      Location = $row.Location
      Role = $row.Role
      Mode = $(if ($DemoMode) { "DEMO" } else { "AD" })
      Status = "FAILED"
      Error = "$_"
    })
  }
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
$resultPath = Join-Path $OutputDir "result_$ts.csv"
$result | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $resultPath

Write-Log -LogPath $logPath -Level INFO -Message "Done. Result saved to: $resultPath"
Write-Log -LogPath $logPath -Level INFO -Message "Log saved to: $logPath"
