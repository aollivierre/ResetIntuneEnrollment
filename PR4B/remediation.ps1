try {
    New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"; New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM" -Name AutoEnrollMDM -Value 1; & "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDM
} catch {
    # Write-Error "An error occurred during remediation: $_"
    # exit 2
}