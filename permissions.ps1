#####################################################
# HelloID-Conn-Prov-Target-Atlassian-Jira-Permissions
#
# Version: 2.0.0 | new-powershell-connector
#####################################################
# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try
{
    $pair = $actionContext.Configuration.username + ":" + $actionContext.Configuration.password
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $headers = @{"authorization" = $Key }    

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