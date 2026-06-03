#################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Create
# PowerShell V2
#################################################

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
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    $splatHeaderParams = @{
        username = $actionContext.Configuration.username
        password = $actionContext.Configuration.token
    }
    $headers = New-AuthorizationHeaders @splatHeaderParams

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        # Determine if a user needs to be [created] or [correlated]
        $splatCorrelateParams = @{
            Uri         = "$($actionContext.Configuration.url)/rest/api/3/user/search?query=$correlationValue"
            Method      = "GET"
            ContentType = "application/json"
            Headers     = $headers
        }
        $correlatedAccount = Invoke-RestMethod @splatCorrelateParams

        if (($correlatedAccount | Measure-Object).Count -eq 1) {
            $lifecycleProcess = 'CorrelateAccount'
            $correlatedAccount = $correlatedAccount | Select-Object -First 1
        }
        elseif (($correlatedAccount | Measure-Object).Count -eq 0) {
            $lifecycleProcess = 'CreateAccount'
        }
        elseif (($correlatedAccount | Measure-Object).Count -gt 1) {               
            Throw "Multiple accounts found with $correlationField [$correlationValue]. Cannot correlate account."
        }
    }

    # Process
    switch ($lifecycleProcess) {
        'CreateAccount' {
            $splatCreateParams = @{
                Uri         = "$($actionContext.Configuration.url)/rest/api/3/user"
                Body        = $actionContext.Data | ConvertTo-Json
                Method      = "Post"
                ContentType = "application/json"
                Headers     = $headers
            }

            # Make sure to test with special characters and if needed; add utf8 encoding.
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating Atlassian-Jira account'
                $response = Invoke-RestMethod @splatCreateParams

                $createdAccount = [PSCustomObject]@{
                    displayName  = $response.displayName
                    emailAddress = $response.emailAddress
                    name         = $response.name
                }
                $outputContext.Data = $createdAccount
                $outputContext.AccountReference = $createdAccount.accountId
                    
            }
            else {
                Write-Information '[DryRun] Create and correlate Atlassian-Jira account, will be executed during enforcement'
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating Atlassian-Jira account'

            # Make sure to filter out arrays from $outputContext.Data (If this is not mapped to type Array in the fieldmapping). This is not supported by HelloID.
            $outputContext.Data = $correlatedAccount
            $outputContext.AccountReference = $correlatedAccount.accountId
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $lifecycleProcess
            Message = $auditLogMessage
            IsError = $false
        })
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Atlassian-JiraError -ErrorObject $ex
        $auditLogMessage = "Could not create or correlate Atlassian-Jira account: [$($actionContext.References.Account)]. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not create or correlate Atlassian-Jira account: [$($actionContext.References.Account)]. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}