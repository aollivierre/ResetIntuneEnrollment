function CreateScheduledTask {
    param (
        [string]$TaskName,
        [string]$ActionPath,
        [string]$ActionArguments,
        [string]$TriggerInterval
    )

    # Create a new scheduled task
    $task = New-ScheduledTask -Action (New-ScheduledTaskAction -Execute $ActionPath -Argument $ActionArguments) -Trigger (New-ScheduledTaskTrigger -Daily -At $TriggerInterval)

    # Register the task
    Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force
}

# Call the function with the desired parameters
CreateScheduledTask -TaskName "MyTask" -ActionPath "C:\Path\to\Script.ps1" -ActionArguments "-Parameter1 Value1 -Parameter2 Value2" -TriggerInterval "*/5"
