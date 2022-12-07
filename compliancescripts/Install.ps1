#region Config
$client = "Company"
$scriptsPath = "$env:ProgramData\$client\Scripts\ComplianceScript"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceScript-RunOnceConfig.log"
$logonScript = "ComplianceCheck.ps1"
$buildId = "cb5b1c07-3258-4fb1-a223-06bf3b6033a8"
#endregion
#region Logging
if (!(Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -Type Directory -Force | Out-Null
}
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

if (Test-Path "$scriptsPath\$logonScript") {
    Remove-Item -Path "$scriptsPath\$logonScript" -Force
}
Start-Transcript -Path "$logFile" -Force
#endregion
#region Logon Script Contents
Write-Host "Creating Compliance script and storing: $scriptsPath\$logonScript" -ForegroundColor Yellow
Copy-Item "$PSScriptRoot\$logonScript" -Destination "$scriptsPath\$logonScript" -Force
#endregion
#region Scheduled Task
try {
    Write-Host "Setting up scheduled task"
    if (!(Get-ScheduledTask -TaskName "$client`_Logonscript" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        $ShedService = New-Object -comobject 'Schedule.Service'
        $ShedService.Connect()

        $Task = $ShedService.NewTask(0)
        $Task.RegistrationInfo.Description = "Logon Script for $client"
        $Task.Settings.Enabled = $true
        $Task.Settings.AllowDemandStart = $true
        $Task.Settings.IdleSettings.StopOnIdleEnd = $false
        $Task.Settings.RunOnlyIfIdle = $false
        $Task.Settings.DisallowStartIfOnBatteries = $false
        $Task.Settings.StopIfGoingOnBatteries = $false

        $trigger = $task.triggers.Create(9)
        $trigger.Enabled = $true

        $trigger = $task.triggers.Create(0)
        $trigger.Subscription = @'
<QueryList>
    <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
        <Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[(EventID=10000)]]</Select>
    </Query>
</QueryList>
'@
        $trigger.Enabled = $true

        $action = $Task.Actions.Create(0)
        $action.Path = "powershell.exe"
        $action.Arguments = " -ExecutionPolicy `"Bypass`" -NoProfile -NonInteractive -WindowStyle hidden -File `"$scriptsPath\$logonScript`""

        $taskFolder = $ShedService.GetFolder("\")
        $taskFolder.RegisterTaskDefinition("$client`_Logonscript", $Task , 6, 'Users', $null, 4) | Out-Null
        Write-Host $script:tick -ForegroundColor Green
    }
    else {
        Write-Host "Scheduled task already configured."
    }
}
catch {
    $errMsg = $_.Exception.Message
}
finally {
    if ($errMsg) {
        Write-Warning $errMsg
        Stop-Transcript
        throw $errMsg
    }
    else {
        Write-Host "script completed successfully.."
        "done." | Out-File "$env:temp\$buildId`.txt" -Encoding ASCII -force
        Stop-Transcript
    }
}
#endregion