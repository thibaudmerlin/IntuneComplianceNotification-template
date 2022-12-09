using namespace System.Net

# Input bindings are passed in via param block.
param(
    $Request, 
    $TriggerMetadata
)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$device = $Request.Query.Device
if (-not $device) {
    $device = $Request.Body.Device
}
if (Test-Path "$env:HOME/site/wwwroot/pwexpnotifqry/confqry.json") {
    $jsonPath = "$env:HOME/site/wwwroot/pwexpnotifqry/confqry.json"
    $cfgPath = Get-Content $jsonPath -raw
    $parameters = $ExecutionContext.InvokeCommand.ExpandString( $cfgPath ) | ConvertFrom-Json
}
else {
    $jsonPath = "$PSScriptRoot/confqry.json"
    $cfgPath = Get-Content $jsonPath -raw
    $parameters = $ExecutionContext.InvokeCommand.ExpandString( $cfgPath ) | ConvertFrom-Json -Depth 20
}
$hash = (Get-FileHash $jsonPath).Hash
$hashCheck = $hash.Substring($hash.Length - 6, 6)
$parameters
#region Functions
function Get-AuthHeader {
    param (
        [Parameter(mandatory = $true)]
        [string]$tenant_id,
        [Parameter(mandatory = $true)]
        [string]$client_id,
        [Parameter(mandatory = $true)]
        [string]$client_secret,
        [Parameter(mandatory = $true)]
        [string]$resource_url
    )
    $body = @{
        resource      = $resource_url
        client_id     = $client_id
        client_secret = $client_secret
        grant_type    = "client_credentials"
        scope         = "openid"
    }
    try {
        $response = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$tenant_id/oauth2/token" -Body $body -ErrorAction Stop
        $headers = @{ }
        $headers.Add("Authorization", "Bearer " + $response.access_token)
        return $headers
    }
    catch {
        Write-Error $_.Exception
    }
}
Function Get-JsonFromGraph {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]    
        $token,
        [Parameter(Mandatory = $true)]
        $strQuery,
        [parameter(mandatory = $true)] [ValidateSet('v1.0', 'beta')]
        $ver

    )
    #proxy pass-thru
    $webClient = new-object System.Net.WebClient
    $webClient.Headers.Add("user-agent", "PowerShell Script")
    $webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

    try { 
        $header = $token
        if ($header) {
            #create the URL
            $url = "https://graph.microsoft.com/$ver/$strQuery"
        
            #Invoke the Restful call and display content.
            Write-Verbose $url
            $query = Invoke-RestMethod -Method Get -Headers $header -Uri $url -ErrorAction STOP
            if ($query) {
                if ($query.value) {
                    #multiple results returned. handle it
                    $query = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$ver/$strQuery" -Headers $header
                    $result = @()
                    while ($query.'@odata.nextLink') {
                        Write-Verbose "$($query.value.Count) objects returned from Graph"
                        $result += $query.value
                        Write-Verbose "$($result.count) objects in result array"
                        $query = Invoke-RestMethod -Method Get -Uri $query.'@odata.nextLink' -Headers $header
                    }
                    $result += $query.value
                    Write-Verbose "$($query.value.Count) objects returned from Graph"
                    Write-Verbose "$($result.count) objects in result array"
                    return $result
                }
                else {
                    #single result returned. handle it.
                    $query = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/$ver/$strQuery" -Headers $header
                    return $query
                }
            }
            else {
                $errorMsg = @{
                    errNumber = 404
                    errMsg    = "No results found. Either there literally is nothing there or your query was malformed."
                }
            }
            throw;
        }
        else {
            $errorMsg = @{
                errNumber = 401
                errMsg    = "Authentication Failed during attempt to create Auth header."
            }
            throw;
        }
    }
    catch {
        return $errorMsg
    }
}
#endregion

#region Process
$params = @{
    tenant_id = $env:tenant_id
    client_id = $env:client_id
    client_secret = $env:client_secret
    resource_url = "https://graph.microsoft.com"
}
    $token = Get-AuthHeader @params
if ($device) {
    $status = [HttpStatusCode]::OK
    $deviceQuery = "deviceManagement/managedDevices?`$filter=startswith(deviceName,'{0}')&`$select=id" -f $device
    $deviceId = (Get-JsonFromGraph -token $token -strQuery $deviceQuery -ver v1.0).id
    $deviceQuery
    $device
    $deviceId
    if ($deviceId) {
        $managedDeviceQuery = "deviceManagement/managedDevices/{0}" -f $deviceId
        $managedDevice = (Get-JsonFromGraph -token $token -strQuery $managedDeviceQuery -ver v1.0)
    }
    $aadDeviceQuery = "devices?`$filter=startswith(displayName,'{0}')&`$select=id" -f $device
    $aadDeviceId = (Get-JsonFromGraph -token $token -strQuery $aadDeviceQuery -ver v1.0).id
    $aadDeviceQuery
    $aadDeviceId
    if ($aadDeviceId) {
        $managedAadDeviceQuery = "devices/{0}" -f $aadDeviceId
        $managedAadDevice = (Get-JsonFromGraph -token $token -strQuery $managedAadDeviceQuery -ver v1.0)
    }
#region if not compliant
    $deviceId = $deviceId | select-object -Unique

    foreach ($devId in $deviceId) {
        # get list of all compliance policies of this particular device
        $deviceCompliancePolicyQuery = "deviceManagement/managedDevices('{0}')/deviceCompliancePolicyStates" -f $deviceId
        $deviceCompliancePolicy = (Get-JsonFromGraph -token $token -strQuery $deviceCompliancePolicyQuery -ver beta)
        if ($deviceCompliancePolicy) {
            # get detailed information for each compliance policy (mainly errorDescription)
            $deviceCompliancePolicy | ForEach-Object {
                $deviceComplianceId = $_.id
                $deviceComplianceStatusQuery = "deviceManagement/managedDevices('$devId')/deviceCompliancePolicyStates('$deviceComplianceId')/settingStates"
                $deviceComplianceStatus = (Get-JsonFromGraph -token $token -strQuery $deviceComplianceStatusQuery -ver beta)

                if ($justProblematic) {
                    $deviceComplianceStatus = $deviceComplianceStatus | Where-Object { $_.state -ne "compliant" }
                }
                $deviceComplianceStatus | Select-Object @{n = 'deviceName'; e = { $device } }, state, errorDescription, userPrincipalName , setting, sources
            }
        } else {
            Write-Warning "There are no compliance policies for $devId device"
        }
    }

#endregion

    $txtToMap = $parameters.texts
    $imgToMap = $parameters.images
    $result = [PSCustomObject]@{
        hash                        = $hashCheck
        lastSyncDateTime      = $managedDevice.lastSyncDateTime
        complianceState          = $managedDevice.complianceState
        isCompliant              = $managedAadDevice.isCompliant
        texts                       = $txtToMap | Where-Object { $_ }
        images                      = $imgToMap | Where-Object { $_ }
        deviceId                    = $deviceId
        deviceComplianceStatus      = $deviceComplianceStatus | Where-Object { $_ }
    }
}
else {
    $status = [HttpStatusCode]::BadRequest
    $result = @{"Error" = "Please pass a name on the query string or in the request body."} | ConvertTo-Json
}
#endregion
#region output
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $status
        Body       = $result
    })
#endregion