#region scheduled tasks and sync process
$taskName = "Schedule to run OMADMClient by client"
$timeout = 600 ##  seconds
  $timer =  [Diagnostics.Stopwatch]::StartNew()
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Start-ScheduledTask -TaskName $taskName
    while (((Get-ScheduledTask -TaskName $taskName).State -ne  'Ready') -and  ($timer.Elapsed.TotalSeconds -lt $timeout)) {    
    Write-Verbose  -Message "Waiting on scheduled task..."
    Start-Sleep -Seconds  30   
    }
    $timer.Stop()
      Write-Verbose  -Message "We waited [$($timer.Elapsed.TotalSeconds)] seconds on the task 'TaskName'"
      $fParams = @{
        Method      = 'Get'
        Uri         = "$funcUri&device=$device"
        ContentType = 'Application/Json'
    }
    $json = Invoke-RestMethod @fParams
    [datetime]$lastsyncdate = $json.lastSyncDateTime
}	
#start de compliance sync
$syncIme = New-Object -ComObject Shell.Application
$syncIme.open("intunemanagementextension://syncapp")

$syncIme = New-Object -ComObject Shell.Application
$syncIme.open("intunemanagementextension://synccompliance")
#endregion