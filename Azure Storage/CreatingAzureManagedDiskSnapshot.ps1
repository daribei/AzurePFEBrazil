Param(
    [string]$resourceGroupName
)

# Ensures you do not inherit an AzureRMContext in your runbook
#Disable-AzureRmContextAutosave –Scope Process

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

# Remove old snapshots
$snapshotnames = (Get-AzSnapshot -ResourceGroupName $resourceGroupName).name
foreach($snapname in $snapshotnames)
{
    Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapname | ?{($_.TimeCreated) -lt ([datetime]::UtcNow.AddMinutes(-10080))} | Remove-AzSnapshot -Force
} 

foreach ($VMs in Get-AzVM -ResourceGroupName $resourceGroupName) {  
    #Set local variables 
    $location = $VMs.Location 
    #$resourceGroupName = $vmInfo.ResourceGroupName 
    $timestamp = Get-Date -f MM-dd-yyyy_HH_mm_ss 
 
    #Snapshot name of OS data disk 
    $snapshotName = "bkp-" + $VMs.Name + "-" + $timestamp 
 
    #Create snapshot configuration 
    $snapshot = New-AzSnapshotConfig -SourceUri $VMs.StorageProfile.OsDisk.ManagedDisk.Id -Location $location  -CreateOption copy 
                 
    #Take snapshot 
    New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName  
                 

                 
    if ($VMs.StorageProfile.DataDisks.Count -ge 1) { 
        #Condition with more than one data disks 
        for ($i = 0; $i -le $VMs.StorageProfile.DataDisks.Count - 1; $i++) { 
                                 
            #Snapshot name of OS data disk 
            $snapshotName = $VMs.StorageProfile.DataDisks[$i].Name + $timestamp  
                             
            #Create snapshot configuration 
            $snapshot = New-AzSnapshotConfig -SourceUri $VMs.StorageProfile.DataDisks[$i].ManagedDisk.Id -Location $location  -CreateOption copy 
                             
            #Take snapshot 
            New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName  
                             
        } 
    } 
    else { 
        Write-Host $VMs.Name + " doesn't have any additional data disk." 
    } 
}