#Unique Tracking ID: 44aff377-0a75-4a32-811d-102b5acd0fa5, Timestamp: 2024-03-10 14:50:44

# Read configuration from the JSON file
# Assign values from JSON to variables


<#
.SYNOPSIS
Dot-sources all PowerShell scripts in the 'private' folder relative to the script root.

.DESCRIPTION
This function finds all PowerShell (.ps1) scripts in a 'private' folder located in the script root directory and dot-sources them. It logs the process, including any errors encountered, with optional color coding.

.EXAMPLE
Dot-SourcePrivateScripts

Dot-sources all scripts in the 'private' folder and logs the process.

.NOTES
Ensure the Write-EnhancedLog function is defined before using this function for logging purposes.
#>

$privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
$scriptFiles = Get-ChildItem -Path $privateFolderPath -Filter "*.ps1"

try {
    $scriptFiles = Get-ChildItem -Path $privateFolderPath -Filter "*.ps1"
    foreach ($file in $scriptFiles) {
        $filePath = $file.FullName
        
        . $filePath
        Write-EnhancedLog -Message "Dot-sourcing script: $($file.Name)" -Level INFO -ForegroundColor Cyan
        # $DBG
    }
}
catch {
    # Write-EnhancedLog -Message "Error dot-sourcing scripts: $_" -Level ERROR -ForegroundColor Red
}

# ################################################################################################################################
# ################################################ END DOT SOURCING ##############################################################
# ################################################################################################################################


if (Get-Command Write-EnhancedLog -ErrorAction SilentlyContinue) {
    Write-EnhancedLog -Message "Logging works" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
}
else {
    Write-Host "Write-EnhancedLog not found."
}



function Test-RunningAsSystem {
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier "S-1-5-18"
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User

    return $currentSid -eq $systemSid
}

<#
.SYNOPSIS
Elevates the script to run with administrative privileges if not already running as an administrator.

.DESCRIPTION
The CheckAndElevate function checks if the current PowerShell session is running with administrative privileges. If it is not, the function attempts to restart the script with elevated privileges using the 'RunAs' verb. This is useful for scripts that require administrative privileges to perform their tasks.

.EXAMPLE
CheckAndElevate

Checks the current session for administrative privileges and elevates if necessary.

