#region Config
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$client = "Kyos"
$logPath = "$ENV:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceCheckDetection.log"
$device = hostname
$funcUri = 'https://kyoscompliancecheck.azurewebsites.net/api/comp-notif-qry?code=ywVBor5v_z5s6PRAh-zZxm0auuZ-0rqTG5DGqgKY7xJqAzFupFsODA=='
$UserContext = [Security.Principal.WindowsIdentity]::GetCurrent()
$WindirTemp = Join-Path $Env:Windir -Childpath "Temp"
 
Switch ($UserContext) {
    { $PSItem.Name -Match       "System"    } { Write-Output "Running as System" ; $logPath =  $WindirTemp }
    { $PSItem.Name -NotMatch    "System"    } { Write-Output "Not running System" }
    Default { Write-Output "Could not translate Usercontext" }
}
Write-Host $device
#endregion
#region logging
if (!(Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force
}
Start-Transcript -Path $logFile -Force
#endregion
#region Remediation script

#region Get parameters and user pw timespan
    $fParams = @{
        Method      = 'Get'
        Uri         = "$funcUri&device=$device"
        ContentType = 'Application/Json'
    }
    $json = Invoke-RestMethod @fParams
#endregion
#region check compliance with Intune attribute
    $complianceState = $json.complianceState
    If ($complianceState -ne "compliant") {
        Write-Output "The device is not compliant : $complianceState"
        Stop-Transcript
        Exit 1
    }
    else {
        Write-Output "The device is compliant"
        Stop-Transcript
        Exit 0
    }
#endregion


