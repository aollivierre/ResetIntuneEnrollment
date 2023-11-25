# Get the current time plus one minute
$startTime = (Get-Date).AddMinutes(1).ToString("HH:mm")

# Creating a basic daily trigger with the start time set to one minute after the script runs
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument 'C:\Users\hp\Anaconda3\python.exe C:\Users\hp\Desktop\py.py'
$trigger = New-ScheduledTaskTrigger -Daily -At $startTime
$task = Register-ScheduledTask -TaskName "MyTask" -Trigger $trigger -Action $action

# Updating the trigger to include repetition with a 5-minute interval, omitting RepetitionDuration
$task = Get-ScheduledTask -TaskName "MyTask"
$task.Triggers[0].Repetition.Interval = "PT5M" # Repeat every 5 minutes
$task | Set-ScheduledTask