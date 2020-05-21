<# 
    # Install the Azure Module
    Install-Module -Name Az -force -AllowClobber
#>  
    # Login to Azure, you will be prompted for your creds 
    Login-AzAccount  
 
# Loop through all Subscriptions that you have access to and export the Role information 
Get-AzSubscription | foreach-object { 
 
    Write-Verbose -Message "Changing to Subscription $($_.Name)" -Verbose 
 
    Select-AzSubscription -TenantId $_.TenantId -Name $_.Id -Force 
    $Name     = $_.Name 
    $TenantId = $_.TenantId 
 
 
    Get-AzRoleAssignment -IncludeClassicAdministrators | Select RoleDefinitionName,DisplayName,SignInName,ObjectType,Scope, 
        @{name='TenantId';expression = {$TenantId}},@{name='SubscriptionName';expression = {$Name}} -OutVariable ra 
 
    # Also export the individual subscriptions to excel documents on your Desktop. 
    # One file per subscription 
    $ra | Export-Csv -Path $home\Desktop\$Name.csv -NoTypeInformation 
 
} 
 
# once the csv files are saved on the desktop 
# Open files, insert Table, tick 'my table has headers' 
# format the size of the columns 
# Save as excel document 