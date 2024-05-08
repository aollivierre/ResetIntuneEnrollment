# Define the log file name based on the hostname
$hostname = hostname
$logFileName = "$hostname.txt"
# $logFileFullPath = Join-Path -Path $PSScriptRoot -ChildPath $logFileName

# Start transcript and overwrite if the log file already exists
Start-Transcript -Path c:\temp\$logFileName -Force

# Your original commands
New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM" -Name AutoEnrollMDM -Value 1 -Force
& "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDM

# Optionally, you can log additional information here
Write-Host "Hostname: $hostname"

Stop transcript