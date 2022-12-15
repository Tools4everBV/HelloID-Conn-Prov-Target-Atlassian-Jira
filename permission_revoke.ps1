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
                Message = "Revoke Jira entitlement: [$($pRef.Reference)] from: [$($p.DisplayName)], will be executed during enforcement"
            })
    }
    
    if (-not($dryRun -eq $true)) {
        Write-Verbose "Revoking Jira entitlement: [$($pRef.Reference)] from: [$($p.DisplayName)]"

        $pair = $config.username + ":" + $config.password
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{"authorization" = $Key }    

       

        $url = $config.url + "/rest/api/3/group/user?groupId=$($pRef.Reference)&accountId=$aRef"
        $response = Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers
    
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "Revoke Jira entitlement: [$($pRef.Reference)] from: [$($p.DisplayName)] was successful."
                IsError = $false
            })
    }
}
catch {
    $success = $false
    $ex = $PSItem
    $errorMessage = "Could not revoke Jira entitlement: [$($pRef.Reference)] from: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"

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