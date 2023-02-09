![Icon-KYOS-Apps-256px](https://user-images.githubusercontent.com/107478270/217793968-32c87952-1520-46f6-8d70-edb4bb54b5e2.png)
# Compliance Check, Notification and Remdiation FunctionApp and Proactive Remediation/Scheduled Tasks - Intune

- Azure Function App to serve as midddleware for a compliance notif solution for cloud managed devices with Proactive Remediation and/or Scheduled Tasks
- Tested on Windows 10 and Windows 11

# Problem
- You configured compliance policies in Intune
- You configured Conditionnal Access rules to block access if the device is not compliant
- Your devices are Cloud managed (Intune)
- Sometimes your users complain about lossing their access to Online Tools without any clue and/or notif

# Solution
- The app function parse all device compliance state and return if it's compliant or not
- The proactive remediation show a toast notification  to the user if the device is not compliant, show wgich setting is not compliant, then add a shorcut to the company portal to sync settings ans poilcies
- The scheduled task ComplianceNotification has the same behavior than the proactive remediation but launch at logon of any user with a 2mn delay (can be changed)
- The scheduled task ComplianceCheck parse the windows event logs to searcg any AADSTS53003 errors, then launch the sync task 'Schedule to run OMADMClient by client' and try to evaluate the compliance policies by using "intunemanagementextension://synccompliance" and also launch the task ComplianceNotification to notify the user, this task scheduled every 15mn and parse the last 15mn windows events. This is the only i found to detect any AADSTS53003 error, XPath is not capable to filter event description
You can use proactive remediation only, or scheduled task only or both, as you whish :)
# Installation
## 1. Create App Registration
- Create a new App Registration in AzureAD, name Company-DeviceComplianceNotif (Single Tenant, no redirect uri)
- Add API permissions : Directory.Read.All (application), DeviceManagementConfiguration.Read.All (application), DeviceManagementManagedDevice.Read.All (application)
- Create a secret and save the value
- Save the Client(app) ID, save the Tenant ID

## 2. Create an Azure Function
<img width="550" alt="image" src="https://user-images.githubusercontent.com/107478270/202721339-711e5cbf-b2e2-429a-92e6-bdac6daf528a.png">

- Add App Insight to monitor the function
- Create a slot for UAT
- Create environment variables for PRD and UAT (in configuration) :
    - client_id = yourclientID
    - client_secret = yourclientSecret
    - tenant_id = yourtenantID
- *Optional : you can enforce certificate auth in the azure function in strict env.

## 3. Clone the github repo
- Clone this repository
- *Optional : Create the env. variable for pipeline

## 4. Customize the files for the customer and deploy the function
- Connect VSCode to the GitHub repo
- Add desired paramters in the confqry.json (respect the schema)
    - You can use online images, just replace image path with http path (hero and/or logo)
    - You can create a public azure blob account and put image there (logo : 128px is the good size)
- Deploy the function to UAT by using Azure Functions:Deploy to Slot... in VSCode
- If tests are ok, deploy it to PRD by using Azure Functions:Deploy to Function App... in VSCode
- Gather the function URI and save it
- Change variable in remediation scripts ($client, $funcUri)

## 5. Package the win32 app and deploy it to devices
- Donwload [win32 prep tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)
- Put all the files into the complianceTask folder in the intunewin package
- Deploy the App in intune and use the commands :
    - Install Command : Powershell.exe -ExecutionPolicy ByPass -File .\Install.ps1
    - Uninstall Command : Powershell.exe -ExecutionPolicy ByPass -File .\UnInstall.ps1
## 6. Create the proactive remediation in Intune
- Create a proactive remediation with these parameters :
    - Execute in User Context : Yes
    - Execute in Powershell64bits : Yes
- Assign it and don't forget to setup the schedule (each hour) 
- Grab a coffee and wait :)
# Folder overview
- complianceTask contains all files to be packaged to deploy an app in Intune to register all desired scheduled tasks
- function-app contains the function app code that will be deployed to Azure
- proactive-remediation contains the code that will be packaged and deployed via Intune ProActive Remediation
- tests contains the pester tests to be used for interactive testing OR ci/cd deployment

# Pre-Reqs for local function app development and deployment

To develop and deploy the function app contained within this repository, please make sure you have the following reqs on your development environment.

- [Visual Studio Code](https://code.visualstudio.com/)
- The [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) version 2.x or later. The Core Tools package is downloaded and installed automatically when you start the project locally. Core Tools includes the entire Azure Functions runtime, so download and installation might take some time.
- [PowerShell 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows) recommended.
- Both [.NET Core 3.1](https://www.microsoft.com/net/download) runtime and [.NET Core 2.1 runtime](https://dotnet.microsoft.com/download/dotnet-core/2.1).
- The [PowerShell extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell).
- The [Azure Functions extension for Visual Studio Code](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=powershell#install-the-azure-functions-extension)
- The [Pester Tests extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=pspester.pester-test)
- The [Pester Tests Explorer extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=TylerLeonhardt.vscode-pester-test-adapter)