.NOTES
This function will cause the script to exit and restart if it is not already running with administrative privileges. Ensure that any state or data required after elevation is managed appropriately.
#>
function CheckAndElevate {
    [CmdletBinding()]
    param (
        # Advanced parameters could be added here if needed. For this function, parameters aren't strictly necessary,
        # but you could, for example, add parameters to control logging behavior or to specify a different method of elevation.
        # [switch]$Elevated
    )

    begin {
        try {
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            Write-EnhancedLog -Message "Checking for administrative privileges..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Blue)
        }
        catch {
            Write-EnhancedLog -Message "Error determining administrative status: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
            throw $_
        }
    }

    process {
        if (-not $isAdmin) {
            try {
                Write-EnhancedLog -Message "The script is not running with administrative privileges. Attempting to elevate..." -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
                
                $arguments = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" $args"
                Start-Process PowerShell -Verb RunAs -ArgumentList $arguments

                # Invoke-AsSystem -PsExec64Path $PsExec64Path
                
                Write-EnhancedLog -Message "Script re-launched with administrative privileges. Exiting current session." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
                exit
            }
            catch {
                Write-EnhancedLog -Message "Failed to elevate privileges: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $_
            }
        }
        else {
            Write-EnhancedLog -Message "Script is already running with administrative privileges." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
    }

    end {
        # This block is typically used for cleanup. In this case, there's nothing to clean up,
        # but it's useful to know about this structure for more complex functions.
    }
}



<#
.SYNOPSIS
Executes a PowerShell script under the SYSTEM context, similar to Intune's execution context.

.DESCRIPTION
The Invoke-AsSystem function executes a PowerShell script using PsExec64.exe to run under the SYSTEM context. This method is useful for scenarios requiring elevated privileges beyond the current user's capabilities.

.PARAMETER PsExec64Path
Specifies the full path to PsExec64.exe. If not provided, it assumes PsExec64.exe is in the same directory as the script.

.EXAMPLE
Invoke-AsSystem -PsExec64Path "C:\Tools\PsExec64.exe"

Executes PowerShell as SYSTEM using PsExec64.exe located at "C:\Tools\PsExec64.exe".

.NOTES
Ensure PsExec64.exe is available and the script has the necessary permissions to execute it.

.LINK
https://docs.microsoft.com/en-us/sysinternals/downloads/psexec
#>

function Invoke-AsSystem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PsExec64Path,
        [string]$ScriptPathAsSYSTEM  # Path to the PowerShell script you want to run as SYSTEM
    )

    begin {
        CheckAndElevate
        # Define the arguments for PsExec64.exe to run PowerShell as SYSTEM with the script
        $argList = "-accepteula -i -s -d powershell.exe -NoExit -ExecutionPolicy Bypass -File `"$ScriptPathAsSYSTEM`""
        Write-EnhancedLog -Message "Preparing to execute PowerShell as SYSTEM using PsExec64 with the script: $ScriptPathAsSYSTEM" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
    }

    process {
        try {
            # Ensure PsExec64Path exists
            if (-not (Test-Path -Path $PsExec64Path)) {
                $errorMessage = "PsExec64.exe not found at path: $PsExec64Path"
                Write-EnhancedLog -Message $errorMessage -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                throw $errorMessage
            }

            # Run PsExec64.exe with the defined arguments to execute the script as SYSTEM
            $executingMessage = "Executing PsExec64.exe to start PowerShell as SYSTEM running script: $ScriptPathAsSYSTEM"
            Write-EnhancedLog -Message $executingMessage -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            Start-Process -FilePath "$PsExec64Path" -ArgumentList $argList -Wait -NoNewWindow

            Write-EnhancedLog -Message "SYSTEM session started. Closing elevated session..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            exit
        }
        catch {
            Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
        }
    }
}




# Assuming Invoke-AsSystem and Write-EnhancedLog are already defined
# Update the path to your actual location of PsExec64.exe
$privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
$PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

if (-not (Test-RunningAsSystem)) {
    Write-EnhancedLog -Message "Current session is not running as SYSTEM. Attempting to invoke as SYSTEM..." -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)

    $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
    Invoke-AsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem

}
else {
    Write-EnhancedLog -Message "Session is already running as SYSTEM." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
}

    
    
#################################################################################################################################
################################################# END LOGGING ###################################################################
#################################################################################################################################

<#
.SYNOPSIS
Removes MDM certificates from the specified certificate store based on issuer name.

.DESCRIPTION
The Remove-MDMCertificates function searches for and removes certificates from the specified certificate store path that are issued by the specified issuer, logging each removal action.

.PARAMETER CertStorePath
The path of the certificate store from which to remove certificates.

.PARAMETER IssuerName
The name of the issuer whose certificates should be removed.

.EXAMPLE
$parameters = @{
    CertStorePath = 'Cert:\LocalMachine\My\'
    IssuerName = "CN=Microsoft Intune MDM Device CA"
}
Remove-MDMCertificates @parameters
Removes all MDM certificates issued by Microsoft Intune from the LocalMachine's My certificate store.

.NOTES
Uses Write-EnhancedLog for detailed logging.
#>
function Remove-MDMCertificates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$CertStorePath,

        [Parameter(Mandatory = $true)]
        [string]$IssuerName
    )

    begin {
        Write-EnhancedLog -Message "Initiating MDM certificate removal from $CertStorePath certificate store." -Level "Info"
    }

    process {
        try {
            $mdmCerts = Get-ChildItem $CertStorePath | Where-Object Issuer -EQ $IssuerName
            
            if ($mdmCerts) {
                foreach ($cert in $mdmCerts) {
                    Write-EnhancedLog -Message "Removing Intune certificate $($cert.DnsNameList.Unicode)" -Level "Info"
                    Remove-Item $cert.PSPath -ErrorAction Stop
                }
            }
            else {
                Write-EnhancedLog -Message "No Intune MDM certificates found." -Level "Warning"
            }
        }
        catch {
            Write-EnhancedLog -Message "Error removing Intune MDM certificate: $_" -Level "Error"
        }
    }

    end {
        Write-EnhancedLog -Message "MDM certificate removal process completed." -Level "Info"
    }
}

<#
.SYNOPSIS
Retrieves GUIDs from the Task Scheduler within a specified root directory, ensuring only valid GUID named folders are collected.

.DESCRIPTION
The Get-ManagementGUID function connects to the Task Scheduler service and enumerates all subfolders within a specified root directory. It collects the names of these subfolders, validating that they match the GUID format, into a list. Designed for use with the Task Scheduler's Microsoft\Windows\EnterpriseMgmt directory to gather enrollment GUIDs, it can be adapted for other directories. Utilizes advanced logging through `Write-EnhancedLog` for detailed operation logs.

.PARAMETER taskRoot
The root directory within the Task Scheduler from which to start collecting GUIDs. Defaults to "\Microsoft\Windows\EnterpriseMgmt".

.EXAMPLE
PS> Get-ManagementGUID
Runs the function with its default parameter to collect GUIDs from "\Microsoft\Windows\EnterpriseMgmt".

.EXAMPLE
PS> Get-ManagementGUID -taskRoot "\Microsoft\Windows\CustomDirectory"
Specifies a custom root directory from which to collect GUIDs.

.NOTES
Ensure the custom logging function `Write-EnhancedLog` is defined in your script or module for logging to work correctly.
#>
function Get-ManagementGUID {
    [CmdletBinding()]
    param (
        [string]$taskRoot = "\Microsoft\Windows\EnterpriseMgmt"
    )

    begin {
        try {
            $taskScheduler = New-Object -ComObject Schedule.Service
            $taskScheduler.Connect()
            $EnrollmentGUIDs = New-Object System.Collections.Generic.List[object]
            # Regular expression to match GUID format
            $guidRegex = '^[{(]?[0-9A-Fa-f]{8}[-]?(?:[0-9A-Fa-f]{4}[-]?){3}[0-9A-Fa-f]{12}[)}]?$'
        }
        catch {
            Write-EnhancedLog -Message "Failed to connect to the Task Scheduler service. Error: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
            return
        }
    }

    process {
        try {
            $rootFolder = $taskScheduler.GetFolder($taskRoot)
            $subfolders = $rootFolder.GetFolders(0)
        }
        catch {
            Write-EnhancedLog -Message "Failed to get subfolders for the task root '$taskRoot'. Error: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
            return
        }

        foreach ($folder in $subfolders) {
            if ($folder.Name -match $guidRegex) {
                try {
                    $EnrollmentGUIDs.Add($folder.Name)
                    Write-EnhancedLog -Message "Added GUID: $($folder.Name)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
                }
                catch {
                    Write-EnhancedLog -Message "Failed to add GUID: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
                }
            }
            else {
                Write-EnhancedLog -Message "Skipping non-GUID folder: $($folder.Name)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)
            }
        }
    }

    end {
        if ($EnrollmentGUIDs.Count -gt 0) {
            Write-EnhancedLog -Message "$($EnrollmentGUIDs.Count) GUIDs collected successfully." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            return $EnrollmentGUIDs
        }
        else {
            Write-EnhancedLog -Message "No GUIDs found in '$taskRoot'." -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
        }
    }
}









<#
.SYNOPSIS
Checks for scheduled tasks and their folders related to a specific Enrollment GUID.

.DESCRIPTION
The Check-TaskSchedulerEntriesAndTasks function lists all scheduled tasks under the Enterprise Management path that match the specified Enrollment GUID. It also checks for the existence of corresponding task folders.

.PARAMETER EnrollmentGUID
The GUID of the enrollment entries related to the tasks to be checked.

.EXAMPLE
Check-TaskSchedulerEntriesAndTasks -EnrollmentGUID "YourGUIDHere"
Lists all scheduled tasks and checks folders under Enterprise Management that match the given GUID.

.NOTES
Uses Write-EnhancedLog for logging information.
#>
function Check-TaskSchedulerEntriesAndTasks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$EnrollmentGUID
    )

    begin {
        Write-EnhancedLog -Message "Checking Task Scheduler entries and folders for GUID: $EnrollmentGUID" -Level "Info"
        $taskScheduler = New-Object -ComObject Schedule.Service
        $taskScheduler.Connect()
    }

    process {
        $tasksFound = Get-ScheduledTask | Where-Object { $_.TaskPath -match $EnrollmentGUID }
        if ($tasksFound) {
            foreach ($task in $tasksFound) {
                Write-EnhancedLog -Message "Found task: $($task.TaskName)" -Level "Info"
            }
        }
        else {
            Write-EnhancedLog -Message "No tasks found for GUID: $EnrollmentGUID" -Level "Warning"
        }

        $taskPath1 = "$env:WINDIR\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollmentGUID"
        $taskPath2 = "$env:WINDIR\System32\Tasks\Microsoft\Windows\EnterpriseMgmtNoncritical\$EnrollmentGUID"
        $paths = @($taskPath1, $taskPath2)

        foreach ($path in $paths) {
            if (Test-Path $path) {
                Write-EnhancedLog -Message "Found task folder at path: $path" -Level "Info"
            }
            else {
                Write-EnhancedLog -Message "No task folder found at path: $path" -Level "Warning"
            }
        }
    }

    end {
        Write-EnhancedLog -Message "Task Scheduler entry and folder check for GUID: $EnrollmentGUID completed." -Level "Info"
    }
}



<#
.SYNOPSIS
Removes scheduled tasks and their folders related to a specific Enrollment GUID.

.DESCRIPTION
The Remove-TaskSchedulerEntriesAndTasks function finds and removes all scheduled tasks under the Enterprise Management path that match the specified Enrollment GUID. It also removes the corresponding task folders if they exist.

.PARAMETER EnrollmentGUID
The GUID of the enrollment entries related to the tasks to be removed.

.EXAMPLE
Remove-TaskSchedulerEntriesAndTasks -EnrollmentGUID "YourGUIDHere"
Removes all scheduled tasks and folders under Enterprise Management that match the given GUID.

.NOTES
Uses Write-EnhancedLog for logging steps and outcomes.
#>
function Remove-TaskSchedulerEntriesAndTasks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$EnrollmentGUID
    )

    begin {
        Write-EnhancedLog -Message "Initiating cleanup of Task Scheduler entries for GUID: $EnrollmentGUID" -Level "Info"
        $taskScheduler = New-Object -ComObject Schedule.Service
        $taskScheduler.Connect()
        # Initialize an array to store information about unregistered tasks.
        $unregisteredTasks = @()
    }

    process {
        try {
            $taskPath1 = "$env:WINDIR\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollmentGUID"
            $taskPath2 = "$env:WINDIR\System32\Tasks\Microsoft\Windows\EnterpriseMgmtNoncritical\$EnrollmentGUID"
            $paths = @($taskPath1, $taskPath2)

            # Remove tasks matching the GUID and store their names.
            Get-ScheduledTask | Where-Object { $_.TaskPath -match $EnrollmentGUID } | ForEach-Object {
                Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false
                # Add each unregistered task's information to the array.
                $unregisteredTasks += [PSCustomObject]@{
                    TaskName = $_.TaskName
                    TaskPath = $_.TaskPath
                }
            }

            # Remove task folders and log their paths.
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Force -ErrorAction Stop
                    Write-EnhancedLog -Message "Task folder removed successfully from path: $path" -Level "INFO"
                }
            }

            # Attempt to remove the parent folder from the Task Scheduler.
            $rootFolder = $taskScheduler.GetFolder("\")
            $rootFolder.DeleteFolder("\Microsoft\Windows\EnterpriseMgmt\$EnrollmentGUID", 0)
            Write-EnhancedLog -Message "Parent task folder for GUID - $EnrollmentGUID removed successfully" -Level "INFO"
        }
        catch {
            Write-EnhancedLog -Message "Error during cleanup: $_" -Level "Error"
        }
    }

    end {
        # Output all unregistered tasks as a single table.
        if ($unregisteredTasks.Count -gt 0) {
            $unregisteredTasks | Format-Table -AutoSize
            Write-EnhancedLog -Message "All specified tasks have been unregistered successfully." -Level "Info"
        }
        else {
            Write-EnhancedLog -Message "No tasks were found/unregistered for GUID: $EnrollmentGUID" -Level "Warning"
        }
        Write-EnhancedLog -Message "Cleanup process for GUID: $EnrollmentGUID completed." -Level "Info"
    }
}


<#
.SYNOPSIS
Removes specified registry entries under the Microsoft Enrollments key that match a given GUID.

.DESCRIPTION
The Remove-RegistryEntries function searches for and removes registry keys under "HKLM:\SOFTWARE\Microsoft\Enrollments" that match the specified EnrollmentGUID. It logs the process, including successes and warnings, using the Write-EnhancedLog function.

.PARAMETER EnrollmentGUID
The GUID of the enrollment entries to be removed from the registry.

.EXAMPLE
Remove-RegistryEntries -EnrollmentGUID "12345678-1234-1234-1234-1234567890ab"
Removes all registry entries under Microsoft Enrollments that match the given GUID.

.NOTES
Uses the Write-EnhancedLog function for logging. Ensure this function is defined in your script or module.

#>
function Remove-RegistryEntries {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$EnrollmentGUID
    )

    begin {
        $RegistryKeys = @("HKLM:\SOFTWARE\Microsoft\Enrollments")
        Write-EnhancedLog -Message "Starting registry entry removal for GUID: $EnrollmentGUID" -Level "Cyan"
    }

    process {
        foreach ($Key in $RegistryKeys) {
            try {
                if (Test-Path -Path $Key) {
                    Get-ChildItem -Path $Key |
                    Where-Object { $_.Name -match $EnrollmentGUID } |
                    ForEach-Object {
                        $_ | Remove-Item -Recurse -Force -Confirm:$false
                        Write-EnhancedLog -Message "GUID entry found and removed from $Key." -Level "Info"
                    }
                }
                else {
                    Write-EnhancedLog -Message "Registry key $Key not found or has no matching GUID entries." -Level "Warning"
                }
            }
            catch {
                Write-EnhancedLog -Message "Error removing GUID entry from $Key $_" -Level "Error"
            }
        }
    }

    end {
        Write-EnhancedLog -Message "Completed registry entry removal for GUID: $EnrollmentGUID" -Level "Info"
    }
}







<#
.SYNOPSIS
Checks for specific registry keys under given GUIDs and outputs their subkeys and values.

.DESCRIPTION
The Check-RegistryKeys function searches the registry under "HKLM:\SOFTWARE\Microsoft\Enrollments" for specified GUIDs, checks for specific subkeys (DeviceEnroller, DMClient, Poll, Push), and lists all items within these subkeys as a table of key name and value pairs.

.PARAMETER EnrollmentGUIDs
The GUIDs under which to search for specific registry subkeys.

.EXAMPLE
Check-RegistryKeys -EnrollmentGUIDs @("GUID1", "GUID2")
Searches for and lists details of specific registry subkeys under the specified GUIDs.

.NOTES
Ensure the 'Write-EnhancedLog' function is defined in your environment for logging.
#>
function Check-RegistryKeys {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$EnrollmentGUIDs
    )

    begin {
        $BaseKey = "HKLM:\SOFTWARE\Microsoft\Enrollments"
        Write-EnhancedLog -Message "Starting check for registry keys under $BaseKey for specified GUIDs." -Level "Info"
        # Initialize an array to hold all property objects
        $allProperties = @()
    }

    process {
        foreach ($GUID in $EnrollmentGUIDs) {
            $GUIDPath = Join-Path -Path $BaseKey -ChildPath $GUID
            if (Test-Path -Path $GUIDPath) {
                $SubKeys = Get-ChildItem -Path $GUIDPath -ErrorAction SilentlyContinue
                foreach ($SubKey in $SubKeys) {
                    if ($SubKey.Name -match "DeviceEnroller|DMClient|Poll|Push") {
                        $SubKeyProperties = Get-ItemProperty -Path $SubKey.PSPath
                        foreach ($Property in $SubKeyProperties.PSObject.Properties) {
                            # Add each property to the array as a custom object
                            $allProperties += [PSCustomObject]@{
                                SubKeyName    = $SubKey.PSChildName
                                PropertyName  = $Property.Name
                                PropertyValue = $Property.Value
                            }
                        }
                    }
                    else {
                        Write-EnhancedLog -Message "No relevant subkeys found under $GUIDPath." -Level "Warning"
                    }
                }
            }
            else {
                Write-EnhancedLog -Message "GUID $GUID not found under $BaseKey." -Level "Warning"
            }
        }
    }

    end {
        # Output all collected properties as a single table
        $allProperties | Format-Table -AutoSize
        Write-EnhancedLog -Message "Completed check for registry keys under specified GUIDs." -Level "Info"
    }
}







<#
.SYNOPSIS
Checks for the presence of certificates in the specified certificate store, issued by a specified issuer, within a given timeout period.

.DESCRIPTION
This function waits for up to a specified timeout for certificates to be created in the specified certificate store, looking specifically for certificates issued by the provided issuer name. It logs the waiting process and the outcome, successfully finding the certificates or timing out.

.PARAMETER CertStorePath
The path of the certificate store to check for certificates. Default is the local machine's personal certificate store.

.PARAMETER IssuerName
The name of the issuer to check for in the certificates. Default is "CN=Microsoft Intune MDM Device CA".

.PARAMETER Timeout
The maximum amount of time, in seconds, to wait for the certificates. Default is 30 seconds.

.EXAMPLE
Check-IntuneCertificates
Checks for certificates issued by Microsoft Intune in the local machine's personal certificate store with the default timeout of 30 seconds.

.EXAMPLE
Check-IntuneCertificates -CertStorePath 'Cert:\LocalMachine\My\' -IssuerName "CN=Microsoft Intune MDM Device CA" -Timeout 60
Checks for certificates with a custom timeout of 60 seconds in the specified certificate store and issuer.

.NOTES
Ensure that the 'Write-EnhancedLog' function is defined in your environment for logging.
#>

function Check-IntuneCertificates {
    [CmdletBinding()]
    Param(
        [string]$CertStorePath = 'Cert:\LocalMachine\My\',
        [string]$IssuerName = "CN=Microsoft Intune MDM Device CA",
        [int]$Timeout = 30
    )

    Begin {
        Write-EnhancedLog -Message "Waiting for certificate creation from issuer: $IssuerName" -Level "INFO" -ForegroundColor ([ConsoleColor]::Cyan)
    }

    Process {
        $i = $Timeout
        while (!(Get-ChildItem $CertStorePath | Where-Object { $_.Issuer -match $IssuerName }) -and $i -gt 0) {
            Start-Sleep -Seconds 1
            $i--
            Write-EnhancedLog -Message "Waiting... ($i seconds remaining)" -ForegroundColor ([ConsoleColor]::DarkYellow)
        }

        if ($i -eq 0) {
            Write-EnhancedLog -Message "Certificate (issuer: $IssuerName) isn't created (yet?)." -Level "WARNING" -ForegroundColor ([ConsoleColor]::Yellow)
        }
        else {
            Write-EnhancedLog -Message "Certificate creation from issuer: $IssuerName confirmed :)" -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
    }

    End {
        Write-EnhancedLog -Message "Check-IntuneCertificates function has completed." -Level "INFO" -ForegroundColor ([ConsoleColor]::Cyan)
    }
}


# Check-IntuneCertificates












function Perform-IntuneCleanup {
    # Assuming Check-IntuneCertificates and Remove-MDMCertificates are defined elsewhere

    # Check for Intune-related certificates before removal.
    Check-IntuneCertificates

    # First, remove any MDM certificates.
    

    # Define the parameters in a hashtable
    $parameters = @{
        CertStorePath = 'Cert:\LocalMachine\My\'
        IssuerName    = "CN=Microsoft Intune MDM Device CA"
    }

    # Call the function with splatting
    Remove-MDMCertificates @parameters


    # Check again after removal.
    Check-IntuneCertificates


    # Obtain the current management GUIDs.
    $EnrollmentGUIDs = Get-ManagementGUID

    if ($EnrollmentGUIDs.Count -eq 0) {
        Write-EnhancedLog -Message "No enrollment GUIDs found. Exiting cleanup process." -Level "Warning" -ForegroundColor Yellow
        return
    }

    foreach ($EnrollmentGUID in $EnrollmentGUIDs) {
        Write-EnhancedLog -Message "Current enrollment GUID detected as $EnrollmentGUID" -Level "Info" -ForegroundColor Cyan

        # Check registry keys before removal.
        Write-EnhancedLog -Message "Checking registry keys before cleanup for GUID: $EnrollmentGUID" -Level "Info" -ForegroundColor Cyan
        Check-RegistryKeys -EnrollmentGUIDs @($EnrollmentGUID)


        Check-TaskSchedulerEntriesAndTasks -EnrollmentGUID $EnrollmentGUID

        # Remove task scheduler entries and tasks.
        # Assuming Remove-TaskSchedulerEntriesAndTasks is defined elsewhere.
        Remove-TaskSchedulerEntriesAndTasks -EnrollmentGUID $EnrollmentGUID


        Check-TaskSchedulerEntriesAndTasks -EnrollmentGUID $EnrollmentGUID

        # Delete specific registry entries associated with the GUID.
        Remove-RegistryEntries -EnrollmentGUID $EnrollmentGUID

        # Check registry keys after removal to confirm cleanup.
        Write-EnhancedLog -Message "Verifying registry cleanup for GUID: $EnrollmentGUID" -Level "Info" -ForegroundColor Cyan
        Check-RegistryKeys -EnrollmentGUIDs @($EnrollmentGUID)
    }

    Write-EnhancedLog -Message "Intune cleanup process completed." -Level "Success" -ForegroundColor Green
}

# Start the cleanup process
Perform-IntuneCleanup


<#
.SYNOPSIS
Enables AutoEnrollment to Mobile Device Management (MDM) by modifying the registry and invoking the device enrollment process.

.DESCRIPTION
This function creates a new registry key for Mobile Device Management under Microsoft Windows CurrentVersion policies. It then sets the AutoEnrollMDM property to enable automatic MDM enrollment. Finally, it invokes the device enroller executable to apply the changes.

.EXAMPLE
Enable-MDMAutoEnrollment

This command runs the Enable-MDMAutoEnrollment function to enable automatic device enrollment in MDM.

.NOTES
This function requires administrative privileges to modify the registry and to run the device enrollment executable.

#>

function Enable-MDMAutoEnrollment {
    [CmdletBinding()]
    Param()

    Begin {
    }

    Process {
        Try {
            $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM"

            # Check if the registry key exists
            if (-not (Test-Path $registryPath)) {
                Write-EnhancedLog -Message "Creating registry key for MDM AutoEnrollment." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
                New-Item $registryPath -ErrorAction Stop | Out-Null
            }
            else {
                Write-EnhancedLog -Message "Registry key for MDM AutoEnrollment already exists. Skipping creation." -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)
            }

            # Check if the AutoEnrollMDM property exists
            $propertyExists = $false
            Try {
                $propertyExists = [bool](Get-ItemProperty -Path $registryPath -Name AutoEnrollMDM -ErrorAction Stop)
            }
            Catch {
                $propertyExists = $false
            }

            if (-not $propertyExists) {
                Write-EnhancedLog -Message "Setting AutoEnrollMDM property." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
                New-ItemProperty -Path $registryPath -Name AutoEnrollMDM -Value 1 -ErrorAction Stop | Out-Null
            }
            else {
                Write-EnhancedLog -Message "AutoEnrollMDM property already set. Skipping." -Level "INFO" -ForegroundColor ([ConsoleColor]::Yellow)
            }

            # Invoke the device enrollment process
            Write-EnhancedLog -Message "Invoking the device enrollment process." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
            & "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDM

            Write-EnhancedLog -Message "MDM AutoEnrollment process completed successfully." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        }
        Catch {
            Write-EnhancedLog -Message "An error occurred during the MDM AutoEnrollment process: $_" -Level "ERROR" -ForegroundColor ([ConsoleColor]::Red)
        }
    }

    End {
        Write-EnhancedLog -Message "MDM AutoEnrollment function has completed." -Level "INFO" -ForegroundColor ([ConsoleColor]::Green)
        Check-IntuneCertificates
    }
}

Enable-MDMAutoEnrollment