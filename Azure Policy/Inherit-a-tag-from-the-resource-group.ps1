Login-AzAccount

$SubscriptionId = Get-AzSubscription | Out-GridView -PassThru
Select-AzSubscription -SubscriptionId ($SubscriptionId).Id

foreach ($group in Get-AzResourceGroup) {
    if ($null -ne $group.Tags) {
        $resources = Get-AzResource -ResourceGroupName $group.ResourceGroupName
        foreach ($r in $resources) {
            $resourcetags = (Get-AzResource -ResourceId $r.ResourceId).Tags
            if ($resourcetags) {
                foreach ($key in $group.Tags.Keys) {
                    if (-not($resourcetags.ContainsKey($key))) {
                        $resourcetags.Add($key, $group.Tags[$key])
                    }
# Remove os comentario abaixo se voce deseja atualizar os recursos que ja possuem as tags
#                    else {
#                        $resourcetags.Remove($key)
#                        $resourcetags.Add($key, $group.Tags[$key])
#                    }
                }
                Set-AzResource -Tag $resourcetags -ResourceId $r.ResourceId -Force
            }
            else {
                Set-AzResource -Tag $group.Tags -ResourceId $r.ResourceId -Force
            }
        }
    }    
}