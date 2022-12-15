$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

$VerbosePreference = 'Continue'

try {
    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "Grant Jira entitlement: [$($pRef.Reference)] to: [$($p.DisplayName)], will be executed during enforcement"
            })
    }
    
    if (-not($dryRun -eq $true)) {
        Write-Verbose "Granting Jira entitlement: [$($pRef.Reference)] to: [$($p.DisplayName)] $aRef"

        $pair = $config.username + ":" + $config.password
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{
            "authorization" = $Key
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        }    

        $body = @{
            accountId = "$aRef"
        }

        $bodyJson = $body | ConvertTo-Json

        $url = $config.url + "rest/api/3/group/user?groupId=$($pRef.Reference)"

        Write-Verbose -Verbose $url
        Write-Verbose -Verbose $bodyJson
        $response = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $bodyJson
    
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "Grant Jira entitlement: [$($pRef.Reference)] to: [$($p.DisplayName)] was successful."
                IsError = $false
            })
    }
}
catch {
    $success = $false
    $ex = $PSItem
    $errorMessage = "Could not grant Jira entitlement: [$($pRef.Reference)] to: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"

    Write-Verbose $errorMessage -Verbose
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
}
finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}