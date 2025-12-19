# AD User Onboarding (PowerShell)

This project automates the onboarding of new users in an Active Directory environment using PowerShell.

It is a learning project for the German apprenticeship  
**Fachinformatiker für Systemintegration (FiSi)**.

## Features
- Create AD users from CSV
- Assign groups based on department
- Create home folders
- Set NTFS permissions
- Logging and WhatIf mode

## Requirements
- Windows Server or Windows Client with RSAT
- PowerShell 5.1 or newer
- ActiveDirectory Module

## Example Usage
```powershell
.\src\New-CompanyUser.ps1 -CsvPath .\data\sample_users.csv -WhatIf
