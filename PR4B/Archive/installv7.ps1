$PackageName = "PR4B_MDMEnrollmentScripted"
$Version = 1
$Schedule_Frequency = "Hourly"
$Schedule_RepeatInterval = "1"
$Schedule_StartDate = "2023-01-15"
$Schedule_StartTime = "6pm"

Write-Host "Initializing script variables..." -ForegroundColor Cyan

function Test-RunningAsSystem {
    Write-Host "Checking if running as System..." -ForegroundColor Magenta
    return [bool]($(whoami -user) -match "S-1-5-18")
}

function Create-VBShiddenPS {
    Write-Host "Creating VBScript to hide PowerShell window..." -ForegroundColor Magenta
    $scriptBlock = @"
    Dim shell,fso,file

    Set shell=CreateObject("WScript.Shell")
    Set fso=CreateObject("Scripting.FileSystemObject")

    strPath=WScript.Arguments.Item(0)

    If fso.FileExists(strPath) Then
        set file=fso.GetFile(strPath)
        strCMD="powershell -nologo -executionpolicy ByPass -command " & Chr(34) & "&{" & file.ShortPath & "}" & Chr(34)
        shell.Run strCMD,0
    End If
"@
    $Path_VBShiddenPS = Join-Path -Path "$global:Path_local\Data" -ChildPath "run-ps-hidden.vbs"
    $scriptBlock | Out-File -FilePath (New-Item -Path $Path_VBShiddenPS -Force) -Force
    return $Path_VBShiddenPS
}

function Check-ExistingTask {
    param (
        [string]$taskName,
        [string]$version
    )
    Write-Host "Checking for existing scheduled task..." -ForegroundColor Magenta
    $task_existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    return $task_existing.Description -like "Version $version*"
}

function Execute-DetectionAndRemediation {
    param (
        [string]$Path_PR
    )
    Write-Host "Executing detection and remediation scripts..." -ForegroundColor Magenta
    Set-Location $Path_PR
    .\detection.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Detection positive, remediation starts now" -ForegroundColor Green
        .\remediation.ps1
    }
    else {
        Write-Host "Detection negative, no further action needed" -ForegroundColor Yellow
    }
}

function MyRegisterScheduledTask {
    param (
        [string]$schtaskName,
        [string]$schtaskDescription,
        [string]$Path_vbs,
        [string]$Path_PSscript
    )

    Write-Host "Registering scheduled task..." -ForegroundColor Magenta

    # Create a daily trigger
    $Trigger = New-ScheduledTaskTrigger -Daily -At "12:00 AM"

    # Modify the trigger to add repetition (workaround)
    $TriggerXml = $Trigger.GetXml()
    $TriggerXml = $TriggerXml -replace 'Interval="P1D"', 'Interval="PT5M" Duration="P1D"'

    # Create a new trigger from modified XML
    $Trigger = [Microsoft.Management.Infrastructure.CimInstance]::CreateInstanceFromQueryResult($TriggerXml, "root/Microsoft/Windows/TaskScheduler")

    # Create an action for the task
    $Action = New-ScheduledTaskAction -Execute $Path_vbs -Argument "`"$Path_PSscript`""

    # Principal settings (running as SYSTEM in highest privileges)
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Define task settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    # Register the task with the above settings
    Register-ScheduledTask -TaskName $schtaskName -Description $schtaskDescription -Trigger $Trigger -Action $Action -Principal $Principal -Settings $settings -Force

    # Start the task immediately
    Start-ScheduledTask -TaskName $schtaskName
}

# Example call to the function
# MyRegisterScheduledTask -schtaskName "MyTask" -schtaskDescription "Runs daily and repeats every 5 minutes" -Path_vbs "C:\Path\To\Script.vbs" -Path_PSscript "C:\Path\To\Script.ps1"





Write-Host "Exiting Register-ScheduledTask function..." -ForegroundColor Magenta

Write-Host "Checking running context..." -ForegroundColor Cyan
if (Test-RunningAsSystem) {
    $global:Path_local = "$ENV:Programfiles\_MEM"
    Write-Host "Running as system, setting path to Program Files" -ForegroundColor Yellow
}
else {
    $global:Path_local = "$ENV:LOCALAPPDATA\_MEM"
    Write-Host "Running as user, setting path to Local AppData" -ForegroundColor Yellow
}

Write-Host "Starting transcript..." -ForegroundColor Cyan
$logFileName = "$global:Path_local\Log\${PackageName}-install-$(Get-Date -Format 'yyyyMMddHHmmss').log"
Write-Host "Log file name set to: $logFileName" -ForegroundColor Cyan
Start-Transcript -Path $logFileName -Force

try {
    Write-Host "Preparing script execution..." -ForegroundColor Cyan
    $Path_PR = "$global:Path_local\Data\PR_$PackageName"
    $schtaskName = "$PackageName - $env:username"
    $schtaskDescription = "Version $Version"

    Write-Host "Checking for existing task..." -ForegroundColor Cyan
    if (Check-ExistingTask -taskName $schtaskName -version $Version) {
        Execute-DetectionAndRemediation -Path_PR $Path_PR
    }
    else {
        Write-Host "Setting up new task environment..." -ForegroundColor Cyan
        New-Item -path $Path_PR -ItemType Directory -Force
        $Path_PSscript = "$Path_PR\$PackageName.ps1"
        Get-Content -Path $($PSCommandPath) | Out-File -FilePath $Path_PSscript -Force
        $Path_vbs = Create-VBShiddenPS

        Copy-Item detection.ps1 -Destination $Path_PR -Force
        Copy-Item remediation.ps1 -Destination $Path_PR -Force

        # Creating a hashtable for splatting
        $scheduledTaskParams = @{
            schtaskName             = $schtaskName
            schtaskDescription      = $schtaskDescription
            Path_vbs                = $Path_vbs
            Path_PSscript           = $Path_PSscript
            Schedule_Frequency      = $Schedule_Frequency
            Schedule_RepeatInterval = $Schedule_RepeatInterval
            Schedule_StartDate      = $Schedule_StartDate
            Schedule_StartTime      = $Schedule_StartTime
        }

        Write-Host "Registering scheduled task with provided parameters..." -ForegroundColor Cyan
        # Using splatting to pass parameters to the Register-ScheduledTask function

        Write-Host "About to call MyRegisterScheduledTask function..." -ForegroundColor Green
        # MyRegisterScheduledTask @scheduledTaskParams




        # Creating a hashtable for splatting
        $params = @{
            schtaskName        = "MyTask"
            schtaskDescription = "Runs daily and repeats every 5 minutes"
            Path_vbs           = "C:\Path\To\Script.vbs"
            Path_PSscript      = "C:\Path\To\Script.ps1"
        }

        # Using splatting to pass parameters to the MyRegisterScheduledTask function
        MyRegisterScheduledTask @params



        Write-Host "MyRegisterScheduledTask function called..." -ForegroundColor Green
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}

Write-Host "Stopping transcript..." -ForegroundColor Cyan
Stop-Transcript