﻿Login-AzAccount
Select-AzSubscription -Subscription "SUBSCRIPTION NAME/ID"

$rgName = "WEBAPPS RESOURCE GROUP"
$webApps = @('WEBAPP01','WEBAPP02', 'WEBAPP03')


$range1 = "13.65.92.252/32,13.65.95.152/32,13.75.124.254/32,13.75.127.63/32,13.75.152.253/32,13.75.153.124/32,13.84.222.37/32,23.96.236.252/32"
$range2 = "23.101.191.199/32,40.68.30.66/32,40.68.31.178/32,40.78.67.110/32,40.87.147.10/32,40.87.151.34/32,40.114.5.197/32,52.172.155.168/32"
$range3 = "52.172.158.37/32,52.173.90.107/32,52.173.250.232/32,52.240.144.45/32,52.240.151.125/32,65.52.217.19/32,104.41.187.209/32,104.41.190.203/32"
$range4 = "104.42.192.195/32,104.45.149.110/32,104.215.91.84/32,137.135.46.163/32,137.135.47.215/32,137.135.80.149/32,137.135.82.249/32,191.232.208.52/32"
$range5 = "191.232.214.62/32"


foreach ($webApp in $webApps)
{
    Add-AzWebAppAccessRestrictionRule -ResourceGroupName $rgName -WebAppName "$webApp" `
    -Name "Allow - TrafficManager" -Priority 150 -Action Allow -IpAddress $range1

    Add-AzWebAppAccessRestrictionRule -ResourceGroupName $rgName -WebAppName "$webApp" `
    -Name "Allow - TrafficManager" -Priority 151 -Action Allow -IpAddress $range2

    Add-AzWebAppAccessRestrictionRule -ResourceGroupName $rgName -WebAppName "$webApp" `
    -Name "Allow - TrafficManager" -Priority 152 -Action Allow -IpAddress $range3

    Add-AzWebAppAccessRestrictionRule -ResourceGroupName $rgName -WebAppName "$webApp" `
    -Name "Allow - TrafficManager" -Priority 153 -Action Allow -IpAddress $range4

    Add-AzWebAppAccessRestrictionRule -ResourceGroupName $rgName -WebAppName "$webApp" `
    -Name "Allow - TrafficManager" -Priority 154 -Action Allow -IpAddress $range5

}