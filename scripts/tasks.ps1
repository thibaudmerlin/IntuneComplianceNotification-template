#region Config
$client = "Company"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceScript.log"
#endregion
#region Logging
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$logFile" -Force
#endregion
#region variables
$aadstsError = "AADSTS53003"
$timeSpan = -15
$taskName = "Schedule to run OMADMClient by client"
$timeout = 600 ##  seconds
$data = Get-WinEvent -LogName Microsoft-Windows-AAD/Operational | Where-Object Message -Match $aadstsError | Select-Object -First 1
[datetime]$timeref = (get-date).AddMinutes($timeSpan)
[datetime]$timecreated = $data.TimeCreated
#endregion
#region script
If ($null -ne $data) {
    if ($timeref -lt $timecreated) {
        Write-Verbose -Message "There is an error in the last period, trying to launch the sheduled task to sync the policies"
        $timer =  [Diagnostics.Stopwatch]::StartNew()
        if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
            Start-ScheduledTask -TaskName $taskName
            while (((Get-ScheduledTask -TaskName $taskName).State -ne  'Ready') -and  ($timer.Elapsed.TotalSeconds -lt $timeout)) {    
                Write-Verbose  -Message "Waiting on scheduled task..."
                Start-Sleep -Seconds  30   
            }
        $timer.Stop()
        Write-Verbose  -Message "We waited [$($timer.Elapsed.TotalSeconds)] seconds on the task '$taskName'"
        Write-Verbose -Message "Policies sync done, now trying to launch compiance check"
        $syncIme = New-Object -ComObject Shell.Application
        $syncIme.open("intunemanagementextension://synccompliance")
        Write-Verbose -Message "Compliance Check launched, task done"
        Exit 0
        }
    }
    else {
        Write-Verbose -Message "Log with error $aadstsError found, but too old for this task"
        Exit 0
    }
}
Else {
    Write-Verbose -Message "No log with the error $aadstsError found"
    Exit 0
}
#endregion