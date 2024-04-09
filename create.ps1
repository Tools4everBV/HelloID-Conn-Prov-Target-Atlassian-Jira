#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Create
#
# Version: 2.0.0 | new-powershell-connector
#####################################################

# Set to false at start, because only when no error occurs it is set to true
$outputContext.Success = $false

# AccountReference must have a value for dryRun
$outputContext.AccountReference = "Unknown"

# done in field mapping
$account = $actionContext.Data

$action = ""
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
    [SecureString]$securePassword = ConvertTo-SecureString $actionContext.Configuration.password -AsPlainText -Force
    $headers = New-AuthorizationHeaders -username $actionContext.Configuration.username -password $securePassword

    # Check if we should try to correlate the account
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $action = "correlate"
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ([string]::IsNullOrEmpty($correlationField)) {
            Write-Warning "Correlation is enabled but not configured correctly."
            Throw "Correlation is enabled but not configured correctly."
        }

        if ([string]::IsNullOrEmpty($correlationValue)) {
            Write-Warning "The correlation value for [$correlationField] is empty. This is likely a scripting issue."
            Throw "The correlation value for [$correlationField] is empty. This is likely a scripting issue."
        }

        # get object
        if ([string]::IsNullOrEmpty($($account.$correlationValue)) -eq $false) {
            $url = $actionContext.Configuration.url + "/rest/api/3/user/search?query=" + $($account.$correlationValue)
            $response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

            if (($response | Measure-Object).Count -eq 1) {
                if (-Not($actionContext.DryRun -eq $true)) {
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = "CorrelateAccount"
                        Message = "Correlated account with id [$($response.accountId)] on field $($correlationField) with value $($correlationValue)"
                        IsError = $false
                    })
                } else {
                    Write-Warning "DryRun: Would correlate account [$($personContext.Person.DisplayName)] on field [$($correlationField)] with value [$($correlationValue)]"
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = "CorrelateAccount"
                        Message = "DryRun: Would correlate account [$($personContext.Person.DisplayName)] on field [$($correlationField)] with value [$($correlationValue)]"
                        IsError = $false
                    })
                }
                $outputContext.AccountReference = $response.accountId
                $outputContext.AccountCorrelated = $true
            }
        }
    } 
    else {
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = "CorrelateAccount"
            Message = "Configuration of correlation is madatory."
            IsError = $true
        })
        Throw "Configuration of correlation is madatory."
    }

    # create the account object if not present
    if (!$outputContext.AccountCorrelated) {    
        $action = "create" 
        $account = $actionContext.Data

        Write-Verbose "Creating account for: [$($personContext.Person.DisplayName)]"
        $CreateParams = @{
            name=$account.name
            password=$account.password
            emailAddress=$account.emailAddress
            displayName=$account.displayname
        }

        $CreateParamsJson = $CreateParams | ConvertTo-Json
        $url = $actionContext.Configuration.url + "/rest/api/3/user"
        try {
            if (-Not($actionContext.DryRun -eq $true)) {
                $response = Invoke-RestMethod -Method Post -Uri $url -Body $CreateParamsJson -ContentType "application/json" -Headers $headers
            
                $outputContext.AccountReference = $response.accountId
                $createdAccount = [PSCustomObject]@{
                    displayName = $response.displayName
                    emailAddress = $response.emailAddress
                    name = $response.name
                }
                $outputContext.Data = $createdAccount

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "Created account with email $($account.emailAddress)"
                    IsError = $false
                })
            } 
            else {
                Write-Warning "DryRun: Would create account [$($account | ConvertTo-Json)]"
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CreateAccount"
                    Message = "DryRun: Would create account [$($account | ConvertTo-Json)]"
                    IsError = $false
                })
            }
        }
        catch {
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "Error creating account with email $($account.emailAddress) - Error: $($_)"
                IsError = $true
            })
        }
    }
} 
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {

        if (-Not [string]::IsNullOrEmpty($ex.ErrorDetails.Message)) {
            $errorMessage = "Could not $action account. Error: $($ex.ErrorDetails.Message)"
        }
        else {
            $errorMessage = "Could not $action account. Error: $($ex.Exception.Message)"
        }
    }
    else {
        $errorMessage = "Could not $action account. Error: $($ex.Exception.Message) $($ex.ScriptStackTrace)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Action  = "CreateAccount"
        Message = "Error occurred when $action account. Error Message: $($errorMessage)"
        IsError = $true
    })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-not($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}