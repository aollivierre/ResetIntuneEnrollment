$PackageName = "PR4B_MDMEnrollmentScripted"
$Version = 1

##########################################################################
#   Recurrence Data
##########################################################################

$Schedule_Frequency = "Daily"       # Once, Hourly, Daily, AtLogon
$Schedule_RepeatInterval = "5"      # Minutes for repetition (for Daily and Hourly)
$Schedule_StartDate = (Get-Date).AddMinutes(1).ToString("yyyy-MM-dd") # Start one minute from now
$Schedule_StartTime = (Get-Date).AddMinutes(1).ToString("HH:mm")      # Start one minute from now


# $PackageName = "PR4B_MDMEnrollmentScripted"
# $Version = 1

# ##########################################################################
# #   Recurence Data
# ##########################################################################

# $Schedule_Frequency = "Hourly"      # Once, Hourly, Daily, AtLogon
# $Schedule_RepeatInterval = "1"      # Number            (for Daily and Hourly)
# $Schedule_StartDate = "2023-01-15"  # YYYY.MM.DD        (for Once)
# $Schedule_StartTime = "6pm"         # ex 8am or 5pm     (for Once, Hourly, Daily)

# ##########################################################################


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
	$Content_VBShiddenPS = "
	Dim shell,fso,file

	Set shell=CreateObject(`"WScript.Shell`")
	Set fso=CreateObject(`"Scripting.FileSystemObject`")

	strPath=WScript.Arguments.Item(0)

	If fso.FileExists(strPath) Then
		set file=fso.GetFile(strPath)
		strCMD=`"powershell -nologo -executionpolicy ByPass -command `" & Chr(34) & `"&{`" &_
		file.ShortPath & `"}`" & Chr(34)
		shell.Run strCMD,0
	End If
	"
	$Path_VBShiddenPS = $(Join-Path -Path "$global:Path_local\Data" -ChildPath "run-ps-hidden.vbs")
	$Content_VBShiddenPS | Out-File -FilePath (New-Item -Path $Path_VBShiddenPS -Force) -Force
    return $Path_VBShiddenPS
}

if(Test-RunningAsSystem){$global:Path_local = "$ENV:Programfiles\_MEM"}
else{$global:Path_local = "$ENV:LOCALAPPDATA\_MEM"}

Start-Transcript -Path "$global:Path_local\Log\$PackageName-install.log" -Force

try{
    # local Path
    $Path_PR = "$global:Path_local\Data\PR_$PackageName"

    # Task Name & Description
    $schtaskName = "$PackageName - $env:username"
    $schtaskDescription = "Version $Version"

    # Check if Task exist with correct version
    $task_existing = Get-ScheduledTask -TaskName $schtaskName -ErrorAction SilentlyContinue
    if($task_existing.Description -like "Version $Version*"){
        Set-Location $Path_PR
        .\detection.ps1
        if($LASTEXITCODE -ne 0){
            Write-Host "Detection positiv, remediation starts now"
            .\remediation.ps1
            }else{
                Write-Host "Detection negativ, no further action needed"
            }
    }else{
        # path declaration / creation
        New-Item -path $Path_PR -ItemType Directory -Force
        $Path_PSscript = "$Path_PR\$PackageName.ps1"
        # get and save file content
        Get-Content -Path $($PSCommandPath) | Out-File -FilePath $Path_PSscript -Force
        # create vbs to run PS hidden
        $Path_vbs = Create-VBShiddenPS

        # copy/safe detection- and remediation script
        Copy-Item detection.ps1 -Destination $Path_PR -Force
        Copy-Item remediation.ps1 -Destination $Path_PR -Force

   # ... [previous parts of the script] ...

# Register scheduled task to run at startup
switch ($Schedule_Frequency) {
    "Once" {
        $trigger = New-ScheduledTaskTrigger -Once -At $(Get-Date "$Schedule_StartDate $Schedule_StartTime")
    }
    "Hourly" {
        $trigger = New-ScheduledTaskTrigger -Once -At $Schedule_StartTime -RepetitionDuration (New-TimeSpan -Days 1) -RepetitionInterval (New-TimeSpan -Hours $Schedule_RepeatInterval)
    }
    "Daily" {
        $trigger = New-ScheduledTaskTrigger -Daily -At $Schedule_StartTime -RepetitionDuration ([TimeSpan]::MaxValue) -RepetitionInterval (New-TimeSpan -Minutes $Schedule_RepeatInterval)
    }
    "AtLogon" {
        $triggerParams = @{
            AtLogon = $true
            User    = $(if (Test-RunningAsSystem) { "NT AUTHORITY\SYSTEM" } else { $env:USERNAME })
        }
        $trigger = New-ScheduledTaskTrigger @triggerParams
    }
    Default {
        Write-Error "Wrong frequency declaration."
    }
}

        
   # Determine the principal based on whether the script is running as a system
if (Test-RunningAsSystem -eq "True") {
    $principalParams = @{
        UserID    = "NT AUTHORITY\SYSTEM"
        LogonType = "ServiceAccount"
        RunLevel  = "Highest"
    }
} else {
    $principalParams = @{
        UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
}
$principal = New-ScheduledTaskPrincipal @principalParams

# Define the action for the scheduled task
$actionParams = @{
    Execute  = Join-Path $env:SystemRoot -ChildPath "System32\wscript.exe"
    Argument = "`"$Path_vbs`" `"$Path_PSscript`""
}
$action = New-ScheduledTaskAction @actionParams

# Define the settings for the scheduled task
$settingsParams = @{
    AllowStartIfOnBatteries = $true
    DontStopIfGoingOnBatteries = $true
}
$settings = New-ScheduledTaskSettingsSet @settingsParams

# Register the scheduled task
$registerTaskParams = @{
    TaskName    = $schtaskName
    Trigger     = $trigger
    Action      = $action
    Principal   = $principal
    Settings    = $settings
    Description = $schtaskDescription
    Force       = $true
}
Register-ScheduledTask @registerTaskParams

   # Register the task
if ($Schedule_Frequency -eq "Hourly") {
    Start-ScheduledTask $schtaskName
}

}catch{
    Write-Error $_
}

Stop-Transcript