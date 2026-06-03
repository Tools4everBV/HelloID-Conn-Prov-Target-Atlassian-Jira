#################################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-RevokePermission-Group
# PowerShell V2
#################################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-Atlassian-JiraError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            
            # Extract Jira-specific error messages
            $friendlyMessageParts = [System.Collections.Generic.List[string]]::new()
            
            # Check for errorMessages array (common in Jira API responses)
            if ($errorDetailsObject.PSObject.Properties.Name -contains 'errorMessages') {
                foreach ($errorMessage in $errorDetailsObject.errorMessages) {
                    if (-not [string]::IsNullOrEmpty($errorMessage)) {
                        $friendlyMessageParts.Add($errorMessage)
                    }
                }
            }
            
            # Check for errors object with field-specific errors
            if ($errorDetailsObject.PSObject.Properties.Name -contains 'errors') {
                foreach ($errorProperty in $errorDetailsObject.errors.PSObject.Properties) {
                    $fieldName = $errorProperty.Name
                    $fieldError = $errorProperty.Value
                    if (-not [string]::IsNullOrEmpty($fieldError)) {
                        $friendlyMessageParts.Add("[$fieldName]: $fieldError")
                    }
                }
            }
            
            # Check for single message property
            if ($errorDetailsObject.PSObject.Properties.Name -contains 'message') {
                if (-not [string]::IsNullOrEmpty($errorDetailsObject.message)) {
                    $friendlyMessageParts.Add($errorDetailsObject.message)
                }
            }
            
            # Combine all error messages or fall back to raw error details
            if ($friendlyMessageParts.Count -gt 0) {
                $httpErrorObj.FriendlyMessage = $friendlyMessageParts -join '; '
            }
            else {
                $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}
#endregion

# Begin
try {
    # Verify if [accountReference] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    $splatHeaderParams = @{
        username = $actionContext.Configuration.username
        password = $actionContext.Configuration.token
    }
    $headers = New-AuthorizationHeaders @splatHeaderParams

    Write-Information 'Verifying if a Atlassian-Jira account exists'
    $splatCorrelateParams = @{
        Uri         = "$($actionContext.Configuration.url)/rest/api/3/user?accountId=$($actionContext.References.Account)"
        Method      = "GET"
        ContentType = "application/json"
        Headers     = $headers
    }
    $correlatedAccount = Invoke-RestMethod @splatCorrelateParams

    if ($null -ne $correlatedAccount) {
        $lifecycleProcess = 'RevokePermission'
    }
    else {
        $lifecycleProcess = 'NotFound'
    }

    # Process
    switch ($lifecycleProcess) {
        'RevokePermission' {

            # Make sure to test with special characters and if needed; add utf8 encoding.
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Revoking Atlassian-Jira permission: [$($actionContext.PermissionDisplayName)] - [$($actionContext.References.Permission.Reference)]"

                $splatRevokeParams = @{
                    Uri     = "$($actionContext.Configuration.url)/rest/api/3/group/user?groupId=$($actionContext.References.Permission.Reference)&accountId=$($actionContext.References.Account)"
                    Method  = "DELETE"
                    Headers = $headers
                }
                $null = Invoke-RestMethod @splatRevokeParams
            }
            else {
                Write-Information "[DryRun] Revoke Atlassian-Jira permission: [$($actionContext.PermissionDisplayName)] - [$($actionContext.References.Permission.Reference)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Revoke permission: [$($actionContext.PermissionDisplayName)] from [$($actionContext.References.Account)] was successful. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "Atlassian-Jira account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Atlassian-Jira account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }
    }
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Atlassian-JiraError -ErrorObject $ex
        $auditLogMessage = "Could not revoke Atlassian-Jira permission for account: [$($actionContext.References.Account)]. Error: $($errorObj.FriendlyMessage). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not revoke Atlassian-Jira permission for account: [$($actionContext.References.Account)]. Error: $($_.Exception.Message). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}