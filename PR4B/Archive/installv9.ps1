# Check if C:\IntuneTask exists and if not create it
if (-not (Test-Path "C:\IntuneTask")) {
    New-Item -Path "C:\IntuneTask" -ItemType Directory -Force
}

# Get the location of the current script
$currentScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Copy script.ps1 to C:\IntuneTask
Copy-Item -Path "$currentScriptPath\script.ps1" -Destination "C:\IntuneTask" -Force

# Scheduled task properties
$TaskName = "WindowsUpdateResetTask_03f5f774-7ea5-4163-a969-4994ba7b20c5_2023_08_16_11_27_29"
$TaskDescription = "Task to reset specific Windows Update registry settings and restart the update service."
$ScriptPath = "C:\IntuneTask\script.ps1"

# Create task action
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $ScriptPath"

# Create daily trigger
$Trigger = New-ScheduledTaskTrigger -Daily -At "12:00 AM"

# Create principal
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Define task settings
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Register the task
Try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description $TaskDescription -Force
    Write-Host "Task registered successfully." -ForegroundColor Green
} Catch {
    Write-Host "Error registering task: $_" -ForegroundColor Red
}
