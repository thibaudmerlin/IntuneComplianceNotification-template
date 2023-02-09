#region Config
$client = "Company"
$scriptsPath = "$env:ProgramData\$client\Scripts\ComplianceScript"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceScript-RunOnceConfig.log"
$complianceScript = "ComplianceCheck.ps1"
$complianceNotificationScript = "remediationScript.ps1"
$buildId = "afd21f58-9c02-41b0-87a6-95745bd02153"
#endregion
#region Logging
if (!(Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -Type Directory -Force | Out-Null
}
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

if (Test-Path "$scriptsPath\$complianceScript") {
    Remove-Item -Path "$scriptsPath\$complianceScript" -Force
}
Start-Transcript -Path "$logFile" -Force
#endregion
#region Logon Script Contents
Write-Host "Creating Compliance script and storing: $scriptsPath\$complianceScript" -ForegroundColor Yellow
Copy-Item "$PSScriptRoot\$complianceScript" -Destination "$scriptsPath\$complianceScript" -Force
#endregion
#region Scheduled Task
try {
    Write-Host "Setting up scheduled task"
    if (!(Get-ScheduledTask -TaskName "$client`_Compliance" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        $ShedService = New-Object -comobject 'Schedule.Service'
        $ShedService.Connect()

        $Task = $ShedService.NewTask(0)
        $Task.RegistrationInfo.Description = "Compliance Script for $client"
        $Task.Settings.Enabled = $true
        $Task.Settings.AllowDemandStart = $true
        $Task.Settings.IdleSettings.StopOnIdleEnd = $false
        $Task.Settings.RunOnlyIfIdle = $false
        $Task.Settings.DisallowStartIfOnBatteries = $false
        $Task.Settings.StopIfGoingOnBatteries = $false

        $trigger = $task.triggers.Create(9)
        $trigger.Enabled = $true
        $trigger.Delay="PT2M" # 2 minutes
        $trigger.Id="Startup Trigger"

        $action.Path = "powershell.exe"
        $action.Arguments = " -ExecutionPolicy `"Bypass`" -NoProfile -NonInteractive -WindowStyle hidden -File `"$scriptsPath\$complianceNotificationScript`""

        $taskFolder = $ShedService.GetFolder("\")
        $taskFolder.RegisterTaskDefinition("$client`_Compliance", $Task , 6, 'Users', $null, 4) | Out-Null
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