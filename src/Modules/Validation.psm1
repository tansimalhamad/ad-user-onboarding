function Remove-Diacritics {
  param([Parameter(Mandatory)][string]$Text)

  $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
  $sb = New-Object System.Text.StringBuilder

  foreach ($c in $normalized.ToCharArray()) {
    $uc = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
    if ($uc -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb.Append($c)
    }
  }
  return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function New-SamAccountName {
  param(
    [Parameter(Mandatory)][string]$FirstName,
    [Parameter(Mandatory)][string]$LastName,
    [int]$MaxLength = 20
  )

  $fn = (Remove-Diacritics $FirstName).ToLower()
  $ln = (Remove-Diacritics $LastName).ToLower()

  $fn = ($fn -replace "[^a-z]", "")
  $ln = ($ln -replace "[^a-z]", "")

  if (-not $fn -or -not $ln) { throw "Cannot create SamAccountName from '$FirstName $LastName'." }

  $base = ($fn.Substring(0, [Math]::Min(1, $fn.Length)) + $ln)
  if ($base.Length -gt $MaxLength) { $base = $base.Substring(0, $MaxLength) }

  return $base
}

function Assert-UserRowValid {
  param([Parameter(Mandatory)]$Row)

  foreach ($field in @("FirstName","LastName","Department","Location","Role")) {
    if (-not $Row.$field -or [string]::IsNullOrWhiteSpace($Row.$field)) {
      throw "CSV row missing required field: $field"
    }
  }
}

Export-ModuleMember -Function New-SamAccountName, Assert-UserRowValid, Remove-Diacritics
