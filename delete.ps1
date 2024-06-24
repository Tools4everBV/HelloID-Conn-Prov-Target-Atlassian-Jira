#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Delete
#
# Version: 3.0.0 | api changes
#####################################################

# Set to false at start, because only when no error occurs it is set to true
$outputContext.Success = $false

$aRef = $actionContext.References.Account

# done in field mapping
$account = $actionContext.Data

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

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
        if ([string]::IsNullOrEmpty($aRef) -eq $false) {
            $url = $actionContext.Configuration.url + "/rest/api/3/user?accountId=" + $aRef
            $response = Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "DeleteAccount"
                    Message = "Successfully deleted account with id [$aRef]"
                    IsError = $false
                })
        }
    }
    else {
        Write-Verbose "DryRun: Would delete account [$($account | ConvertTo-Json)]"
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "DeleteAccount"
                Message = "DryRun: Would delete account with id [$aRef]"
                IsError = $false
            })
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {

        if (-Not [string]::IsNullOrEmpty($ex.ErrorDetails.Message)) {
            $errorMessage = "Could not delete account. Error: $($ex.ErrorDetails.Message)"
        }
        else {
            $errorMessage = "Could not delete account. Error: $($ex.Exception.Message)"
        }
    }
    else {
        $errorMessage = "Could not delete account. Error: $($ex.Exception.Message) $($ex.ScriptStackTrace)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "Delete Account"
            Message = "Error occurred when deleting account. Error Message: $($errorMessage.AuditErrorMessage)"
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-not($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}