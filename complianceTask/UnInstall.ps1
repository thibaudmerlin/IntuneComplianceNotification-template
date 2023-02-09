#region Config
$client = "Company"
$scriptsPath = "$env:ProgramData\$client\Scripts\ComplianceScript\"
$logPath = "$env:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceScript-UnInstall.log"
$buildId = "afd21f58-9c02-41b0-87a6-95745bd02153"
#endregion
#region Logging
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}
Start-Transcript -Path "$logFile" -Force
#endregion
#region Scheduled Task
try {
    Write-Verbose "Deletting scheduled tasks"
    if ((Get-ScheduledTask -TaskName "$client`_ComplianceCheck" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName "$client`_ComplianceCheck" -Confirm:$false
        Write-Verbose "Scheduled task deleted successfully"
        if (Test-Path "$scriptsPath") {
            Remove-Item -Path "$scriptsPath" -Force -Recurse
            Write-Verbose "Scripts deleted successfully"
        }
    }
    else {
        Write-Verbose "Scheduled task ComplianceCheck already deleted."
    }
    if ((Get-ScheduledTask -TaskName "$client`_ComplianceNotification" -TaskPath "\" -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName "$client`_ComplianceNotification" -Confirm:$false
        Write-Verbose "Scheduled task deleted successfully"
        if (Test-Path "$scriptsPath") {
            Remove-Item -Path "$scriptsPath" -Force -Recurse
            Write-Verbose "Scripts deleted successfully"
        }
    }
    else {
        Write-Verbose "Scheduled task ComplianceNotification already deleted."
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