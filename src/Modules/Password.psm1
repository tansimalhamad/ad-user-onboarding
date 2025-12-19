function New-RandomPassword {
  param(
    [int]$Length = 14
  )

  $lower = "abcdefghijkmnopqrstuvwxyz"
  $upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
  $nums  = "23456789"
  $spec  = "!@#$%&*_-+?"

  $all = ($lower + $upper + $nums + $spec).ToCharArray()

  $pw = @(
    $lower[(Get-Random -Minimum 0 -Maximum $lower.Length)]
    $upper[(Get-Random -Minimum 0 -Maximum $upper.Length)]
    $nums[(Get-Random -Minimum 0 -Maximum $nums.Length)]
    $spec[(Get-Random -Minimum 0 -Maximum $spec.Length)]
  )

  for ($i = $pw.Count; $i -lt $Length; $i++) {
    $pw += $all[(Get-Random -Minimum 0 -Maximum $all.Length)]
  }

  -join ($pw | Sort-Object { Get-Random })
}

Export-ModuleMember -Function New-RandomPassword
