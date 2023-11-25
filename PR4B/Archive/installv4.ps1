# check if running as system
function Test-RunningAsSystem {
    [CmdletBinding()]
    param()
    process {
        return [bool]($(whoami -user) -match "S-1-5-18")
    }
}

function Create-VBShiddenPS {
    # Dummy vbscript to hide PowerShell Window popping up at task execution
    $Content_VBShiddenPS = @"
    Dim shell,fso,file

    Set shell=CreateObject("WScript.Shell")
    Set fso=CreateObject("Scripting.FileSystemObject")

    strPath=WScript.Arguments.Item(0)

    If fso.FileExists(strPath) Then
        set file=fso.GetFile(strPath)
        strCMD="powershell -nologo -executionpolicy ByPass -command " & Chr(34) & "&{" &_
        file.ShortPath & "}" & Chr(34)
        shell.Run strCMD,0
    End If
"@
    $Path_VBShiddenPS = $(Join-Path -Path "$global:Path_local\Data" -ChildPath "run-ps-hidden.vbs")
    $Content_VBShiddenPS | Out-File -FilePath (New-Item -Path $Path_VBShiddenPS -Force) -Force
    Write-Host "VBScript for hidden PowerShell execution created at $Path_VBShiddenPS" -ForegroundColor Green
    return $Path_VBShiddenPS
}
    
$PackageName = "PR4B_MDMEnrollmentScripted"
$Version = 1

# Recurrence Data
$Schedule_Frequency = "Daily"
$Schedule_RepeatInterval = 5 # In Minutes
$Schedule_StartDate = (Get-Date).AddMinutes(1).ToString("yyyy-MM-dd")
$Schedule_StartTime = (Get-Date).AddMinutes(1).ToString("HH:mm")

Write-Host "Script initialization completed. Package Name: $PackageName, Version: $Version" -ForegroundColor Cyan

# Function definitions (Test-RunningAsSystem and Create-VBShiddenPS) remain unchanged

if (Test-RunningAsSystem) {
    $global:Path_local = "$ENV:Programfiles\_MEM"
    Write-Host "Running as System. Global path set to $global:Path_local" -ForegroundColor Green
}
else {
    $global:Path_local = "$ENV:LOCALAPPDATA\_MEM"
    Write-Host "Running as User. Global path set to $global:Path_local" -ForegroundColor Yellow
}

Start-Transcript -Path "$global:Path_local\Log\$PackageName-install.log" -Force
Write-Host "Transcript started at $global:Path_local\Log\$PackageName-install.log" -ForegroundColor Cyan

try {
    # Rest of your script setup (up to the task creation)

    # Register scheduled task to run at startup
    switch ($Schedule_Frequency) {
        "Once" {
            $triggerParams = @{
                At   = $(Get-Date "$Schedule_StartDate $Schedule_StartTime")
                Once = $true
            }
            Write-Host "Setting up Once trigger with start date: $Schedule_StartDate and start time: $Schedule_StartTime" -ForegroundColor White
        }
        "Hourly" {
            $triggerParams = @{
                Once               = $true
                At                 = $Schedule_StartTime
                RepetitionDuration = [TimeSpan]::FromDays(1)
                RepetitionInterval = [TimeSpan]::FromHours($Schedule_RepeatInterval)
            }
            Write-Host "Setting up Hourly trigger with repetition interval: $Schedule_RepeatInterval hours" -ForegroundColor White
        }
        "Daily" {
            $triggerParams = @{
                Daily = $true
                At    = $Schedule_StartTime
            }
            $repetitionParams = @{
                RepetitionDuration = [TimeSpan]::MaxValue
                RepetitionInterval = [TimeSpan]::FromMinutes($Schedule_RepeatInterval)
            }
        }        
        "AtLogon" {
            $triggerParams = @{
                AtLogon = $true
                User    = $(if (Test-RunningAsSystem) { "NT AUTHORITY\SYSTEM" } else { $env:USERNAME })
            }
            Write-Host "Setting up AtLogon trigger for user: $(if (Test-RunningAsSystem) { 'NT AUTHORITY\SYSTEM' } else { $env:USERNAME })" -ForegroundColor White
        }
        Default {
            Write-Error "Wrong frequency declaration."
            Write-Host "Invalid schedule frequency: $Schedule_Frequency" -ForegroundColor Red
        }
    }

    $trigger = New-ScheduledTaskTrigger @triggerParams
    $trigger.RepetitionInterval = $repetitionParams.RepetitionInterval
    $trigger.RepetitionDuration = $repetitionParams.RepetitionDuration

    Write-Host "Scheduled task trigger created successfully" -ForegroundColor Green

    # Remaining task creation logic using splatting as in your provided script

    # Register the task
    if ($Schedule_Frequency -eq "Hourly") {
        Start-ScheduledTask $schtaskName
        Write-Host "Scheduled task started: $schtaskName" -ForegroundColor Green
    }

    Write-Host "Script execution completed successfully." -ForegroundColor Cyan

}
catch {
    Write-Error $_
    Write-Host "An error occurred: $_" -ForegroundColor Red
}

Stop-Transcript
Write-Host "Transcript stopped. Log file saved at $global:Path_local\Log\$PackageName-install.log" -ForegroundColor Cyan
