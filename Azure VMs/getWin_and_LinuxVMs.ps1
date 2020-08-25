$getSoType = @()

foreach ($Subscription in (Get-AzSubscription))
{
    Select-AzSubscription -SubscriptionId ($Subscription).Id

        foreach ($vms in (Get-AzVM))
        {   
            $getSoType += [pscustomobject]@{
            Name = $VMs.Name  
            SO_Type = $vms.StorageProfile.OsDisk.OsType
            }
        }
}
$getSoType
$getSoType | Export-Csv ".\SO_Type.csv" -NoTypeInformation -Encoding UTF8
