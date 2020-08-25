Connect-AzAccount 

$azurevms = @()
$azurevmsDisks = @()

$filename = "inventory.csv"
$filename2 = "inventoryDataDisks.csv"

foreach ($Subscription in (Get-AzSubscription))
{
Select-AzSubscription -SubscriptionId ($Subscription).Id

foreach ($vm in (Get-AzVM))
{
        $NIC = Get-AzNetworkInterface -ResourceId $VM.NetworkProfile.NetworkInterfaces.id
        $Disk = Get-AzDisk -DiskName (Get-AzResource -ResourceId $VM.StorageProfile.OsDisk.ManagedDisk.Id).Name    
              
    $azurevms += [pscustomobject]@{
        Name = $VM.Name
        ResourceGroup = $VM.ResourceGroupName
        Subscription = $Subscription.Name
        OperatingSystem = $vm.StorageProfile.OsDisk.OsType
        Size = $VM.HardwareProfile.VmSize
        Status = (get-azvm -ResourceGroupName $VM.ResourceGroupName -Name $VM.name -status).Statuses.code[1]  
        ImageReference = $VM.StorageProfile.ImageReference.Offer
        License = $VM.LicenseType
        OSDiskType = $VM.StorageProfile.OsDisk.OsType
        OSDiskManaged = $Disk.Name
        OSDiskManagedSize = $Disk.DiskSizeGB
        OSDiskManagedMB = $Disk.DiskMBpsReadWrite
        OSDiskUnManaged = $VM.StorageProfile.OsDisk.Vhd
        VMAgentStatus = IF ($VM.StorageProfile.OsDisk.OsType -eq "Windows"){$VM.OSProfile.WindowsConfiguration.ProvisionVMAgent} ELSE {$VM.OSProfile.LinuxConfiguration.ProvisionVMAgent}
        DiagEnabled = $VM.DiagnosticsProfile.BootDiagnostics.Enabled
        DiagConfig = $VM.DiagnosticsProfile.BootDiagnostics.StorageUri
        Nic = $NIC.Primary
        NicIP = $NIC.IpConfigurations.PrivateIpAddress -join ";"
        NicIPPUB = if ($NIC.IpConfigurations.PublicIpAddress.Id -eq $null) {"no PIP"} ELSE {(Get-AzResource -ResourceId $NIC.IpConfigurations.PublicIpAddress.Id).Name}
        NicAccNet = $NIC.EnableAcceleratedNetworking
        NicIPFor = $NIC.EnableIPForwarding
        NicNSG = if ($NIC.NetworkSecurityGroup.id -eq $null) {"no nsg"} ELSE {(Get-AzResource -ResourceId $NIC.NetworkSecurityGroup.id).Name}
        NicAppSecG = if ($NIC.IpConfigurations[0].ApplicationSecurityGroups.id -eq $null){"no appsecgroup"} ELSE {($appsec = foreach ($1 in $NIC.IpConfigurations[0].ApplicationSecurityGroups.id){(Get-AzResource -ResourceId $1).name}) -join ";" }
        NicLBBEPool = $NIC.IpConfigurations.LoadBalancerBackendAddressPools.id -join ";"
        NicAppgtwBEPool = $NIC.IpConfigurations.ApplicationGatewayBackendAddressPools -join ";"
    }
}

foreach ($vm in (Get-AzVM))
{
        $dataDiskCount = $VM.StorageProfile.DataDisks.Count
        $count = $dataDiskCount-1        
              
        if ($dataDiskCount -gt 0)
        {
            DO
            {        
              $diskName = $VM.StorageProfile.DataDisks[$count].Name                
              $diskInfo = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $diskName              
              $count--

          $azurevmsDisks += [pscustomobject]@{
            Name = $VM.Name
            Subscription = $Subscription.Name
            DataDiskName = $diskInfo.Name
            DataDiskSize = $diskInfo.DiskSizeGB
              }

            } While ($count -ge 0)
        }
}

}

$azurevms | Export-Csv ".\$filename" -NoTypeInformation -Encoding UTF8
$azurevmsDisks | Export-Csv ".\$filename2" -NoTypeInformation -Encoding UTF8