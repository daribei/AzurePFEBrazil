Param(
    [Parameter(Mandatory = $True)]
    [String] $email
)

$hostPoolRG = "Host Pool - RG Name"
$hostPoolName = "Host Pool Name"
$flag = "0"
$subscriptionID = "Subscription ID"

Login-AzAccount

Select-AzSubscription -Subscription $subscriptionID


$sessionHosts = Get-AzWvdSessionHost -HostPoolName $hostPoolName -ResourceGroupName $hostPoolRG

foreach ($sessionHost in $sessionHosts)
{

    if ($sessionHost.AssignedUser -eq $email)
    {
        $vmResourceID = $sessionHost.ResourceId
        $vmName = $vmResourceID.Substring(128)
        $flag = "1"
        
        Write-Output "Iniciando máquina virtual... Aguarde 5 minutos e tente conectar."
        Stop-AzVM -Name $vmName -ResourceGroupName $hostPoolRG -Force -AsJob | Out-Null
    }
}

if ($flag -eq "0")
{

        Write-Output "O usuário $email não possui máquina disponível no WVD."
}