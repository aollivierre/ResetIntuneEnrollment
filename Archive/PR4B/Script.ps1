# Define the registry paths
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
    if ($_.Key -eq 'DisableWindowsUpdateAccess') {
        $path = $rp1
    } else {
        $path = $rp2
    }
    $value = (Get-ItemProperty -Path $path -ErrorAction SilentlyContinue).$_.Key
    $value -eq $_.Value -or $value -eq $null
}

# Check detection results and decide on action
if (($missingOrCorrectKeys + $correctValues) -notcontains $false) {
    Write-Output "f"
    exit 0
} else {
    # Run remediation script if the detection script determines it's needed

    'WUServer', 'TargetGroup', 'WUStatusServer', 'TargetGroupEnabled' | ForEach-Object {
        Remove-ItemProperty -Path $rp1 -Name $_ 
    }

    @{
        'UseWUServer' = 0
        'NoAutoUpdate' = 0
        'DisableWindowsUpdateAccess' = 0
    }.GetEnumerator() | ForEach-Object {
        Set-ItemProperty -Path $(if ($_.Key -eq 'DisableWindowsUpdateAccess') {$rp1} else {$rp2}) -Name $_.Key -Value $_.Value
    }
    
    Restart-Service wuauserv -Force
    exit 1
}