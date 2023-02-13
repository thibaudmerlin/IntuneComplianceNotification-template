#region Config
$client = "Company"
$scriptsPath = "$env:ProgramData\$client\Scripts\ComplianceScript"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceScript-RunOnceConfig.log"
$complianceScript = "ComplianceCheck.ps1"
$complianceNotificationScript = "ComplianceNotification.ps1"
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
if (Test-Path "$scriptsPath\$complianceNotificationScript") {
    Remove-Item -Path "$scriptsPath\$complianceNotificationScript" -Force
}
Start-Transcript -Path "$logFile" -Force
#endregion
#region Logon Script Contents
Write-Host "Creating Compliance script and storing: $scriptsPath\$complianceScript" -ForegroundColor Yellow
Copy-Item "$PSScriptRoot\$complianceScript" -Destination "$scriptsPath\$complianceScript" -Force
Write-Host "Creating Compliance Notification script and storing: $scriptsPath\$complianceNotificationScript" -ForegroundColor Yellow
Copy-Item "$PSScriptRoot\$complianceNotificationScript" -Destination "$scriptsPath\$complianceNotificationScript" -Force
#endregion
#region Scheduled Task
$date = Get-Date -format s
$author = $env:username
$uri = $Client+"_ComplianceCheck"
$ComplianceTaskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Date>$date</Date>
        <Author>$author</Author>
        <URI>\$uri</URI>
    </RegistrationInfo>
    <Triggers>
        <BootTrigger>
            <Repetition>
                <Interval>PT15M</Interval>
                <StopAtDurationEnd>false</StopAtDurationEnd>
            </Repetition>
            <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
            <Enabled>true</Enabled>
            <Delay>PT1M</Delay>
        </BootTrigger>
    </Triggers>
    <Principals>
        <Principal id="Author">
            <UserId>S-1-5-18</UserId>
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Settings>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
        <AllowHardTerminate>true</AllowHardTerminate>
        <StartWhenAvailable>false</StartWhenAvailable>
        <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
        <IdleSettings>
            <StopOnIdleEnd>true</StopOnIdleEnd>
            <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <Enabled>true</Enabled>
        <Hidden>false</Hidden>
        <RunOnlyIfIdle>false</RunOnlyIfIdle>
        <WakeToRun>false</WakeToRun>
        <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
        <Priority>7</Priority>
    </Settings>
    <Actions Context="Author">
        <Exec>
            <Command>powershell.exe</Command>
            <Arguments>-ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle hidden -File $scriptsPath\$complianceScript</Arguments>
        </Exec>
    </Actions>
</Task>
"@

try {
    Write-Host "Setting up scheduled task"
    if ((Get-ScheduledTask -TaskName "$client`_ComplianceCheck" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        Get-ScheduledTask -TaskName "$client`_ComplianceCheck" -TaskPath "\" | Unregister-ScheduledTask -Confirm:$false
        Write-Host "Scheduled Task already configured, deleting..." -ForegroundColor Yellow
    }
    if ((Get-ScheduledTask -TaskName "$client`_ComplianceNotification" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        Get-ScheduledTask -TaskName "$client`_ComplianceNotification" -TaskPath "\" | Unregister-ScheduledTask -Confirm:$false
        Write-Host "Scheduled Task already configured, deleting..." -ForegroundColor Yellow
    }
#register compliance sync task
    Register-ScheduledTask -TaskName "$client`_ComplianceCheck" -Xml $ComplianceTaskXml -Force
#register compliance notification task
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
    $trigger.Delay="PT3M" # 3 minutes
    $trigger.Id="Startup Trigger"
    $action = $Task.Actions.Create(0)
    $action.Path = "powershell.exe"
    $action.Arguments = " -ExecutionPolicy `"Bypass`" -NoProfile -NonInteractive -WindowStyle hidden -File `"$scriptsPath\$complianceNotificationScript`""
    $taskFolder = $ShedService.GetFolder("\")
    $taskFolder.RegisterTaskDefinition("$client`_ComplianceNotification", $Task , 6, 'Users', $null, 4) | Out-Null
    Write-Host $script:tick -ForegroundColor Green
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