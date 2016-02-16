function Test-Process
{
	<#
	.SYNOPSIS
		This function is called after the execution of an external CMD process to log the status of how the process was exited.
	.PARAMETER Process
		A System.Diagnostics.Process object type that is output by using the -Passthru parameter on the Start-Process cmdlet
	#>
	[CmdletBinding()]
	param (
		[Parameter()]
		[System.Diagnostics.Process]$Process
	)
	process
	{
		try
		{
			Write-Log -Message "$($MyInvocation.MyCommand) - BEGIN"
			if (@(0, 3010) -notcontains $Process.ExitCode)
			{
				Write-Log -Message "Process ID $($Process.Id) failed. Return value was $($Process.ExitCode)" -LogLevel '2'
				$false
			}
			else
			{
				Write-Log -Message "Process ID $($Process.Id) exited with successfull exit code '$($Process.ExitCode)'."
				$true
			}
			Write-Log -Message "$($MyInvocation.MyCommand) - END"
		}
		catch
		{
			Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			Write-Log -Message "$($MyInvocation.MyCommand) - END"
			$false
		}
	}
}

function Get-ChildProcess
{
	<#
	.SYNOPSIS
		This function childs all child processes a parent process has spawned
	.PARAMETER ProcessId
		The potential parent process ID
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$ProcessId
	)
	process
	{
		try
		{
			Get-WmiObject -Class Win32_Process -Filter "ParentProcessId = '$ProcessId'"
		}
		catch
		{
			Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$false
		}
	}
}

function Stop-MyProcess
{
	<#
	.SYNOPSIS
		This function stops a process while provided robust logging of the activity
	.PARAMETER ProcessName
		One more process names
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string[]]$ProcessName
	)
	process
	{
		try
		{
			Write-Log -Message "$($MyInvocation.MyCommand) - BEGIN"
			$ProcessesToStop = Get-Process -Name $ProcessName -ErrorAction 'SilentlyContinue'
			if (!$ProcessesToStop)
			{
				Write-Log -Message "-No processes to be killed found..."
			}
			else
			{
				foreach ($process in $ProcessesToStop)
				{
					Write-Log -Message "-Process $($process.Name) is running. Attempting to stop..."
					$WmiProcess = Get-WmiObject -Class Win32_Process -Filter "name='$($process.Name).exe'" -ea 'SilentlyContinue' -ev WMIError
					if ($WmiError)
					{
						Write-Log -Message "Unable to stop process $($process.Name). WMI query errored with `"$($WmiError.Exception.Message)`"" -LogLevel '2'
						$false
					}
					elseif ($WmiProcess)
					{
						$WmiResult = $WmiProcess.Terminate()
						if ($WmiResult.ReturnValue -eq 1603)
						{
							Write-Log -Message "Process $($process.name) exited successfully but needs a reboot."
						}
						elseif ($WmiResult.ReturnValue -ne 0)
						{
							Write-Log -Message "-Unable to stop process $($process.name). Return value was $($WmiResult.ReturnValue)" -LogLevel '2'
							$false
						}
						else
						{
							Write-Log -Message "-Successfully stopped process $($process.Name)..."
							$true
						}
					}
				}
			}
			Write-Log -Message "$($MyInvocation.MyCommand) - END"
		}
		catch
		{
			Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			Write-Log -Message "$($MyInvocation.MyCommand) - END"
			$false
		}
	}
}

function Wait-MyProcess
{
	<#
	.SYNOPSIS
		This function waits for a process and waits for all that process's children before releasing control
	.PARAMETER ProcessId
		A process Id
	.PARAMETER ProcessTimeout
		An interval (in seconds) to wait for the process to finish.  If the process hasn't exited within this timeout
		it will be terminated.  The default is 600 seconds (5 minutes) so no process will run longer than that.
	.PARAMETER ReportInterval
		The number of seconds between when it is logged that the process is still pending
	.PARAMETER SleepInterval
		The number of seconds the process should be checked to ensure it's still running

	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[int]$ProcessId,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$ProcessTimeout = 600,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$ReportInterval = 15,
		
		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[int]$SleepInterval = 1
		
	)
	process
	{
		try
		{
			Write-Log -Message "$($MyInvocation.MyCommand) - BEGIN"
			
			Write-Log -Message "Finding the process ID '$ProcessId'..."
			$Process = Get-Process -Id $ProcessId -ea 'SilentlyContinue'
			if ($Process)
			{
				Write-Log -Message "Process '$($Process.Name)' ($($Process.Id)) found. Waiting to finish and capturing all child processes."
				$ChildProcessIds = @()
				## While waiting for the initial process to stop, collect all child IDs it spawns
				$ChildProcessesToLive = @()
				
				## Start the timer to ensure we have a point to get total time from
				$Timer = [Diagnostics.Stopwatch]::StartNew()
				$i = 0
				
				## Do this while the parent process is still running
				while (-not $Process.HasExited)
				{
					## Find any and all child processes the parent process spawned
					$ChildProcesses = Get-ChildProcess -ProcessId $ProcessId
					if ($ChildProcesses)
					{
						## If any child processes are found, collect them all
						$ChildProcessesToLive += $ChildProcesses
					}
					if ($Timer.Elapsed.TotalSeconds -ge $ProcessTimeout)
					{
						Write-Log -Message "The process '$($Process.Name)' ($($Process.Id)) has exceeded the timeout of $ProcessTimeout seconds.  Killing process."
						$Timer.Stop()
						Stop-MyProcess -ProcessName $Process.Name
					}
					elseif (($i % $ReportInterval) -eq 0) ## Use a modulus here to write to the log every X seconds
					{
						Write-Log "Still waiting for process '$($Process.Name)' ($($Process.Id)) after $([Math]::Round($Timer.Elapsed.TotalSeconds, 0)) seconds"
					}
					Start-Sleep -Seconds $SleepInterval
					$i++
				}
				Write-Log "Process '$($Process.Name)' ($($Process.Id)) has finished after $([Math]::Round($Timer.Elapsed.TotalSeconds, 0)) seconds"
				if ($ChildProcessesToLive) ## If any child processes were spawned while the parent process was running
				{
					$ChildProcessesToLive = $ChildProcessesToLive | Select-Object -Unique ## Ensure we didn't accidently capture duplicate PIDs
					Write-Log -Message "Parent process '$($Process.Name)' ($($Process.Id)) has finished but still has $($ChildProcessesToLive | Get-Count) child processes ($($ChildProcessesToLive.Name -join ',')) left.  Waiting on these to finish."
					foreach ($Process in $ChildProcessesToLive)
					{
						Wait-MyProcess -ProcessId $Process.ProcessId
					}
				}
				else
				{
					Write-Log -Message 'No child processes found spawned'
				}
				Write-Log -Message "Finished waiting for process '$($Process.Name)' ($($Process.Id)) and all child processes"
				
				## If we got this far, the function was a success
				$true
			}
			else
			{
				Write-Log -Message "Process ID '$ProcessId' not found.  No need to wait on it."
			}
		}
		catch
		{
			Write-Log -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)" -LogLevel '3'
			$false
		}
		finally
		{
			Write-Log -Message "$($MyInvocation.MyCommand) - END"
		}
	}
}