# Login
Connect-AzAccount 

$SubscriptionId = Get-AzSubscription | Out-GridView -PassThru
#$SubscriptionName = $SubscriptionId.Name
Select-AzSubscription -SubscriptionId ($SubscriptionId).Id

# Azure Resources Variables
$storageAccountName = "Nome da Conta de Armazenamento"
$fileShareName = "Nome do File Share"

$location = "brazilsouth"
$rgName = "PDBL-AFS-PRD-BR-RG"

# Create the Storage Account
if ($stgAvailability.Reason -eq "AlreadyExists") {
    
    #Write-Host "$storageAccountName account already exists, skipping creation" -ErrorAction Stop | Out-Null
    Write-Host "Conta de armazenamento $storageAccountName já existe, altere a variável `$storageAccountName e tente novamente." -ErrorAction Stop | Out-Null
}

else {
    $storageAccount = New-AzStorageAccount -Name $storageAccountName -Location $location -ResourceGroupName $rgName -SkuName Standard_LRS -Kind StorageV2 `
    -EnableHttpsTrafficOnly:$true
    
    Write-Host "Conta de armazenamento $storageAccountName criada com sucesso."
    Write-Host "Compartilhamento $fileShareName criado com sucesso." 
    Write-Host ""
 }