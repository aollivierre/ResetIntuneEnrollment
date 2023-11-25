$PackageName = "PR4B_MDMEnrollmentScripted-NEW004"
$Version = 1

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

    # Get the current time plus one minute for the trigger start time
    $startTime = (Get-Date).AddMinutes(1).ToString("HH:mm")

    # Creating a basic daily trigger with the start time set dynamically
    $actionParams = @{
        Execute  = Join-Path $env:SystemRoot -ChildPath "System32\wscript.exe"
        Argument = "`"$Path_vbs`" `"$Path_PSscript`""
    }
    $action = New-ScheduledTaskAction @actionParams
    $trigger = New-ScheduledTaskTrigger -Daily -At $startTime

    # Setting principal
    $principalParams = @{
        UserID    = "NT AUTHORITY\SYSTEM"
        LogonType = "ServiceAccount"
        RunLevel  = "Highest"
    }
    $principal = New-ScheduledTaskPrincipal @principalParams

    # Register the task
    $task = Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger -Action $action -Principal $principal -Description $schtaskDescription -Force

    # Updating the task to include repetition with a 5-minute interval
    $task = Get-ScheduledTask -TaskName $schtaskName
    $task.Triggers[0].Repetition.Interval = "PT5M" # Repeat every 5 minutes
    $task | Set-ScheduledTask

    Write-Host "Exiting MyRegisterScheduledTask function..." -ForegroundColor Magenta
}

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
        }

        Write-Host "Registering scheduled task with provided parameters..." -ForegroundColor Cyan
        # Using splatting to pass parameters to the Register-ScheduledTask function

        Write-Host "About to call MyRegisterScheduledTask function..." -ForegroundColor Green
        MyRegisterScheduledTask @scheduledTaskParams

        Write-Host "MyRegisterScheduledTask function called..." -ForegroundColor Green
    }
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}

Write-Host "Stopping transcript..." -ForegroundColor Cyan
Stop-Transcript