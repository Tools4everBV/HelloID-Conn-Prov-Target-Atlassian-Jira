$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;
$mRef = $managerAccountReference | ConvertFrom-Json;
$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

#Change mapping here
$account = [PSCustomObject]@{};

if(-Not($dryRun -eq $True)) {
    # Write delete logic here
    try
    {
        $pair = $c.username + ":" + $c.password
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{"authorization" = $Key }    

        if ([string]::IsNullOrEmpty($aRef) -eq $false)
        {
            $url = $c.url + "/rest/api/2/user?accountId=" + $aRef
            $response = Invoke-RestMethod -Method DELETE -Uri $url -Headers $headers
        }   
        $success = $True; 
    }
    catch
    {
        $success = $False;
        $auditLogs.Add([PSCustomObject]@{
                    Action = "DeleteAccount"
                    Message = "Error deleting account with PrimaryEmail $($p.contact.business.email) - Ref: $($aRef) - Error: $($_)"
                    IsError = $true;
                });
        Write-Error $_
    }
}

$auditLogs.Add([PSCustomObject]@{
    # Action = "DeleteAccount"; Optionally specify a different action for this audit log
    Message = "Account $($aRef) deleted";
    IsError = $False;
});

# Send results
$result = [PSCustomObject]@{
	Success= $success;
	AuditLogs = $auditLogs;
    Account = $account;
};
Write-Output $result | ConvertTo-Json -Depth 10;