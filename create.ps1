$c = $configuration | ConvertFrom-Json;
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$success = $False;
$auditLogs = New-Object Collections.Generic.List[PSCustomObject];

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


function GenerateName {
    [cmdletbinding()]
    Param (
        [object]$person
    )
    try {
        $initials = $person.Name.Initials -replace "\W"
        $initials = ([string]::Join('.', ([string[]]$initials.ToCharArray()))) + "."
        $FamilyNamePrefix = $person.Name.FamilyNamePrefix
        $FamilyName = $person.Name.FamilyName           
        $PartnerNamePrefix = $person.Name.FamilyNamePartnerPrefix
        $PartnerName = $person.Name.FamilyNamePartner 
        $convention = $person.Name.Convention
        $Name = $person.Name.NickName

        switch ($convention) {
            "B" {
                $Name += if (-NOT([string]::IsNullOrEmpty($FamilyNamePrefix))) { " " + $FamilyNamePrefix }
                $Name += " " + $FamilyName
            }
            "P" {
                $Name += if (-NOT([string]::IsNullOrEmpty($PartnerNamePrefix))) { " " + $PartnerNamePrefix }
                $Name += " " + $PartnerName
            }
            "BP" {
                $Name += if (-NOT([string]::IsNullOrEmpty($FamilyNamePrefix))) { " " + $FamilyNamePrefix }
                $Name += " " + $FamilyName + " - "
                $Name += if (-NOT([string]::IsNullOrEmpty($PartnerNamePrefix))) { $PartnerNamePrefix + " " }
                $Name += $PartnerName
            }
            "PB" {
                $Name += if (-NOT([string]::IsNullOrEmpty($PartnerNamePrefix))) { " " + $PartnerNamePrefix }
                $Name += " " + $PartnerName + " - "
                $Name += if (-NOT([string]::IsNullOrEmpty($FamilyNamePrefix))) { $FamilyNamePrefix + " " }
                $Name += $FamilyName
            }
            Default {
               $Name += if (-NOT([string]::IsNullOrEmpty($FamilyNamePrefix))) { " " + $FamilyNamePrefix }
                $Name += " " + $FamilyName
            }
        }      
        return $Name
            
    }
    catch {
        throw("An error was found in the name convention algorithm: $($_.Exception.Message): $($_.ScriptStackTrace)")
    } 
}

# Change mapping here
$account = [PSCustomObject]@{
    displayName = GenerateName -person $p
    emailAddress = $p.Accounts.MicrosoftActiveDirectory.userprincipalname
    password = New-RandomPassword(14)
    name = $p.Accounts.MicrosoftActiveDirectory.userprincipalname
    
};

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
                name=$account.name
                password=$account.password
                emailAddress=$account.emailAddress
                displayName=$account.displayname;
        };
        if ([string]::IsNullOrEmpty($account.name) -eq $false)
        {
            $url = $c.url + "/rest/api/3/user/search?query=" + $account.name
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
                    Message = "Error creating account with email $($account.emailAddress) - Error: $($_)"
                    IsError = $true;
                });
        Write-Error $_
    }
    
}

$auditLogs.Add([PSCustomObject]@{
    Action = "CreateAccount"; #Optionally specify a different action for this audit log
    Message = "Created account with email $($account.emailAddress)";
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
        userName = $account.Name;
        accountId = $aRef;
    };
};
Write-Output $result | ConvertTo-Json -Depth 10;