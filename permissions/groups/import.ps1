####################################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-ImportPermissions-Group
# PowerShell V2
####################################################################

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
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            Write-Warning $_.Exception.Message
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
        #Add the authorization header to the request
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
    Write-Information 'Starting Atlassian-Jira permission entitlement import'
    $splatHeaderParams = @{
        username = $actionContext.Configuration.username
        password = $actionContext.Configuration.token
    }
    $headers = New-AuthorizationHeaders @splatHeaderParams

    $startAt = 0
    $maxResults = 50
    $importedPermissions = [System.Collections.ArrayList]@()

    do {
        $splatPermissionParams = @{
            Uri     = "$($actionContext.Configuration.url)/rest/api/3/group/bulk?startAt=$startAt&maxResults=$maxResults"
            Method  = "GET"
            Headers = $headers
        }
        $response = Invoke-RestMethod @splatPermissionParams        
        $permissions = $response.values
        
        $importedPermissions.AddRange($permissions)
        $startAt += $maxResults        
        
    }while ($response.values.count -eq $maxResults)

    
    foreach ($importedPermission in $importedPermissions) {

        $startAt = 0
        $maxResults = 50
        $memberslist = [System.Collections.ArrayList]@()

        do {
            $splatPermissionMembersParams = @{
                Uri     = "$($actionContext.Configuration.url)/rest/api/3/group/member?groupId=$($importedPermission.groupId)&startAt=$startAt&maxResults=$maxResults"
                Method  = "GET"
                Headers = $headers
            }
            $members = Invoke-RestMethod @splatPermissionMembersParams

            if ($members.values.accountId.count -gt 0) {
                [void]$memberslist.AddRange([array]$members.values.accountId)
            } 

            $startAt += $maxResults

        }while ($members.values.accountId.count -eq $maxResults -and $members.values.accountId.count -gt 0)

        if ($memberslist.count -gt 0) {
            $permission = @{
                PermissionReference = @{
                    Reference = $importedPermission.groupId
                }
                Description         = "$($importedPermission.name)"
                DisplayName         = "$($importedPermission.name)"
                AccountReferences   = $memberslist
            }
            Write-Output $permission
        }
    }
    Write-Information 'Atlassian-Jira permission entitlement import completed'
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-Atlassian-JiraError -ErrorObject $ex
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        Write-Error "Could not import Atlassian-Jira permission entitlements. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import Atlassian-Jira permission entitlements. Error: $($ex.Exception.Message)"
    }
}