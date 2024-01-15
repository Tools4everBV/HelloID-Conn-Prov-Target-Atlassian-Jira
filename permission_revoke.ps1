#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Permission-Revoke
#
# Version: 2.0.0 | new-powershell-connector
#####################################################

# Set to true at start, because only when an error occurs it is set to false
$outputContext.Success = $true

# AccountReference must have a value for dryRun
$aRef = $actionContext.References.Account

# The permissionReference object contains the Identification object provided in the retrieve permissions call
$pRef = $actionContext.References.Permission

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

try {    
    if (-Not($actionContext.DryRun -eq $true)) {
        Write-Verbose "Revoking Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]"

        $pair = $actionContext.Configuration.username + ":" + $actionContext.Configuration.password
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{"authorization" = $Key }    

        $url = $actionContext.Configuration.url + "/rest/api/3/group/user?groupId=$($pRef.Reference)&accountId=$aRef"
        $response = Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers
    
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action = "RevokePermission"
            Message = "Revoked Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]"
            IsError = $false
        })
    } else {
        Write-Verbose "DryRun: Would revoke Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)], will be executed during enforcement"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action = "RevokePermission"
            Message = "DryRun: Would revoke Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]"
            IsError = $false
        })
    }
}
catch {
    $ex = $PSItem
    $errorMessage = "Could not revoke Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]. Error: $($ex.Exception.Message)"

    Write-Verbose $errorMessage -Verbose
    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Action = "RevokePermission"
        Message = "Error occurred revoking Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]. Error: $($ex.Exception.Message)"
        IsError = $true
    })
}
finally {
    # Check if auditLogs contains errors, if errors are found, set success to false
    if ($outputContext.AuditLogs.IsError -contains $true) {
        $outputContext.Success = $false
    }
}