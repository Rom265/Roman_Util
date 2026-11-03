Function Invoke-RemoteScriptAsJob {
    <#
.SYNOPSIS
Run the indicated script on a list of piped in machines.
 
.DESCRIPTION
This script is an extention of and narrow use case of Invoke-Command that allows you to provide remote machine details and credential using the Get-CredentialedComputer script to create computer objects and pipe those into this command. The indicated script will be run as a job on each remote machine simultaneously using WinRm. This might require a credential object if the machine is in a foreign domain, for example.
Standard output from the job will be collected and displayed as well as saved to the log file, unless -PassThru is specified.

Get-MyComputerObjects.ps1 facilitates Get-CredentialedComputer.ps1 and saves output to $MyComps. You can then pipe the $MyComps collection to this script.

.NOTES
Script: Invoke-RemoteScriptAsJob.ps1
Author: Roman Revell
Requirements: PowerShell (tested on version 7.6)
Note: Module Roman_Prereq version 6.2 will suffice.
        
History: 
version 4.1   2026-09-25 Fix so that a regular object is passed as data and only the output, not the job creation output.
version 4     2026-09-08 Add -PassThru option to pass the data output of each job through onto the pipeline.
version 3     2026-04-13 Added ability to specify script block instead of script file to run quick one-off commands against a list of remote machines.
version 2.2.1   2026-04-13 Minor script technicalities and retested for verification and renamed script with approved verb.
version 2.2   2025-09-14 Updated help documentation and changed RemoteScriptPath to ScriptPath to avoid confusion.
version 2.1   2025-07-08 Update methods. Remove [ValidateNotNullOrEmpty()] from credential so that a credential is not mandatory.
version 2.0.1 2024-01-08 Remove non-operational code left by mistake
version 2     2024-01-07 Add -Argument parameter
version 1     2024-01-05

.PARAMETER ComputerName
Remote computer name.

.PARAMETER Credential
PS Credential object (user name and password) that allows admin access to the corresponding computer. (optional)

.PARAMETER IPv4Address
IPv4 address of the computer.

.PARAMETER FilePath
File path to the script that we want to run on the remote machine. It will be copied from this location to the remote machine by invoke-command. Mutually exclusive with ScriptBlock.

.PARAMETER ScriptBlock
Text of script block in PowerShell block format: {write-host "my script block"} . Mutually exclusive with ScriptPath.

.PARAMETER ArgumentList
This will be passed on to the cmdlet invoke-command. See documentation for that command to see how to supply arguments.
The script specified with ScriptPath will take these arguments and fit them in order to the parameters defined in that script.
Example: "Application Name","c:\scripts\task1\MyApp\MyAppLog.log.txt"
Since you can not pass named parameters, only positional parameters, if you need to name parameters, use a copy of the script you want to pass and modify its parameter section to have the arguments you need instead of trying to supply arguments with this parameter.

.PARAMETER LogPath
Path to a log file. This script will log the start, stop, and maybe progress details. 
Specify the full path name of the file you want to log to, otherwise it will create a default in the same directory as this script 
with the name of this script file with extension .log.txt.

.PARAMETER JobWaitTimeout
Timeout in seconds to wait for a background job to finish. After timeout, current output for unfinished jobs will be displayed and then we will resume waiting. Default is 20 seconds. This just allows you to see what is going on in the background while waiting for jobs to finish.

.PARAMETER PassThru
If specified, the output of each job will be passed through to the pipeline as a single object per job with properties: JobName, Value (output from script)   Example:
JobName               Value
-------               -----
MyHost.MyDomain.net   @{timestamp=2026-09-25T13:07:05.7783544-05:00}

Also, the data output will not also be written to the screen as it would without this switch, but messages as to the status of each machine will continue to display when the -JobWaitTimeout has expired and error messages will be displayed once each job has run.
  
.EXAMPLE
D:\OKXIX\scripts\Get-MyComputerObjects.ps1 -ComputerList "D:\OKXIX\machine groups\staging-RealName.txt" -user roman.revell@gainwelltechnologies.com
$MyComps | Invoke-RemoteScriptAsJob -FilePath "D:\OKXIX\scripts\EC2Launch\ConvertTo-EC2Launch.ps1"

.EXAMPLE
Get-CredentialedComputer -computerList "D:\OKXIX\machine groups\adhoc.txt" -Credential (Get-Credential gainwell\a-rrevell) | 
Invoke-RemoteScriptAsJob -FilePath "C:\Users\a-rrevell\Documents\PowerShell\scripts\Jboss_Audit_generic.ps1" -LogPath $home\documents\JBoss_script_test.log.txt -PassThru | 
ForEach-Object {$_.Value} | 
Select-Object -Property timestamp,hostname,ip_address,os,install_date,jboss_home,jboss_modules_jar_present,jboss_version_txt,cpu_name,cpu_cores,cpu_threads,cpu_socket,cpu_env_processors,manufacturer,model,is_virtual_machine | 
Export-CSV $home\documents\Report-JBoss.csv
#>
#requires -Modules @{ModuleName = "Roman_Prereq"; ModuleVersion = "6.2"}
    [CmdletBinding()]
    param(
        [parameter(Mandatory, ValueFromPipelineByPropertyName = $true)] [ValidateNotNullOrEmpty()] [string]
        $ComputerName,
        [parameter(ValueFromPipelineByPropertyName = $true)] [pscredential]
        $Credential,
        [parameter(ValueFromPipelineByPropertyName = $true)] [ValidateNotNullOrEmpty()] [string]
        $IPv4Address,
        [parameter(Mandatory, ParameterSetName = "FilePath" )][string]
        $FilePath, # example "D:\OKXIX\scripts\EC2Launch\ConvertTo-EC2Launch.ps1"
        [parameter(Mandatory, ParameterSetName = "ScriptBlock" )][scriptblock]
        $ScriptBlock,
        [parameter(ParameterSetName = "FilePath" )]
        $ArgumentList, # example of arguments in order of parameters to pass to the remotely run script: "Application Name","c:\scripts\task1\MyApp\MyAppLog.log.txt"
        [string]
        $LogPath,
        [int] 
        $JobWaitTimeout = 20,
        [switch]
        $PassThru
    )
    Begin {
        if ($LogPath) { Write-Log -start -log $LogPath -ErrorAction stop } else { Write-Log -start -ErrorAction stop }
    
        If ($PSCmdlet.ParameterSetName -eq "FilePath") {
            # Read the help section of the script to be run remotely. Find the line after the SYNOPSIS header. Remove blank spaces before and after the text.
            $Synopsis = help "$FilePath" | select-string SYNOPSIS -context 0, 1
            if ($Synopsis) {
                $Synopsis = ($Synopsis -split "`r")[1].trim()
                Write-Log "Running script `"$FilePath`" on selected machines to: $Synopsis." -foreground green
            }
            else { Write-Log "Running script `"$FilePath`" on selected machines." }
        }
        else {
            Write-Log "Running the script block on selected machines."
        }
    }
    Process {
        Write-Log "$ComputerName" -foreground yellow
        #Write-Log "`tExecuting script..."
        If ($PSCmdlet.ParameterSetName -eq "FilePath") {
            if ($Credential) {
                $return = invoke-command -AsJob -JobName $ComputerName -FilePath $FilePath -ArgumentList $ArgumentList -ComputerName $IPv4Address -Credential $Credential 
            }
            else {
                $return = invoke-command -AsJob -JobName $ComputerName -FilePath $FilePath -ArgumentList $ArgumentList -ComputerName $ComputerName
            }
        }
        else {
            # ScriptBlock
            if ($Credential) {
                $return = invoke-command -AsJob -JobName $ComputerName -ScriptBlock $ScriptBlock -ComputerName $IPv4Address -Credential $Credential 
            }
            else {
                $return = invoke-command -AsJob -JobName $ComputerName -ScriptBlock $ScriptBlock -ComputerName $ComputerName
            }
        }
        #Write-Log "Started job $($return.Name)" -ForegroundColor yellow
    }
    End {
        Write-Log "Get results." -foreground green
        ## Get and process each job result
        $AllJobs = Get-Job
        while ($AllJobs) {
            $thisJob = $null
            $thisJob = wait-job -Any -Timeout $JobWaitTimeout -Job $AllJobs
            if ($thisJob) {
                $JobName = $thisJob.Name
                Write-Log $JobName -foreground yellow -NoNewline
                Write-Log " completed: "
                # Get job data. Each datum can only be received once.
                $jobData = $thisJob | Receive-Job -ErrorVariable JobError
                Foreach ($Err in $JobError) {
                    Write-Log -ForegroundColor Red "`t$Err"
                }
                if ($PassThru) {
                    [PSCustomObject]@{
                        JobName = $JobName
                        Value   = $jobData
                    }
                }
                else {
                    ForEach ($Result in @($jobData)) {
                        Write-Log "`t$Result"
                    }
                }
                # Delete this job
                $thisJob | Remove-Job
                $AllJobs = Get-Job
            }
            else {
                # Get current status
                Foreach ($Job in get-job) {
                    if ($Job.State -eq "Running") {
                        Write-Log $($Job.Name) -ForegroundColor yellow -NoNewline
                        Write-Log " still running: "
                        If (!$PassThru) {
                            $jobData = $thisJob | Receive-Job -ErrorVariable JobError
                            Foreach ($Err in $JobError) {
                                Write-Log -ForegroundColor Red "`t$Err"
                            }
                        
                            ForEach ($Result in @($jobData)) {
                                Write-Log "`t$Result"
                            }
                        }
                    }
                }
                Write-Log "----------------------"
            }
        }

        Write-Log -end
    }
}