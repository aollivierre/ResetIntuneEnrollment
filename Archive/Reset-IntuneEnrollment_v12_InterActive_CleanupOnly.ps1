<#
.SYNOPSIS
Script for resetting Intune enrollment and Hybrid AzureAD join connection.

.DESCRIPTION
This script resets the device Intune management connection and Hybrid AzureAD join connection. It performs the following actions:
- Checks if running as admin and relaunches as admin if not
- Resets Hybrid AzureAD join connection
- Removes device records from Intune
- Removes Intune connection data and invokes re-enrollment
- Opens Intune logs, event viewer with Intune log, and generates & opens MDMDiagReport.html report for Intune policies debugging on client

.PARAMETER computerName
(optional) Name of the computer.

.NOTES
This script contains the following functions:
- CheckIfAdmin: Checks if running as admin and relaunches as admin if not
- Reset-IntuneEnrollment: Resets device Intune management connection
- Invoke-MDMReenrollment: Force re-enrollment of Intune managed devices
- Get-IntuneLog: Opens Intune logs, event viewer with Intune log, and generates & opens MDMDiagReport.html report for Intune policies debugging on client
- Reset-HybridADJoin: Resets Hybrid AzureAD join connection

#>
#TODO func1 CheckIfAdmin
# Check if running as admin and if not, relaunch as admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch as an admin
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}



# Generate a timestamp for the log file name
$timestampForFileName = Get-Date -Format "yyyyMMdd-HHmmss"
$logDirectory = "C:\Code\_MEM\logs\ResetIntuneMDMEnrollment"
$logFilePath = Join-Path $logDirectory "_$timestampForFileName.log"

# Function to ensure log directory exists
function Ensure-LogDirectoryExists {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory | Out-Null
    }
}

# Function to append a message to the log file
function Write-Logwithtimestamp {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$MessageType = "Info"
    )
    Ensure-LogDirectoryExists -Path $logDirectory
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFilePath -Value "[$timestamp] $Message"

    # Color-coding for console output
    switch ($MessageType) {
        "Info" {
            Write-Host "[$timestamp] $Message" -ForegroundColor Green
        }
        "Warning" {
            Write-Host "[$timestamp] $Message" -ForegroundColor Yellow
        }
        "Error" {
            Write-Host "[$timestamp] $Message" -ForegroundColor Red
        }
    }
}


