Param(
    [Parameter(Mandatory = $True)]
    [String] $destEmailAddress,
    [Parameter(Mandatory = $True)]
    [String] $fromEmailAddress,
    [Parameter(Mandatory = $True)]
    [String] $subject,
    [Parameter(Mandatory = $True)]
    [String] $days
)

$connection = Get-AutomationConnection -Name AzureRunAsConnection
while (!($connectionResult) -And ($logonAttempt -le 10)) {
    $LogonAttempt++
    # Logging in to Azure...
    $connectionResult = Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $connection.TenantID `
        -ApplicationID $connection.ApplicationID `
        -CertificateThumbprint $connection.CertificateThumbprint

    Start-Sleep -Seconds 30
}

#Set the page size to your need.
$pgsize = 100;

$pg = 0;
$i = 0;
$cnt = $null
$results = @()
do {
    
    $apps = Get-AzADApplication -First $pgsize -Skip ($pg * $pgsize)
    $cnt = $apps | Measure-Object
    #Write-Output "Contador: " + $cnt
    #sleep -Seconds 10
    if ($cnt.Count -gt 0) {
        Write-Output "Page: $pg;  Found $($cnt.Count) apps"
        $apps | % {  
            $app = $_

            $appCred = Get-AzADAppCredential -ObjectId $app.ObjectId

            if (([datetime]::UtcNow.AddDays($days)) -gt ($appCred[$i].EndDate)) {

                $appCred | % {
                    $results += [PSCustomObject] @{

                       
                        CredentialType = $_.Type;
                        DisplayName    = $app.DisplayName; 
                        ExpiryDate     = $_.EndDate;
                        StartDate      = $_.StartDate;
                        #KeyID = $_.KeyId;
                        #AppId = $app.ApplicationId;
                        #ObjectId = $app.ObjectId;
                        #Owners = $owner.UserPrincipalName;
                    }  
                
                }
            }
        }
    }
    $i++;
    $pg += 1;
} while ($cnt.Count -gt 0)  

$results | FT -AutoSize 

# PowerShell code
 
# Hardcode the API key of sendgrid. We need it in the header of the API call
$SENDGRID_API_KEY = "API_Key"
 
# Create the headers for the API call
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer " + $SENDGRID_API_KEY)
$headers.Add("Content-Type", "application/json")
 
foreach ($result in $results) {

    $content = "Application Name: " + $result.DisplayName + " |  Expiry Date: " + $result.ExpiryDate

    # Create a JSON message with the parameters from above
    $body = @{
        personalizations = @(
            @{
                to = @(
                    @{
                        email = $destEmailAddress
                    }
                )
            }
        )
        from             = @{
            email = $fromEmailAddress
        }
        subject          = $subject
        content          = @(
            @{
                type  = "text/plain"
                value = $content
            }
        )
    }

    # Convert the string into a real JSON-formatted string
    # Depth specifies how many levels of contained objects
    # are included in the JSON representation. The default
    # value is 2
    $bodyJson = $body | ConvertTo-Json -Depth 4
 
    # Call the SendGrid RESTful web service and pass the
    # headers and json message. More details about the 
    # webservice and the format of the JSON message go to
    # https://sendgrid.com/docs/api-reference/
    $response = Invoke-RestMethod -Uri https://api.sendgrid.com/v3/mail/send -Method Post -Headers $headers -Body $bodyJson
}