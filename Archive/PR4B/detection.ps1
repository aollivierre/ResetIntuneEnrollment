try {
    $rp1 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $rp2 = "$rp1\AU"

    # Check for missing or correct keys
    $missingOrCorrectKeys = 'WUServer', 'TargetGroup', 'WUStatusServer', 'TargetGroupEnabled' | ForEach-Object {
        $value = (Get-ItemProperty -Path $rp1 -ErrorAction SilentlyContinue).$_
        $value -eq $null
    }

    # Check for correct values in the registry
    $correctValues = @{
        'UseWUServer' = 0
        'NoAutoUpdate' = 0
        'DisableWindowsUpdateAccess' = 0
    } | ForEach-Object {
        $path = if ($_.Key -eq 'DisableWindowsUpdateAccess') {$rp1} else {$rp2}
        $value = (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue).$_.Key
        $value -eq $_.Value -or $value -eq $null
    }

    if (($missingOrCorrectKeys + $correctValues) -notcontains $false) {
        # Write-Host "All registry keys and values are set correctly. No remediation needed."
        exit 0
    } else {
        # Write-Host "Registry keys and/or values are incorrect. Remediation needed."
        exit 1
    }
} catch {
    # Write-Error "An error occurred: $_"
    exit 2
}