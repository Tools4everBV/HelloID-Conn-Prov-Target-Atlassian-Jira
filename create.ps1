$c = $configuration | ConvertFrom-Json;
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

$account_guid = New-Guid;

# Change mapping here
$account = [PSCustomObject]@{
    displayName = $p.DisplayName;
    firstName= $p.Name.NickName;
    lastName= $p.Name.FamilyName;
    userName = $p.UserName;
    externalId = $account_guid;
    title = $p.PrimaryContract.Title.Name;
    department = $p.PrimaryContract.Department.DisplayName;
    startDate = $p.PrimaryContract.StartDate;
    endDate = $p.PrimaryContract.EndDate;
    manager = $p.PrimaryManager.DisplayName;
};

function New-RandomPassword($PasswordLength) {
    if($PasswordLength -lt 8) { $PasswordLength = 8}

    # Used to store an array of characters that can be used for the password
    $CharPool = New-Object System.Collections.ArrayList

    # Add characters a-z to the arraylist
    for ($index = 97; $index -le 122; $index++) { [Void]$CharPool.Add([char]$index) }

    # Add characters A-Z to the arraylist
    for ($index = 65; $index -le 90; $index++) { [Void]$CharPool.Add([Char]$index) }

    # Add digits 0-9 to the arraylist
    $CharPool.AddRange(@("0","1","2","3","4","5","6","7","8","9"))

    # Add a range of special characters to the arraylist
    $CharPool.AddRange(@("!","""","#","$","%","&","'","(",")","*","+","-",".","/",":",";","<","=",">","?","@","[","\","]","^","_","{","|","}","~","!"))

    $password=""
    $rand=New-Object System.Random

    # Generate password by appending a random value from the array list until desired length of password is reached
    1..$PasswordLength | ForEach-Object { $password = $password + $CharPool[$rand.Next(0,$CharPool.Count)] }

    $password
}

if(-Not($dryRun -eq $True)) {
    # Write create logic here
    try
    {
        $pair = $c.username + ":" + $c.password
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $key = "Basic $base64"
        $headers = @{"authorization" = $Key }    

        $CreateParams = @{
                name=$p.contact.business.email;
                password=New-RandomPassword(14)
                emailAddress=$p.contact.business.email;
                displayName=$p.Name.GivenName + " " + $p.Name.FamilyName;
        };
        if ([string]::IsNullOrEmpty($p.contact.business.email) -eq $false)
        {
            $url = $c.url + "/rest/api/3/user/search?query=" + $p.contact.business.email
            $response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers
            if (($response | Measure-Object).Count -ge 1)
            {
                $aRef = $response.accountId
            }
            else
            { 
                $CreateParamsJson = $CreateParams | ConvertTo-Json
                $url = $c.url + "/rest/api/3/user"
                $response = Invoke-RestMethod -Method Post -Uri $url -Body $CreateParamsJson -ContentType "application/json" -Headers $headers
                $aRef = $response.accountId
            }
            $success = $True;
        }
        else
        {
            $success = $False;
        }
    }
    catch { 
        $success = $False;
        $auditLogs.Add([PSCustomObject]@{
                    Action = "CreateAccount"
                    Message = "Error creating account with PrimaryEmail $($p.contact.business.email) - Error: $($_)"
                    IsError = $true;
                });
        Write-Error $_
    }
    
}

$auditLogs.Add([PSCustomObject]@{
    # Action = "CreateAccount"; Optionally specify a different action for this audit log
    Message = "Created account with PrimaryEmail $($p.contact.business.email)";
    IsError = $False;
});

# Send results
$result = [PSCustomObject]@{
	Success= $success;
	AccountReference= $aRef;
	AuditLogs = $auditLogs;
    Account = $account;

    # Optionally return data for use in other systems
    ExportData = [PSCustomObject]@{
        displayName = $account.DisplayName;
        userName = $account.UserName;
        externalId = $aRef;
    };
};
Write-Output $result | ConvertTo-Json -Depth 10;