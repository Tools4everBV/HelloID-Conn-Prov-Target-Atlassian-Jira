#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Permissions
#
# Version: 3.0.0 | api changes
#####################################################

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
#endregion functions

try {
    $headers = New-AuthorizationHeaders -username $actionContext.Configuration.username -password $actionContext.Configuration.token 

    $url = $actionContext.Configuration.url + "/rest/api/3/groups/picker"
    $response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
    
    #Write-Verbose -Verbose $($response.groups)[0]
    $permissions = $response.groups

    $permissions | ForEach-Object { $_ | Add-Member -NotePropertyMembers @{
            DisplayName    = "$($_.name)"
            Identification = @{
                Reference = $_.groupId
            }
        }
    }
}
catch { 
    Write-Error $_
}
finally {
    $permissions | ForEach-Object {
        $outputContext.Permissions.Add($_)
    }
}