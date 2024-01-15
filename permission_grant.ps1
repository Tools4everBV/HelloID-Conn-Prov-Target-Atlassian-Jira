#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Permission-Grant
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

        $passwordToUse = $password | ConvertFrom-SecureString -AsPlainText -Force

        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $pair = $username + ":" + $passwordToUse
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{
            "authorization" = $Key
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        } 

        Write-Output $headers  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion functions

try {    
    [Security.SecureString]$securePassword = ConvertTo-SecureString $actionContext.Configuration.password -AsPlainText -Force
    $headers = New-AuthorizationHeaders -username $actionContext.Configuration.username -password $securePassword 

    if (-Not($actionContext.DryRun -eq $true)) {
        Write-Verbose "Granting Jira entitlement: [$($pRef.Reference)] to: [$($personContext.Person.DisplayName)] $aRef"

        $body = @{
            accountId = "$aRef"
        }

        $bodyJson = $body | ConvertTo-Json

        $url = $actionContext.Configuration.url + "rest/api/3/group/user?groupId=$($pRef.Reference)"

        Write-Verbose -Verbose $url
        Write-Verbose -Verbose $bodyJson
        $response = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $bodyJson
    
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action = "GrantPermission"
            Message = "Grant Jira entitlement: [$($pRef.Reference)] to: [$($personContext.Person.DisplayName)]"
            IsError = $false
        })
    } else {
        Write-Verbose "DryRun: Would grant Jira entitlement: [$($pRef.Reference)] to: [$($personContext.Person.DisplayName)], will be executed during enforcement"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action = "GrantPermission"
            Message = "DryRun: Would grant Jira entitlement: [$($pRef.Reference)] to: [$($personContext.Person.DisplayName)]"
            IsError = $false
        })
    }
}
catch {
    $ex = $PSItem
    $errorMessage = "Could not grant Jira entitlement: [$($pRef.Reference)] to: [$($personContext.Person.DisplayName)]. Error: $($ex.Exception.Message)"

    Write-Verbose $errorMessage -Verbose
    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Action = "GrantPermission"
        Message = "Error occurred granting Jira entitlement: [$($pRef.Reference)] to: [$($personContext.Person.DisplayName)]. Error: $($ex.Exception.Message)"
        IsError = $true
    })
}
finally {
    # Check if auditLogs contains errors, if errors are found, set success to false
    if ($outputContext.AuditLogs.IsError -contains $true) {
        $outputContext.Success = $false
    }
}