Param(
    [Parameter(Mandatory = $True)]
    [String] $stgName,
    [Parameter(Mandatory = $True)]
    [String] $stgRgName    
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

    #Start-Sleep -Seconds 30
}

#Storage Connection
$timestamp = Get-Date -f MM-dd-yyyy
$StartTime = Get-Date
$EndTime = $startTime.AddHours(1.0)
$stgAccount = Get-AzStorageAccount -Name $stgName -ResourceGroupName $stgRgName
$SASToken = New-AzStorageAccountSASToken -Service Blob -ResourceType Container,Object -Permission "racwdlup" -startTime $StartTime -ExpiryTime $EndTime -Context $StgAccount.Context
$stgcontext = New-AzStorageContext -storageAccountName $stgAccount.StorageAccountName -SasToken $SASToken
$stgContainer = New-AzStorageContainer -Name $timestamp -Context $stgcontext

# DNS Zones
$zones = Get-AzDnsZone

foreach($zone in $zones) {
  $fileName = $zone.Name+".dns"
  $recordSets = Get-AzDnsRecordSet -Zone $Zone
  $RecordSets | out-file $fileName -Force
  Set-AzStorageBlobContent -File $fileName -Container $stgContainer.Name -Context $stgcontext -Force
}