#TODO (MAIN) func5 Reset-IntuneEnrollment
function Reset-IntuneEnrollment {
    <#
    .SYNOPSIS
    Function for resetting device Intune management connection.

    .DESCRIPTION
    Function for resetting device Intune management connection.

    It will:
     - check actual Intune status on device
     - reset Hybrid AzureAD join
     - remove device records from Intune
     - remove Intune connection data and invoke re-enrollment

    .PARAMETER computerName
    (optional) Name of the computer.

    .EXAMPLE
    Reset-IntuneEnrollment

    .NOTES
    # How MDM (Intune) enrollment works https://techcommunity.microsoft.com/t5/intune-customer-success/support-tip-understanding-auto-enrollment-in-a-co-managed/ba-p/834780
    #>

    [CmdletBinding()]
    param (
        [string] $computerName = $env:COMPUTERNAME
    )

    $ErrorActionPreference = "Stop"



    #TODO region helper functions
  



    #TODO func6 Begin Defining Invoke-MDMReenrollment
    function Invoke-MDMReenrollment {
        <#
        .SYNOPSIS
        Function for resetting device Intune management connection.

        .DESCRIPTION
        Force re-enrollment of Intune managed devices.

        It will:
        - remove Intune certificates
        - remove Intune scheduled tasks & registry keys
        - force re-enrollment via DeviceEnroller.exe

        .PARAMETER computerName
        (optional) Name of the remote computer, which you want to re-enroll.

        .PARAMETER asSystem
        Switch for invoking re-enroll as a SYSTEM instead of logged user.

        .EXAMPLE
        Invoke-MDMReenrollment

        Invoking re-enroll to Intune on local computer under logged user.

        .EXAMPLE
        Invoke-MDMReenrollment -computerName PC-01 -asSystem

        Invoking re-enroll to Intune on computer PC-01 under SYSTEM account.

        .NOTES
        https://www.maximerastello.com/manually-re-enroll-a-co-managed-or-hybrid-azure-ad-join-windows-10-pc-to-microsoft-intune-without-loosing-current-configuration/

        Based on work of MauriceDaly.
        #>

        [Alias("Invoke-IntuneReenrollment")]
        [CmdletBinding()]
        param (
            [string] $computerName,

            [switch] $asSystem
        )

        if ($computerName -and $computerName -notin "localhost", $env:COMPUTERNAME) {
            if (! ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                throw "You don't have administrator rights"
            }
        }

        $allFunctionDefs = "function Invoke-AsSystem { ${function:Invoke-AsSystem} }"

        $scriptBlock = {
            param ($allFunctionDefs, $asSystem)

            try {
                foreach ($functionDef in $allFunctionDefs) {
                    . ([ScriptBlock]::Create($functionDef))
                }

                Write-Host "Checking for MDM certificate in computer certificate store"

                #TODO Check&Delete MDM device certificate
                Get-ChildItem 'Cert:\LocalMachine\My\' | Where-Object Issuer -EQ "CN=Microsoft Intune MDM Device CA" | ForEach-Object {
                    Write-LogWithTimestamp -Message "Removing Intune certificate $($_.DnsNameList.Unicode)" -MessageType Info
                    Remove-Item $_.PSPath
                }

                #TODO Obtain current management GUID from Task Scheduler
                # $EnrollmentGUID = Get-ScheduledTask | Where-Object { $_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt\*" } | Select-Object -ExpandProperty TaskPath -Unique | Where-Object { $_ -like "*-*-*" } | Split-Path -Leaf

$taskScheduler = New-Object -ComObject Schedule.Service
$taskScheduler.Connect()

$taskRoot = "\Microsoft\Windows\EnterpriseMgmt"
$rootFolder = $taskScheduler.GetFolder($taskRoot)

$subfolders = $rootFolder.GetFolders(0)

foreach ($folder in $subfolders) {
    Write-LogWithTimestamp -Message "Folder Name: $($folder.Name)" -MessageType Info
    Write-LogWithTimestamp -Message "Folder Path: $($folder.Path)" -MessageType Info
    Write-LogWithTimestamp -Message "-----------------------------" -MessageType Info

    $EnrollmentGUID = $folder.Name

    #TODO Start cleanup process
    if (![string]::IsNullOrEmpty($EnrollmentGUID)) {
        Write-Host "Current enrollment GUID detected as $([string]$EnrollmentGUID)"

        # TODO Remove task scheduler entries
        Write-LogWithTimestamp -Message "Removing task scheduler Enterprise Management entries for GUID - $([string]$EnrollmentGUID)" -MessageType Info
        Get-ScheduledTask | Where-Object { $_.Taskpath -match $EnrollmentGUID } | Unregister-ScheduledTask -Confirm:$false

        #TODO Calling Remove-Item against Task Sched for EnterpriseMgmt and EnterpriseMgmtNoncritical
        try {
            $taskPath1 = "$env:WINDIR\System32\Tasks\Microsoft\Windows\EnterpriseMgmt\$EnrollmentGUID"
            $taskPath2 = "$env:WINDIR\System32\Tasks\Microsoft\Windows\EnterpriseMgmtNoncritical\$EnrollmentGUID"

            Remove-Item -Path $taskPath1 -Force -ErrorAction Stop
            Write-Host "Task removed successfully from path: $taskPath1" -ForegroundColor Green

            Remove-Item -Path $taskPath2 -Force -ErrorAction Stop
            Write-LogWithTimestamp -Message "Task removed successfully from path: $taskPath2" -MessageType Success
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }

        #TODO Delete the parent folder in Task Scheduler
        try {
            $rootFolder.DeleteFolder("\$EnrollmentGUID",0)
            Write-LogWithTimestamp -Message "Parent task folder for GUID - $([string]$EnrollmentGUID) removed successfully" -MessageType Success
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }

        <#
        .SYNOPSIS
        Removes registry entries related to Intune enrollment.

        .DESCRIPTION
        This script removes registry entries related to Intune enrollment, including entries for Enrollments, Status, EnterpriseResourceManager, PolicyManager, and Provisioning.

        .PARAMETER EnrollmentGUID
        The GUID of the enrollment to remove.

        .NOTES
        This script should be run as an administrator.

        .EXAMPLE
        .\Reset-IntuneEnrollment_v11_InterActive_CleanupOnly.ps1 -EnrollmentGUID "12345678-1234-1234-1234-1234567890ab"
        #>

        #TODO Calling Remove-Item against Regedit for Enrollments and PolicyManager and Provisioning
        # Define registry keys to be processed
        $RegistryKeys = "HKLM:\SOFTWARE\Microsoft\Enrollments",
                        "HKLM:\SOFTWARE\Microsoft\Enrollments\Status",
                        "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked",
                        "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled",
                        "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers",
                        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts",
                        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger",
                        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions"
        foreach ($Key in $RegistryKeys) {
            Write-Host "Processing registry key $Key"
            # TODO Remove registry entries
            if (Test-Path -Path $Key) {
                #TODO Search for and remove keys with matching GUID
                Write-Logwithtimestamp -Message "GUID entry found in $Key. Removing..." -MessageType Information
                Get-ChildItem -Path $Key | Where-Object { $_.Name -match $EnrollmentGUID } | Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
            else {
                # throw "Unable to obtain enrollment GUID value from task scheduler. Aborting"

                Write-Logwithtimestamp -Message "Error: unable to obtain enrollment GUID $EnrollmentGUID value from $key" -MessageType Error
                Write-Logwithtimestamp -Message "Error: $($_.Exception.Message)" -MessageType Error
            }
        }
        
    }
}
           
            }
            catch [System.Exception] {
                throw "Error message: $($_.Exception.Message)"
            }
        }

        $param = @{
            scriptBlock  = $scriptBlock
            argumentList = $allFunctionDefs, $asSystem
        }

        if ($computerName -and $computerName -notin "localhost", $env:COMPUTERNAME) {
            $param.computerName = $computerName
        }

        Invoke-Command @param
    }


    #TODO func6 End of Defining Invoke-MDMReenrollment
    #TODO func7 Begin Defining Get-IntuneLog
    function Get-IntuneLog {
        <#
        .SYNOPSIS
        Function for Intune policies debugging on client.
        - opens Intune logs
        - opens event viewer with Intune log
        - generates & open MDMDiagReport.html report

        .DESCRIPTION
        Function for Intune policies debugging on client.
        - opens Intune logs
        - opens event viewer with Intune log
        - generates & open MDMDiagReport.html report

        .PARAMETER computerName
        Name of remote computer.

        .EXAMPLE
        Get-IntuneLog
        #>

        [CmdletBinding()]
        param (
            [string] $computerName
        )

        if ($computerName -and $computerName -in "localhost", $env:COMPUTERNAME) {
            $computerName = $null
        }

        # show DM info
        #TODO Checking HKLM:SOFTWARE\Microsoft\Enrollments
        $param = @{
            scriptBlock = { Get-ChildItem -Path HKLM:SOFTWARE\Microsoft\Enrollments -Recurse | Where-Object { $_.Property -like "*UPN*" } }
        }
        if ($computerName) {
            $param.computerName = $computerName
        }
        Invoke-Command @param | Format-Table

    
    }

    #TODO func7 End of Defining Get-IntuneLog
    #TODO func9 Begin Defining Reset-HybridADJoin
    #Reset-HybridADJoin
    function Reset-HybridADJoin {
        <#
        .SYNOPSIS
        Function for resetting Hybrid AzureAD join connection.

        .DESCRIPTION
        Function for resetting Hybrid AzureAD join connection.
        It will:
        - un-join computer from AzureAD (using dsregcmd.exe)
        - remove leftover certificates
        - invoke rejoin (using sched. task 'Automatic-Device-Join')
        - inform user about the result

        .PARAMETER computerName
        (optional) name of the computer you want to rejoin.

        .EXAMPLE
        Reset-HybridADJoin

        Un-join and re-join this computer to AzureAD

        .NOTES
        https://www.maximerastello.com/manually-re-register-a-windows-10-or-windows-server-machine-in-hybrid-azure-ad-join/
        #>

        [CmdletBinding()]
        param (
            [string] $computerName
        )

        Write-Warning "For join AzureAD process to work. Computer account has to exists in AzureAD already (should be synchronized via 'AzureAD Connect')!"

        
        #TODO region helper functions
        
        #TODO func10 Begin Defining Invoke-AsSystem
        function Invoke-AsSystem {
            <#
            .SYNOPSIS
            Function for running specified code under SYSTEM account.

            .DESCRIPTION
            Function for running specified code under SYSTEM account.

            Helper files and sched. tasks are automatically deleted.

            .PARAMETER scriptBlock
            Scriptblock that should be run under SYSTEM account.

            .PARAMETER computerName
            Name of computer, where to run this.

            .PARAMETER returnTranscript
            Add creating of transcript to specified scriptBlock and returns its output.

            .PARAMETER cacheToDisk
            Necessity for long scriptBlocks. Content will be saved to disk and run from there.

            .PARAMETER argument
            If you need to pass some variables to the scriptBlock.
            Hashtable where keys will be names of variables and values will be, well values :)

            Example:
            [hashtable]$Argument = @{
                name = "John"
                cities = "Boston", "Prague"
                hash = @{var1 = 'value1','value11'; var2 = @{ key ='value' }}
            }

            Will in beginning of the scriptBlock define variables:
            $name = 'John'
            $cities = 'Boston', 'Prague'
            $hash = @{var1 = 'value1','value11'; var2 = @{ key ='value' }

            ! ONLY STRING, ARRAY and HASHTABLE variables are supported !

            .PARAMETER runAs
            Let you change if scriptBlock should be running under SYSTEM, LOCALSERVICE or NETWORKSERVICE account.

            Default is SYSTEM.

            .EXAMPLE
            Invoke-AsSystem {New-Item $env:TEMP\abc}

            On local computer will call given scriptblock under SYSTEM account.

            .EXAMPLE
            Invoke-AsSystem {New-Item "$env:TEMP\$name"} -computerName PC-01 -ReturnTranscript -Argument @{name = 'someFolder'} -Verbose

            On computer PC-01 will call given scriptblock under SYSTEM account i.e. will create folder 'someFolder' in C:\Windows\Temp.
            Transcript will be outputted in console too.
            #>

            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true)]
                [scriptblock] $scriptBlock,

                [string] $computerName,

                [switch] $returnTranscript,

                [hashtable] $argument,

                [ValidateSet('SYSTEM', 'NETWORKSERVICE', 'LOCALSERVICE')]
                [string] $runAs = "SYSTEM",

                [switch] $CacheToDisk
            )

            (Get-Variable runAs).Attributes.Clear()
            $runAs = "NT Authority\$runAs"

            #TODO region prepare Invoke-Command parameters
            # export this function to remote session (so I am not dependant whether it exists there or not)
            $allFunctionDefs = "function Create-VariableTextDefinition { ${function:Create-VariableTextDefinition} }"

            $param = @{
                argumentList = $scriptBlock, $runAs, $CacheToDisk, $allFunctionDefs, $VerbosePreference, $ReturnTranscript, $Argument
            }

            if ($computerName -and $computerName -notmatch "localhost|$env:COMPUTERNAME") {
                $param.computerName = $computerName
            }
            else {
                if (! ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                    throw "You don't have administrator rights"
                }
            }
            #endregion prepare Invoke-Command parameters

            Invoke-Command @param -ScriptBlock {
                param ($scriptBlock, $runAs, $CacheToDisk, $allFunctionDefs, $VerbosePreference, $ReturnTranscript, $Argument)

                foreach ($functionDef in $allFunctionDefs) {
                    . ([ScriptBlock]::Create($functionDef))
                }

                $TranscriptPath = "$ENV:TEMP\Invoke-AsSYSTEM_$(Get-Random).log"

                if ($Argument -or $ReturnTranscript) {
                    # define passed variables
                    if ($Argument) {
                        # convert hash to variables text definition
                        $VariableTextDef = Create-VariableTextDefinition $Argument
                    }

                    if ($ReturnTranscript) {
                        # modify scriptBlock to contain creation of transcript
                        $TranscriptStart = "Start-Transcript $TranscriptPath"
                        $TranscriptEnd = 'Stop-Transcript'
                    }

                    $ScriptBlockContent = ($TranscriptStart + "`n`n" + $VariableTextDef + "`n`n" + $ScriptBlock.ToString() + "`n`n" + $TranscriptStop)
                    Write-Verbose "####### SCRIPTBLOCK TO RUN"
                    Write-Verbose $ScriptBlockContent
                    Write-Verbose "#######"
                    $scriptBlock = [Scriptblock]::Create($ScriptBlockContent)
                }

                if ($CacheToDisk) {
                    $ScriptGuid = New-Guid
                    $null = New-Item "$($ENV:TEMP)\$($ScriptGuid).ps1" -Value $ScriptBlock -Force
                    $pwshcommand = "-ExecutionPolicy Bypass -Window Hidden -noprofile -file `"$($ENV:TEMP)\$($ScriptGuid).ps1`""
                }
                else {
                    $encodedcommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($ScriptBlock))
                    $pwshcommand = "-ExecutionPolicy Bypass -Window Hidden -noprofile -EncodedCommand $($encodedcommand)"
                }

                $OSLevel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
                if ($OSLevel -lt 6.2) { $MaxLength = 8190 } else { $MaxLength = 32767 }
                if ($encodedcommand.length -gt $MaxLength -and $CacheToDisk -eq $false) {
                    throw "The encoded script is longer than the command line parameter limit. Please execute the script with the -CacheToDisk option."
                }

                try {
                    #region create&run sched. task
                    $A = New-ScheduledTaskAction -Execute "$($ENV:windir)\system32\WindowsPowerShell\v1.0\powershell.exe" -Argument $pwshcommand
                    if ($runAs -match "\$") {
                        # pod gMSA uctem
                        $P = New-ScheduledTaskPrincipal -UserId $runAs -LogonType Password
                    }
                    else {
                        # pod systemovym uctem
                        $P = New-ScheduledTaskPrincipal -UserId $runAs -LogonType ServiceAccount
                    }
                    $S = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd
                    $taskName = "RunAsSystem_" + (Get-Random)
                    try {
                        $null = New-ScheduledTask -Action $A -Principal $P -Settings $S -ea Stop | Register-ScheduledTask -Force -TaskName $taskName -ea Stop
                    }
                    catch {
                        if ($_ -match "No mapping between account names and security IDs was done") {
                            throw "Account $runAs doesn't exist or cannot be used on $env:COMPUTERNAME"
                        }
                        else {
                            throw "Unable to create helper scheduled task. Error was:`n$_"
                        }
                    }

                    # run scheduled task
                    Start-Sleep -Milliseconds 200
                    Start-ScheduledTask $taskName

                    # wait for sched. task to end
                    Write-Verbose "waiting on sched. task end ..."
                    $i = 0
                    while (((Get-ScheduledTask $taskName -ErrorAction silentlyContinue).state -ne "Ready") -and $i -lt 500) {
                        ++$i
                        Start-Sleep -Milliseconds 200
                    }

                    # get sched. task result code
                    $result = (Get-ScheduledTaskInfo $taskName).LastTaskResult

                    # read & delete transcript
                    if ($ReturnTranscript) {
                        # return just interesting part of transcript
                        if (Test-Path $TranscriptPath) {
                            $transcriptContent = (Get-Content $TranscriptPath -Raw) -Split [regex]::escape('**********************')
                            # return command output
                            ($transcriptContent[2] -split "`n" | Select-Object -Skip 2 | Select-Object -SkipLast 3) -join "`n"

                            Remove-Item $TranscriptPath -Force
                        }
                        else {
                            Write-Warning "There is no transcript, command probably failed!"
                        }
                    }

                    if ($CacheToDisk) { $null = Remove-Item "$($ENV:TEMP)\$($ScriptGuid).ps1" -Force }

                    try {
                        Unregister-ScheduledTask $taskName -Confirm:$false -ea Stop
                    }
                    catch {
                        throw "Unable to unregister sched. task $taskName. Please remove it manually"
                    }

                    if ($result -ne 0) {
                        throw "Command wasn't successfully ended ($result)"
                    }
                    #endregion create&run sched. task
                }
                catch {
                    throw $_.Exception
                }
            }
        }
        #TODO func10 End of Defining Invoke-AsSystem
        #endregion helper functions

        $allFunctionDefs = "function Invoke-AsSystem { ${function:Invoke-AsSystem} }"

        $param = @{
            scriptblock  = {
                param( $allFunctionDefs )

                $ErrorActionPreference = "Stop"

                foreach ($functionDef in $allFunctionDefs) {
                    . ([ScriptBlock]::Create($functionDef))
                }

                $dsreg = dsregcmd.exe /status
                if (($dsreg | Select-String "DomainJoined :") -match "NO") {
                    throw "Computer is NOT domain joined"
                }



                #TODO checking dsregcmd.exe /status
                $dsreg = dsregcmd.exe /status
                if (!(($dsreg | Select-String "AzureAdJoined :") -match "NO")) {
                    throw "$env:COMPUTERNAME is still joined to Azure. Run again"
                }

                #TODO check certificates
                "Waiting for certificate creation"
                $i = 30
                Write-Verbose "two certificates should be created in Computer Personal cert. store (issuer: MS-Organization-Access, MS-Organization-P2P-Access [$(Get-Date -Format yyyy)]"

                Start-Sleep 3

                while (!($hybridJoinCert = Get-ChildItem 'Cert:\LocalMachine\My\' | ? { $_.Issuer -match "MS-Organization-Access|MS-Organization-P2P-Access \[\d+\]" }) -and $i -gt 0) {
                    Start-Sleep 3
                    --$i
                    $i
                }

                #TODO check AzureAd join status
                #TODO Calling dsregcmd.exe /status
                $dsreg = dsregcmd.exe /status
                if (($dsreg | Select-String "AzureAdJoined :") -match "YES") {
                    ++$AzureAdJoined
                }

                if ($hybridJoinCert -and $AzureAdJoined) {
                    "$env:COMPUTERNAME was successfully joined to AAD again."
                }
                else {
                    $problem = @()

                    if (!$AzureAdJoined) {
                        $problem += " - computer is not AzureAD joined"
                    }

                    if (!$hybridJoinCert) {
                        $problem += " - certificates weren't created"
                    }

                    Write-Error "Join wasn't successful:`n$($problem -join "`n")"
                    Write-Warning "Check if device $env:COMPUTERNAME exists in AAD"
                    Write-Warning "Run:`ngpupdate /force /target:computer"
                    Write-Warning "You can get failure reason via manual join by running: Invoke-AsSystem -scriptBlock {dsregcmd /join /debug} -returnTranscript"
                    throw 1
                }
            }
            argumentList = $allFunctionDefs
        }

        if ($computerName -and $computerName -notin "localhost", $env:COMPUTERNAME) {
            $param.computerName = $computerName
        }
        else {
            if (! ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
                throw "You don't have administrator rights"
            }
        }

        Invoke-Command @param
    }

    #TODO func9 End of Defining Reset-HybridADJoin
    #TODO func11 Begin Defining Get-IntuneEnrollmentStatus
    function Get-IntuneEnrollmentStatus {
        <#
        .SYNOPSIS
        Function for checking whether computer is managed by Intune (fulfill all requirements).

        .DESCRIPTION
        Function for checking whether computer is managed by Intune (fulfill all requirements).
        What is checked:
        - device is AAD joined
        - device is joined to Intune
        - device has valid Intune certificate
        - device has Intune sched. tasks
        - device has Intune registry keys
        - Intune service exists

        Returns true or false.

        .PARAMETER computerName
        (optional) name of the computer to check.

        .PARAMETER checkIntuneToo
        Switch for checking Intune part too (if device is listed there).

        .EXAMPLE
        Get-IntuneEnrollmentStatus

        Check Intune status on local computer.

        .EXAMPLE
        Get-IntuneEnrollmentStatus -computerName ae-50-pc

        Check Intune status on computer ae-50-pc.

        .EXAMPLE
        Get-IntuneEnrollmentStatus -computerName ae-50-pc -checkIntuneToo

        Check Intune status on computer ae-50-pc, plus connects to Intune and check whether ae-50-pc exists there.
        #>

        [CmdletBinding()]
        param (
            [string] $computerName,

            [switch] $checkIntuneToo
        )

        if (!$computerName) { $computerName = $env:COMPUTERNAME }

  

        $scriptBlock = {
            param ($checkIntuneToo, $intuneObj)

            $intuneNotJoined = 0


            #TODO region dsregcmd checks
            $dsregcmd = dsregcmd.exe /status
            $azureAdJoined = $dsregcmd | Select-String "AzureAdJoined : YES"
            if (!$azureAdJoined) {
                ++$intuneNotJoined
                Write-Warning "Device is NOT AAD joined"
            }

            $tenantName = $dsregcmd | Select-String "TenantName : .+"
            $MDMUrl = $dsregcmd | Select-String "MdmUrl : .+"
            if (!$tenantName -or !$MDMUrl) {
                ++$intuneNotJoined
                Write-Warning "Device is NOT Intune joined"
            }
            #endregion dsregcmd checks

            #TODO region certificate checks
            $MDMCert = Get-ChildItem 'Cert:\LocalMachine\My\' | Where-Object Issuer -EQ "CN=Microsoft Intune MDM Device CA"
            if (!$MDMCert) {
                ++$intuneNotJoined
                Write-Warning "Intune certificate is missing"
            }
            elseif ($MDMCert.NotAfter -lt (Get-Date) -or $MDMCert.NotBefore -gt (Get-Date)) {
                ++$intuneNotJoined
                Write-Warning "Intune certificate isn't valid"
            }
            #endregion certificate checks

            #TODO region sched. task checks
            $MDMSchedTask = Get-ScheduledTask | Where-Object { $_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt\*" -and $_.TaskName -eq "PushLaunch" }
            $enrollmentGUID = $MDMSchedTask | Select-Object -ExpandProperty TaskPath -Unique | Where-Object { $_ -like "*-*-*" } | Split-Path -Leaf
            if (!$enrollmentGUID) {
                ++$intuneNotJoined
                Write-Warning "Synchronization sched. task is missing"
            }
            #endregion sched. task checks

            #TODO region registry checks
            if ($enrollmentGUID) {
                $missingRegKey = @()
                $registryKeys = "HKLM:\SOFTWARE\Microsoft\Enrollments", "HKLM:\SOFTWARE\Microsoft\Enrollments\Status", "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked", "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled", "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers", "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts", "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger", "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions"
                foreach ($key in $registryKeys) {
                    if (!(Get-ChildItem -Path $key -ea SilentlyContinue | Where-Object { $_.Name -match $enrollmentGUID })) {
                        Write-Warning "Registry key $key is missing"
                        # ++$intuneNotJoined
                    }
                }
            }
            #endregion registry checks

            #TODO region service checks
            $MDMService = Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue
            if (!$MDMService) {
                ++$intuneNotJoined
                Write-Warning "Intune service IntuneManagementExtension is missing"
            }
            if ($MDMService -and $MDMService.Status -ne "Running") {
                Write-Warning "Intune service IntuneManagementExtension is not running"
            }
            #endregion service checks

            if ($intuneNotJoined) {
                return $false
            }
            else {
                return $true
            }
        }

        $param = @{
            scriptBlock  = $scriptBlock
            argumentList = $checkIntuneToo, $intuneObj
        }
        if ($computerName -and $computerName -notin "localhost", $env:COMPUTERNAME) {
            $param.computerName = $computerName
        }

        Invoke-Command @param
    }
    #TODO func11 End of Defining Get-IntuneEnrollmentStatus
    #endregion helper functions

    #TODO checking Intune Connection Status
    Write-Host "Checking actual Intune connection status" -ForegroundColor Cyan

    #TODO Calling Get-IntuneEnrollmentStatus
    # if (Get-IntuneEnrollmentStatus -computerName $computerName) {
    #     $choice = ""
    #     while ($choice -notmatch "^[Y|N]$") {
    #         $choice = Read-Host "It seems device has working Intune connection. Continue? (Y|N)"
    #     }
    #     if ($choice -eq "N") {
    #         break
    #     }
    # }






    Write-Host "Invoking re-enrollment of Intune connection" -ForegroundColor Cyan
    #TODO Calling Invoke-MDMReenrollment
    Invoke-MDMReenrollment -computerName $computerName -asSystem


    #TODO check certificates
    $i = 30
    Write-Host "Waiting for Intune certificate creation"  -ForegroundColor Cyan
    Write-Verbose "two certificates should be created in Computer Personal cert. store (issuer: MS-Organization-Access, MS-Organization-P2P-Access [$(Get-Date -Format yyyy)]"
    while (!(Get-ChildItem 'Cert:\LocalMachine\My\' | Where-Object { $_.Issuer -match "CN=Microsoft Intune MDM Device CA" }) -and $i -gt 0) {
        Start-Sleep 1
        --$i
        $i
    }

    if ($i -eq 0) {
        Write-Warning "Intune certificate (issuer: Microsoft Intune MDM Device CA) isn't created (yet?)"
    }
    else {
        Write-Host "DONE :)" -ForegroundColor Green
    }
}
#TODO (MAIN) Calling func5 Reset-IntuneEnrollment
Reset-IntuneEnrollment

