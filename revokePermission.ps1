#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Permission-Revoke
#
# Version: 2.0.0 | new-powershell-connector
#####################################################

# Set to false at start, because only when no error occurs it is set to true
$outputContext.Success = $false

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

#region functions
function New-AuthorizationHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory)]
        [string]
        $username,

        [parameter(Mandatory)]
        [SecureString]
        $password
    )
    try {    
        #Add the authorization header to the request
        Write-Verbose 'Adding Authorization headers'

        $passwordToUse = $password | ConvertFrom-SecureString -AsPlainText

        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $pair = $username + ":" + $passwordToUse
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{
            "authorization" = $Key
            "Accept"        = "application/json"
            "Content-Type"  = "application/json"
        } 

        Write-Output $headers  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion functions

try {    
    [SecureString]$securePassword = ConvertTo-SecureString $actionContext.Configuration.token -AsPlainText -Force
    $headers = New-AuthorizationHeaders -username $actionContext.Configuration.username -password $securePassword 

    if (-Not($actionContext.DryRun -eq $true)) {
        Write-Verbose "Revoking Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]"

        $url = $actionContext.Configuration.url + "/rest/api/3/group/user?groupId=$($pRef.Reference)&accountId=$aRef"
        $response = Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers
    
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "RevokePermission"
                Message = "Revoked Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]"
                IsError = $false
            })
    }
    else {
        Write-Verbose "DryRun: Would revoke Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)], will be executed during enforcement"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "RevokePermission"
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
            Action  = "RevokePermission"
            Message = "Error occurred revoking Jira entitlement: [$($pRef.Reference)] from: [$($personContext.Person.DisplayName)]. Error: $($ex.Exception.Message)"
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-not($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}