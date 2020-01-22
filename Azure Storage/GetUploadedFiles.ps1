$storageAccount = Get-AzStorageAccount -ResourceGroupName sajbackup-prod-rg -Name sajbackupprodsa
$blobs = Get-AzStorageContainer -Name sajbackup-prod-cont -Context $storageAccount.Context | Get-AzStorageBlob

# Get all files in Azure and total size
$azureSize = 0
$azureFilesNames = @()
foreach ($blob in $blobs){
    $name = $blob.Name.Split("/")
    $name = $name[$name.Count-1]
    $azureFilesNames += $name
    
    $azureSize += $blob.Length
}

$azureFilesNames | Out-File ".\AzureBlobs.txt"


# Get all files in Azure from month 2020_01
$azureSize = 0
$azureFilesNames = @()
$directories = @()
foreach ($blob in $blobs){
    $name = $blob.Name.Split("/")
    $directory = $name[$name.Count-2]
    $name = $name[$name.Count-1]

    if($name.Contains("202001") -or $name.Contains("2020_01")){
        $azureFilesNames += $name
        $azureSize += $blob.Length
        if (!$directories.Contains($directory)){
            $directories += $directory
        }
    }
}

$azureFilesNames | Out-File ".\AzureBlobs_$(Get-Date -f MMMM).txt"