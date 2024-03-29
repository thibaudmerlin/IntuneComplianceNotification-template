#region Config
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$client = "Company"
$logPath = "$ENV:ProgramData\$client\Logs"
$logFile = "$logPath\ComplianceNotificationTask.log"
$device = hostname
$errorOccurred = $null
$funcUri = '<funcURI>'
$UserContext = [Security.Principal.WindowsIdentity]::GetCurrent()
$WindirTemp = Join-Path $Env:Windir -Childpath "Temp"

Switch ($UserContext) {
    { $PSItem.Name -Match       "System"    } { Write-Output "Running as System" ; $logPath =  $WindirTemp  }
    { $PSItem.Name -NotMatch    "System"    } { Write-Output "Not running System"  }
    Default { Write-Output "Could not translate Usercontext" }
}
#endregion
#region Functions
 
function Test-WindowsPushNotificationsEnabled() {
	$ToastEnabledKey = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name ToastEnabled -ErrorAction Ignore).ToastEnabled
	if ($ToastEnabledKey -eq "1") {
		Write-Output "Toast notifications are enabled in Windows"
		return $true
	}
	elseif ($ToastEnabledKey -eq "0") {
		Write-Output "Toast notifications are not enabled in Windows. The script will run, but toasts might not be displayed"
		return $false
	}
	else {
		Write-Output "The registry key for determining if toast notifications are enabled does not exist. The script will run, but toasts might not be displayed"
		return $false
	}
}
 
function Display-ToastNotification() {
 
	$Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
	$Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
 
	# Load the notification into the required format
	$ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
	$ToastXml.LoadXml($Toast.OuterXml)
		
	# Display the toast notification
	try {
		Write-Output "All good. Displaying the toast notification"
		[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($App).Show($ToastXml)
	}
	catch { 
		Write-Output "Something went wrong when displaying the toast notification"
		Write-Output "Make sure the script is running as the logged on user"    
	}
	if ($CustomAudio -eq "True") {
		Invoke-Command -ScriptBlock {
			Add-Type -AssemblyName System.Speech
			$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
			$speak.Speak($CustomAudioTextToSpeech)
			$speak.Dispose()
		}    
	}
}
 
function Test-NTSystem() {  
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	if ($currentUser.IsSystem -eq $true) {
		$true
	}
	elseif ($currentUser.IsSystem -eq $false) {
		$false
	}
}
#endregion
#region logging
if (!(Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force
}
Start-Transcript -Path $logFile -Force
#endregion
#region Remediation script
    $isSystem = Test-NTSystem
	if ($isSystem -eq $True) {
		Write-Output "Aborting script, The user is System"
        Exit 1
	}
    $WindowsPushNotificationsEnabled = Test-WindowsPushNotificationsEnabled
    if ($WindowsPushNotificationsEnabled -eq $False) {
		Write-Output "Aborting script, Windows push notification is disabled"
        Exit 1
	}

    #region Get parameters and device compliance state
    $fParams = @{
        Method      = 'Get'
        Uri         = "$funcUri&device=$device"
        ContentType = 'Application/Json'
    }
    $json = Invoke-RestMethod @fParams
    #endregion
    #region parse json
	$isCompliant = $json.isCompliant
    If ($isCompliant -eq $true) {
        Write-Output "The device is compliant : $complianceState"
        Stop-Transcript
        Exit 1
    }
    
    #endregion
    #region check OS version
    $RunningOS = Get-CimInstance -Class Win32_OperatingSystem | Select-Object BuildNumber
    #endregion
    #region add variables values

    $texts = $json.texts
    $images = $json.images
	[datetime]$lastsyncdate = $json.lastSyncDateTime
	$deviceComplianceStatus = $json.deviceComplianceStatus
	$nonCompliantSettings = ""
	foreach ($obj in $deviceComplianceStatus){
		$setting = " "+$obj.setting
		$nonCompliantSettings += $setting
	}
    $AttributionText = $texts.$AttributionText
    $HeaderText = $texts.headerText
    #$TitleText = $texts.titleText
    $BodyText1 = $texts.bodyText1
    $BodyText2 = $texts.bodyText2+$lastsyncdate
    $BodyText3 = $texts.bodyText3+$nonCompliantSettings
	$BodyText4 = $texts.bodyText4
    $Action = $texts.actionUrl
    $ActionButtonContent = $texts.actionButtonContent
    $DismissButtonContent = $texts.dismissButtonContent

	
	if ($RunningOS.BuildNumber -ge "22000"){
        $HeroImage = $images.heroImgW11
    }
    else {
        $HeroImage = $images.heroImgW10
    }
    $LogoImage = $images.logoImg
    #endregion
	$PSAppStatus = "True"
 
	if ($PSAppStatus -eq "True") {
		$RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
		$App = "Microsoft.CompanyPortal_8wekyb3d8bbwe!App"
		
		if (-NOT(Test-Path -Path "$RegPath\$App")) {
			New-Item -Path "$RegPath\$App" -Force
			New-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -Value 1 -PropertyType "DWORD"
		}
		
		if ((Get-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -ErrorAction SilentlyContinue).ShowInActionCenter -ne "1") {
			New-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -Value 1 -PropertyType "DWORD" -Force
		}
	}
 
 
	$CustomAudio = "False"
	$CustomAudioTextToSpeech = $Xml.Configuration.Option | Where-Object {$_.Name -like 'CustomAudio'} | Select-Object -ExpandProperty 'TextToSpeech'
 
	
	$Scenario = "Reminder"
	try {	
	# Formatting the toast notification XML
	# Create the default toast notification XML with action button and dismiss button
	[xml]$Toast = @"
	<toast scenario="$Scenario">
	<visual>
	<binding template="ToastGeneric">
		<image placement="hero" src="$HeroImage"/>
		<image id="1" placement="appLogoOverride" src="$LogoImage"/>
		<text placement="attribution">$AttributionText</text>
		<text>$HeaderText</text>
		<group>
			<subgroup>     
				<text hint-style="body" hint-wrap="true" >$BodyText1</text>
			</subgroup>
		</group>
		<group>
			<subgroup>     
				<text hint-style="body" hint-wrap="true" >$BodyText2</text>
			</subgroup>
		</group>
        <group>
			<subgroup>     
				<text hint-style="body" hint-wrap="true" >$BodyText3</text>
			</subgroup>
		</group>
		<group>
			<subgroup>     
				<text hint-style="body" hint-wrap="true" >$BodyText4</text>
			</subgroup>
		</group>
	</binding>
	</visual>
	<actions>
		<action activationType="protocol" arguments="$Action" content="$ActionButtonContent" />
		<action activationType="system" arguments="dismiss" content="$DismissButtonContent"/>
	</actions>
    <audio src="ms-winsoundevent:Notification.Reminder"/>
	</toast>
"@
	
	Display-ToastNotification
    }
    catch {
    $errorOccurred = $_.Exception.Message
    }
    finally {
    if ($errorOccurred) {
        Write-Warning "Compliance Check Notification completed with errors."
        Stop-Transcript
        Throw $errorOccurred
        Exit 0
    }
    else {
        Write-Host "Compliance Check Notification completed successfully."
        Stop-Transcript
        Exit 0
    }
}
Write-Host "Compliance Check Notification completed successfully."
Stop-Transcript
Exit 0
#endregion