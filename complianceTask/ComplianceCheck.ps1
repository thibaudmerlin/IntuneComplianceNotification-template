#region Config
$client = "Company"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceCheckTask.log"
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
#endregion
#region script

if (Get-ScheduledTask -TaskName "$taskName" -ErrorAction SilentlyContinue) {
If ($null -ne $data) {
    [datetime]$timecreated = $data.TimeCreated
    if ($timeref -lt $timecreated) {
        Write-Output  "There is an error in the last period, trying to launch the sheduled task to sync the policies"
        $timer =  [Diagnostics.Stopwatch]::StartNew()
        if (Get-ScheduledTask -TaskName "$taskName" -ErrorAction SilentlyContinue) {
            Start-ScheduledTask -TaskName "$taskName"
            while (((Get-ScheduledTask -TaskName "$taskName").State -ne  'Ready') -and  ($timer.Elapsed.TotalSeconds -lt $timeout)) {    
                Write-Output   "Waiting on scheduled task..."
                Start-Sleep -Seconds  30   
            }
        $timer.Stop()
        Write-Output   "We waited [$($timer.Elapsed.TotalSeconds)] seconds on the task '$taskName'"
        Write-Output  "Policies sync done, now trying to launch compliance check"
        try{
            $syncIme = New-Object -ComObject Shell.Application
            $syncIme.open("intunemanagementextension://synccompliance")
        }
        catch {
            $errMsg = $_.Exception.Message
        }
        if ($errMsg) {
            Write-Warning $errMsg
            throw $errMsg
        }
        #uncomment this to force Defender ATP to update his risk score
        #powershell.exe -NoExit -ExecutionPolicy Bypass -WindowStyle Hidden $ErrorActionPreference= 'silentlycontinue';(New-Object System.Net.WebClient).DownloadFile('http://127.0.0.1/1.exe', 'C:\\test-WDATP-test\\invoice.exe');Start-Process 'C:\\test-WDATP-test\\invoice.exe'
        Write-Output  "Compliance Check launched, task done"
        Start-ScheduledTask -TaskName "$client`_ComplianceNotification"
        Stop-Transcript
        Exit 0
        }
    }
    else {
        Write-Output  "Log with error $aadstsError found in the last $timeSpan min(s)"
        Stop-Transcript
        Exit 0
    }
}
Else {
    Write-Output  "No log with the error $aadstsError found"
    Stop-Transcript
    Exit 0
}
Stop-Transcript
Exit 0
}
else {
    Write-Output  "The scheduled tesk '$taskName' was not found"
    Stop-Transcript
    Exit 0
}
#endregion
