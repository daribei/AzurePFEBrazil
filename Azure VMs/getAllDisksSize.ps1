$diskSize = 0

foreach ($Subscription in (Get-AzSubscription))
{
    Select-AzSubscription -SubscriptionId ($Subscription).Id

        foreach ($disks in (Get-AzDisk))
        {
            $diskSize += $disks.DiskSizeGB
        }
}

$diskSize