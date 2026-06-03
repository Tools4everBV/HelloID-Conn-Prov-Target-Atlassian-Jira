##################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Delete
# PowerShell V2
##################################################

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

function New-AuthorizationHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory)]
        [string]
        $username,

        [parameter(Mandatory)]
        [string]
        $password
    )
    try {    
        # Add the authorization header to the request
        Write-Verbose 'Adding Authorization headers'

        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $pair = $username + ":" + $password
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{
            "authorization" = $key
            "Accept"        = "application/json"
            "Content-Type"  = "application/json"
        } 

        Write-Output $headers  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion

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
        $lifecycleProcess = 'DeleteAccount'
    }
    else {
        $lifecycleProcess = 'NotFound'
    }

    # Process
    switch ($lifecycleProcess) {
        'DeleteAccount' {
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Deleting Atlassian-Jira account with accountReference: [$($actionContext.References.Account)]"

                $splatDeleteParams = @{
                    Uri     = "$($actionContext.Configuration.url)/rest/api/3/user?accountId=$($actionContext.References.Account)"
                    Method  = "DELETE"
                    Headers = $headers
                }
                $null = Invoke-RestMethod @splatDeleteParams

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = "DeleteAccount"
                        Message = "Successfully deleted account with id [$($actionContext.References.Account)]"
                        IsError = $false
                    })                
            }
            else {
                Write-Information "[DryRun] Delete Atlassian-Jira account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            # Make sure to filter out arrays from $outputContext.Data (If this is not mapped to type Array in the fieldmapping). This is not supported by HelloID.
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Delete account: [$($actionContext.References.Account)] was successful. Action initiated by: [$($actionContext.Origin)]"
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
        $auditLogMessage = "Could not delete Atlassian-Jira account: [$($actionContext.References.Account)]. Error: $($errorObj.FriendlyMessage). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not delete Atlassian-Jira account: [$($actionContext.References.Account)]. Error: $($_.Exception.Message). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}