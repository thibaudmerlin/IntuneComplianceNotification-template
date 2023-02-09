BeforeDiscovery {
    function Get-TestEnv {
        [cmdletbinding()]
        param (
            $envVar
        )
        $localEnv = get-content ".\tests\.localenv" -Raw | ConvertFrom-Json
        return $localEnv.$envVar
    }
    if (!$env:FA_ENDPOINT_UAT) {
        $env:FA_ENDPOINT_UAT = Get-TestEnv 'endpoint'
    }
    if (!$env:SAMPLE_DEVICE) {
        $env:SAMPLE_DEVICE = Get-TestEnv 'device'
    }
    if (!$env:JSON_PATH) {
        $env:JSON_PATH = ".\function-app\pw-exp-notif-qry\confqry.json"
    }
}
Describe "Function App Call" {
    Context "Checking result of REST call" {
        BeforeAll {
            $iwr = Invoke-WebRequest -Method Get -Uri "$($env:FA_ENDPOINT_UAT)&device=$env:SAMPLE_DEVICE"
            $toMap = $iwr.Content | ConvertFrom-Json
            $hash = (Get-FileHash "$env:JSON_PATH").Hash
            $hashCheck = $hash.Substring($hash.Length -6, 6)
        }
        it 'Function call should return 200' { $iwr.StatusCode | Should -Be 200 }
        it 'Function content should be well formed JSON' { $toMap | should -Not -Be $null }
        it 'We should have some compliance state' { $toMap.complianceState.count | Should -Not -Be $null }
        it 'The configuration JSON should match' { $hashCheck | should -Be $toMap.hash}
    }
}