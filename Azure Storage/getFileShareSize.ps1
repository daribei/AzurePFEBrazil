<#
    .DESCRIPTION
        This script is just an example of how to get the total file share size and send this information to Log Analytics.
    .NOTES
   
#>

#region script global variables
$global:totalLenght=0
#endregion

#region functions
function getFileSize ($file)
{
    $global:totalLenght+= $file    
}

function listSubdirectory ($path)
{
    $filesSubdirectory = Get-AzStorageFile -ShareName share01 -Context $context -Path $path | Get-AzStorageFile

    foreach ($file in $filesSubdirectory)
    {    
        if ($file.GetType().name -eq "CloudFile")
        {
            getFileSize($file.Properties.Length)
        }
    
        elseif ($file.GetType().name -eq "CloudFileDirectory")
        {         
            $sub=$file.Name
            [string]$newPath = "$path/$sub"
            listSubdirectory($newPath)
        }
    }
}

Function Get-LogAnalyticsSignature {
    [cmdletbinding()]
    Param (
        $customerId,
        $sharedKey,
        $date,
        $contentLength,
        $method,
        $contentType,
        $resource
    )
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

 

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

 

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

Function Export-LogAnalytics {
    [cmdletbinding()]
    Param(
        $customerId,
        $sharedKey,
        $object,
        $logType,
        $TimeStampField
    )
    $bodyAsJson = ConvertTo-Json $object
    $body = [System.Text.Encoding]::UTF8.GetBytes($bodyAsJson)

 

    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length

 

    $signatureArguments = @{
        CustomerId = $customerId
        SharedKey = $sharedKey
        Date = $rfc1123date
        ContentLength = $contentLength
        Method = $method
        ContentType = $contentType
        Resource = $resource
    }

 

    $signature = Get-LogAnalyticsSignature @signatureArguments
    
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

 

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

 

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}
#endregion

#region main script
$storageAccountName = <Storage_Account_Name>
$storageAccountKey = <Storage_Account_Key>
$storageAccountRG = <Storage_Account_RG>

$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$fileShares = Get-AzStorageShare -Context $context

#region log analytics variables
  $dataInicioScript = [System.DateTime]::UtcNow
  $RGName = <RG_Workspace_Name>
  $location = <location>
  $workspaceName = <Workspace_Name>
  

  $sharedkey = (Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $RGName -Name $WorkspaceName).PrimarySharedKey
  $customerid = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $RGName -Name $WorkspaceName).CustomerId
#endregion

foreach($share in $fileShares)
{
    $fileShare = Get-AzStorageFile -ShareName $share.Name -Context $context
    foreach($file in $fileShare)
    {
        if ($file.GetType().name -eq "CloudFile")
        {
            getFileSize($file.Properties.Length)
        }
    
        elseif ($file.GetType().name -eq "CloudFileDirectory")
        {
            listSubdirectory($file.Name)
        }

     }
        Write-Host "Share: " $share.Name
        Write-Host "Quota: " $share.Properties.Quota
        Write-Host "Size: " $global:totalLenght
        Write-Host ""

#region log analytics execution

#Conversion of total size to MB
$shareUsed = $global:totalLenght / (1024*1024)
#Conversion of quota to MB
$shareQuota = $share.Properties.Quota * 1024
$shareUsedAbs = $shareUsed
$shareQuotaAbs = $shareQuota
$shareFreeAbs = $shareQuotaAbs - $shareUsedAbs 
$shareUsedRel =  ($shareUsedAbs * 100) / $shareQuotaAbs 
$shareFreeRel = ($shareFreeAbs / $shareQuotaAbs) * 100

$storageaccounts = @{
        CollectionTime = [System.DateTime]::UtcNow
        dataInicioScript = $dataInicioScript
        StorageAccountName = $storageAccountName
        StorageAccountResourceGroup = $storageAccountRG
        StorageAccountShareName = $share.Name
        ShareQuota = $shareQuotaAbs
        ShareUsed = $shareUsedAbs
        ShareFree = $shareFreeAbs
        ShareUsedPercentage = $shareUsedRel
        ShareFreePercentage = $shareFreeRel        
}

$logAnalyticsParams = @{
    CustomerId = $customerid
    SharedKey = $sharedkey 
    TimeStampField = "CollectionTime"
    LogType = "StorageAccountShareMonitoring"
}

Export-LogAnalytics @logAnalyticsParams $storageaccounts

#endregion
        #Reset the total share size to start collecting the next share
        $global:totalLenght=0
}
#endregion