$c = $configuration | convertfrom-json

try
{
    $pair = $c.username + ":" + $c.password
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $headers = @{"authorization" = $Key }    

    
    
        $url = $c.url + "/rest/api/3/groups/picker"
        $response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
        
        #Write-Verbose -Verbose $($response.groups)[0]
        $permissions = $response.groups

        $permissions | ForEach-Object { $_ | Add-Member -NotePropertyMembers  @{
                DisplayName    = "$($_.name)"
                Identification = @{
                    Reference = $_.groupId
                }
            }
        }

        Write-Output $permissions | ConvertTo-Json -Depth 10
}
catch { 
    Write-Error $_
}