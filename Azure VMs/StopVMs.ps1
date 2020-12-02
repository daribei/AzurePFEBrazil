Param(
    [Parameter(Mandatory = $True)]
    [String] $tagName,
    [Parameter(Mandatory = $True)]
    [String] $tagValue
)

$connection = Get-AutomationConnection -Name AzureRunAsConnection
while (!($connectionResult) -And ($logonAttempt -le 10)) {
    $LogonAttempt++
    $connectionResult = Connect-AzAccount `
        -ServicePrincipal `
        -Tenant $connection.TenantID `
        -ApplicationID $connection.ApplicationID `
        -CertificateThumbprint $connection.CertificateThumbprint

}

$VMs = Get-AzVM | `
Where-Object {$PSItem.Tags.Keys -eq $tagName -and $PSItem.Tags.Values -eq $tagValue}
 
ForEach ($VM in $VMs)
{
    Write-Output "Stoping: $($VM.Name)"
    Stop-AzVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -Force -AsJob
}  