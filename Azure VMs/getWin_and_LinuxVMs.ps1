$Linux = 0
$Windows = 0

foreach ($Subscription in (Get-AzSubscription))
{
    Select-AzSubscription -SubscriptionId ($Subscription).Id

        foreach ($vms in (Get-AzVM))
        {      
            if ($vm.StorageProfile.OsDisk.OsType -eq "Linux" )
                {
                    $Linux++
                }
            else
                {
                    $Windows++   
                }
        }
}

Write-Host "VMs Linux: " $Linux
Write-Host "VMs Windows: " $Windows