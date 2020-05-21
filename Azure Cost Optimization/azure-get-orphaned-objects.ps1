<#
.SYNOPSIS
    Author:     Lior Arviv, Microsoft
    Version:    3.0.0
    Created:    01/05/2019
    Updated:    31/12/2019

.EXAMPLE
    For simulation mode, run the script with no parameters:

        .\azure-get-orphaned-objects.ps1

    To scan a specific Azure subscription, pass the "-SubscriptionName Production" parameter where Production is the subscription name

        .\azure-get-orphaned-objects.ps1 -SubscriptionName ""

    To delete orphaned objects that are identified, pass the "-SimulateMode $False" parameter:
    Please be aware that simulation mode is turned on by default

        .\azure-get-orphaned-objects.ps1 -SimulateMode $False

.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages. 

#>
 
Param(
    # Optional. Azure Subscription Name, if you want to scan or update a single subscription use this parameter
    [parameter(position = 1)]
    [string]$SubscriptionName = "SubscriptionName",
    [parameter(position = 0)]
    [string]$SimulateMode = "$True"
)
# Variables
$ErrorActionPreference = "Stop"
# Setup counters for Extension installation results
# If $SubscriptionName Parameter has not been passed as an argument or edited in the script Params.
    
If ($SubscriptionName -eq "SubscriptionName") {
    # Get all Subscriptions
    [array]$AzureSubscriptions = Get-AzSubscription -ErrorAction $ErrorActionPreference
}
else {
    [array]$AzureSubscriptions = (Get-AzContext).Subscription     
}
    
