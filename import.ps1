#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Import
# PowerShell V2
#####################################################

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
#endregion functions

try {
    $splatHeaderParams = @{
        username = $actionContext.Configuration.username
        password = $actionContext.Configuration.token
    }
    $headers = New-AuthorizationHeaders @splatHeaderParams
    
    # Paginering instellingen
    $startAt = 0
    $maxResults = 500

    do {
        $splatImportParams = @{
            Uri         = "$($actionContext.Configuration.url)/rest/api/3/users/search?startAt=$startAt&maxResults=$maxResults"
            Method      = "GET"
            ContentType = "application/json"
            Headers     = $headers
        }
        $importedAccounts = Invoke-RestMethod @splatImportParams

        foreach ($importedAccount in $importedAccounts) {
    
            $data = @{}
            foreach ($field in $actionContext.ImportFields) {
                $data[$field] = $importedAccount.$field
            }
   
            Write-Output @{
                AccountReference = $importedAccount.accountId
                displayName      = $importedAccount.displayName
                UserName         = if (!([string]::IsNullOrEmpty($importedAccount.emailAddress))) { $importedAccount.emailAddress } else { $importedAccount.accountId }
                Enabled          = $importedAccount.active
                Data             = $data
            }
        }

        $startAt += $maxResults

    } while ($importedAccounts.Count -eq $maxResults)
} 
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Atlassian-JiraError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import Atlassian-Jira account entitlements. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Atlassian-Jira account entitlements. Error: $($ex.Exception.Message)"
    }
}