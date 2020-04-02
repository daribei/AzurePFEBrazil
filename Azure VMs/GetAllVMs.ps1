param(
    [string]$file="c:\temp\Azure-ARM-VMs.csv",
    [string]$tenantid="Tenant-ID"
) 

# Use the application ID as the username, and the secret as password
$credentials = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $tenantid
$subs = Get-AzSubscription 


$vmobjs = @()

foreach ($sub in $subs)
{
    
    Write-Host Processing subscription $sub.SubscriptionName

    try
    {

        Select-AzSubscription -SubscriptionId $sub.SubscriptionId -ErrorAction Continue

        $vms = Get-AzVm 

        foreach ($vm in $vms)
        {
            $vmInfo = [pscustomobject]@{
                'Subscription'=$sub.Name
                'Name'=$vm.Name
                'ResourceGroupName' = $vm.ResourceGroupName
                'Location' = $vm.Location
                'Status' = $null
                }
        
            $vmStatus = $vm | Get-AzVM -Status
            $vmInfo.Status = $vmStatus.Statuses[1].DisplayStatus

            $vmobjs += $vmInfo

        }  
    }
    catch
    {
        Write-Host $error[0]
    }
}

$vmobjs | Export-Csv -NoTypeInformation -Path $file
Write-Host "VM list written to $file"