$SubscriptionCount = 0
# Loop Subscriptions
ForEach ($AzureSubscription in $AzureSubscriptions) {

    $SubscriptionCount++

    Write-Host "Processing Azure Subscription: " -NoNewLine
    Write-Host "$SubscriptionCount of $($AzureSubscriptions.Count)" -ForegroundColor Yellow

    Write-Host "Subscription Name = " -NoNewLine
    Write-Host "$($AzureSubscription.Name)" -ForegroundColor Yellow

    $Script:ActiveSubscriptionName = $AzureSubscription.Name
    $Script:ActiveSubscriptionID = $AzureSubscription.Id

    if ($SimulateMode -eq $True) {
        # Simulate Mode: True
        Write-Host "INFO: " -ForegroundColor Cyan
        Write-Host "Simulate Mode ENABLED" -ForegroundColor Green
        Write-Host " - No updates will be performed."
        Write-Host " "
        #Continue

    }
    else {
        # Simulate Mode: False
        Write-Host "INFO: " -ForegroundColor Cyan
        Write-Host "Simulate Mode DISABLED" -ForegroundColor Red
        Write-Host " - Updates will be performed."
        Write-Host " "
        #Continue
    }

    # Set AzContext as we are in a ForEach Loop
    Write-Host "Set-AzContext" -NoNewline
    Write-Host "-SubscriptionId " -NoNewLine
    Write-Host $($AzureSubscription.Id) -ForegroundColor Cyan

    Set-AzContext -SubscriptionId $AzureSubscription.Id

    Write-Host "`nFind and enable Hybrid License Benefit (AHUB):" -ForegroundColor Cyan
    [array]$AzVMs = Get-AzVM #-ErrorAction $ErrorActionPreference -WarningAction $WarningPreference

    if ($AzVMs) {
      
        # Loop through each VM in this Resource Group
        ForEach ($AzVM in $AzVMs) {
      
            # Create New Ordered Hash Table to store VM details
            $VMOutput = [ordered]@{ }
            #$VMOutput.Add("Resource Group",$ResourceGroup)
            $VMOutput.Add("VM Name", $AzVM.Name)
            $VMOutput.Add("Resource Group Name", $AzVM.ResourceGroupName)
            $VMOutput.Add("VM Size", $AzVM.HardwareProfile.VmSize)
            $VMOutput.Add("VM Location", $AzVM.Location)
            $VMOutput.Add("OS Type", $AzVM.StorageProfile.OsDisk.OsType)
      
            # If the VM is a Windows VM
            if ($AzVM.StorageProfile.OsDisk.OsType -eq "Windows") {
      
                # If AHUB is NOT enabled
                if (($AzVM.LicenseType -ne "Windows_Server") -and ($AzVM.LicenseType -ne "Windows_Client")) {
      
                    if ($SimulateMode -eq $False) {
                            
                        # $SimulateMode set to $False, updates will be performed
                        Write-Host "`tUpdating $($AzVM.Name)..."
      
                        $AzVM.LicenseType = "Windows_Server"                      
                        Update-AzVM -ResourceGroupName $AzVM.ResourceGroupName -VM $AzVM
                        # $SimulateMode set to $True (default), No Updates will be performed
      
                    }
                    else {
      
                        Write-Host "INFO: " -ForegroundColor Cyan -NoNewline
                        Write-Host "$($AzVM.Name)"
                    }      
                }
            }
        }
    }

    Write-Host "`nFind stopped Vitual Machines and dellocate them:" -ForegroundColor Cyan
    [array]$StoppedAzVMs = Get-AzVM -Status

    if ($StoppedAzVMs) {
     
        # Loop through each VM in this Resource Group
        ForEach ($StoppedAzVM in $StoppedAzVMs) {
     
            # Create New Ordered Hash Table to store VM details
            $StoppedVMOutput = [ordered]@{ }
            $StoppedVMOutput.Add("VM Name", $StoppedAzVM.Name)
            $StoppedVMOutput.Add("Resource Group Name", $StoppedAzVM.ResourceGroupName)
            $StoppedVMOutput.Add("VM Size", $StoppedAzVM.HardwareProfile.VmSize)
            $StoppedVMOutput.Add("VM Location", $StoppedAzVM.Location)
     
            # If PowerState is VM stopped
            if ($StoppedAzVM.PowerState -eq "VM stopped") {
     
                if ($SimulateMode -eq $False) {
                           
                    Write-Host "`tDeallocating $($StoppedAzVM.Name)..."
                    Stop-AzVM -Name $StoppedAzVM.Name -ResourceGroupName $StoppedAzVM.ResourceGroupName -Force
         
                }
                else {
     
                    Write-Host "INFO: " -ForegroundColor Cyan -NoNewline
                    Write-Host "`tName: $($StoppedAzVM.Name)"
                    Write-Host "`tLocation: $($StoppedAzVM.Location)"
                    Write-Host "`tResource Group: $($StoppedAzVM.ResourceGroupName)"
                    Write-Host "`tSize: $($StoppedAzVM.HardwareProfile.VmSize)"
                }      
            }
        }
    }

    Write-Host "`nFind and delete unattached Network Interfaces:" -ForegroundColor Cyan
    $nics = Get-AzNetworkInterface
    foreach ($nic in $nics) {
        # ManagedBy property stores the Id of the VM to which Managed Disk is attached to
        # If ManagedBy property is $null then it means that the Managed Disk is not attached to a VM
        if ($nic.VirtualMachine -eq $null) {

            if ($SimulateMode -eq $False) {
                Write-Host "Deleting unattached network interface with Id: $($nic.Name)"
                $nic | Remove-AzNetworkInterface -Force
                Write-Host "Deleted unattached network interface with Id: $($nic.Name)"

            }
            else {
                $nic.Name
            }
        }
    }

    Write-Host "`nFind and delete unattached Unmanaged Disks:" -ForegroundColor Cyan

    $storageAccounts = Get-AzStorageAccount
    foreach ($storageAccount in $storageAccounts) {
            $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName)[0].Value
            $context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
            $containers = Get-AzStorageContainer -Context $context

            foreach ($container in $containers) {
                $blobs = Get-AzStorageBlob -Container $container.Name -Context $context

                #Fetch all the Page blobs with extension .vhd as only Page blobs can be attached as disk to Azure VMs
                $blobs | Where-Object { $_.BlobType -eq 'PageBlob' -and $_.Name.EndsWith('.vhd') } | ForEach-Object { 
        
                    #If a Page blob is not attached as disk then LeaseStatus will be unlocked
                    if ($_.ICloudBlob.Properties.LeaseStatus -eq 'Unlocked') {
                        if ($SimulateMode -eq $False) {
                            Write-Host "Deleting unattached VHD with Uri: $($_.ICloudBlob.Uri.AbsoluteUri)"
                            $_ | Remove-AzStorageBlob -Force
                            Write-Host "Deleted unattached VHD with Uri: $($_.ICloudBlob.Uri.AbsoluteUri)"
                        }
                        else {
                            $_.ICloudBlob.Uri.AbsoluteUri
                            [math]::Round($_.ICloudBlob.Properties.Length / 1024 / 1024 / 1024, 2)
                        }
                    }
                }
            }
        
    }
    Write-Host "`nFind and delete unattached Managed Disks:" -ForegroundColor Cyan

    $managedDisks = @(Get-AzDisk | Where-Object { !$PSItem.Name.EndsWith("-ASRReplica") })
    foreach ($md in $managedDisks) {
        # ManagedBy property stores the Id of the VM to which Managed Disk is attached to
        # If ManagedBy property is $null then it means that the Managed Disk is not attached to a VM
        if ($md.ManagedBy -eq $null) {
            if ($SimulateMode -eq $False) {
                Write-Host "Deleting unattached Managed Disk with Id: $($md.Id)"
                $md | Remove-AzDisk -Force
                Write-Host "Deleted unattached Managed Disk with Id: $($md.Id)"
            }
            else {
                $md | Select-Object Id, DiskSizeGB, ResourceGroupName

            }
        }
    }

    Write-Host "`nFind and delete unattached Public IPs:" -ForegroundColor Cyan
    $pips = Get-AzPublicIpAddress
    foreach ($pip in $pips) {

        if ($pip.IpConfiguration -eq $null) {
            if ($SimulateMode -eq $False) {
                Write-Host "Deleting unattached Public IPs with Id: $($pip.Id)"
                $pip | Remove-AzPublicIpAddress -Force
                Write-Host "Deleted unattached Public IPs with Id: $($pip.Id)"

            }
            else {
                $pip | Select Name, PublicIpAllocationMethod, IpAddress
            }
        }
    }

    Write-Host "`nFind and delete Load Balancers with empty pools:" -ForegroundColor Cyan
    
    $AzloadBalancers = Get-AzLoadBalancer
    Foreach ($AzloadBalancer in $AzloadBalancerS) {
        $AzLbBackendConfigs = Get-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $AzloadBalancer
        $EmptyBEPool = @()   
                
        Foreach ($AzLbBackendConfig in $AzLbBackendConfigs) {   
            IF ($AzLbBackendConfig.BackendIpConfigurations.count -lt 1) {
                If ($SimulateMode -eq $False) {
                    Write-Host "Deleting load balancer: $($AzloadBalancer.Name)"
                    $AzloadBalancer | Remove-AzLoadBalancer -Force
                    Write-Host "Deleted load balancer: $($AzloadBalancer.Name)"
                }
                Else {
                    Write-Host "Load Balancer:" $AzloadBalancer.name "has empty pool named:" $AzLbBackendConfig.name
                    $EmptyBEPool += $AzLbBackendConfig
                }
            }
        }   
    }

    Write-Host "`nFind and delete empty Application Gateways with empty backend pools:" -ForegroundColor Cyan

    $AzAppGWs = Get-AzApplicationGateway
    Foreach ($AzAppGW in $AzAppGWs) {
        $AzAppGwBackendConfigs = @(Get-AzApplicationGatewayBackendAddressPool -ApplicationGateway $AzAppGW)
        $EmptyBEPool = @()  
        Foreach ($AzAppGwBackendConfig in $AzAppGwBackendConfigs) {
            If ($AzAppGwBackendConfig.BackendIpConfigurations.count -eq 0 -and $AzAppGwBackendConfig.BackendAddresses.count -eq 0) {
                If ($SimulateMode -eq $False) {
                    Remove-AzApplicationGateway -Name $AzAppGW.Name -ResourceGroupName $AzAppGW.ResourceGroupName -Force
                }
                Else {
                    Write-Host $AzAppGW.name "has a pool configured with no targets named:" $AzAppGwBackendConfig.name
                    $EmptyBEPool += $AzAppGwBackendConfig
                }

            }
        }
    }

    Write-Host "`nFind and delete empty Availability Sets:" -ForegroundColor Cyan

    $AzASs = Get-AzAvailabilitySet | Where-Object { $_.VirtualMachinesReferences.Count -lt 1 }
    Foreach ($AzAS in $AzASs) {
        if ($SimulateMode -eq $False) {
            Write-Host "Deleting availability set: $($AzAS.Name)"
            $AzAS | Remove-AzAvailabilitySet -Force
            Write-Host "$($AzAS.Name) has been deleted"
        }
        else {
            Write-Host "$($AzAS.Name) has no virtual machines reference"
        }
    }

    Write-Host "`nFind and delete empty Resource Groups:" -ForegroundColor Cyan

    $AllRGs = (Get-AzResourceGroup).ResourceGroupName
    $UsedRGs = (Get-AzResource | Group-Object ResourceGroupName).Name
    $EmptyRGs = $AllRGs | Where-Object { $_ -notin $UsedRGs }
    Foreach ($EmptyRG in $EmptyRGs) {
        if ($SimulateMode -eq $False) {
            Write-Host "Deleting" $EmptyRG "resource group" 
            Remove-AzResourceGroup -Name $EmptyRG -Force | Out-Null
            Write-Host "$($EmptyRG) has been deleted"
        }
        else {
            Write-Host "$($EmptyRG) is an empty resource group"
        }
    }
}