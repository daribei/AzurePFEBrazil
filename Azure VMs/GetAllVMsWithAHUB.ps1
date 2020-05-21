Login-AzAccount

Get-AzSubscription | foreach-object { 
 
    Write-Verbose -Message "Changing to Subscription $($_.Name)" -Verbose 
 
    Select-AzSubscription -TenantId $_.TenantId -Name $_.Id -Force 

$vms = Get-AzVM
$vms | Where-Object{$_.LicenseType -like "Windows_Server"} `
     | Select-Object ResourceGroupName, Name, LicenseType
}