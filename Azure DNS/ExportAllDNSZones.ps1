<#
.DESCRIPTION
This example demonstrates how to export all DNS zone through Azure CLI using Azure PowerShell.
.NOTES
1. Before you use this sample, please install the latest version of Azure CLI from here: https://docs.microsoft.com/pt-br/cli/azure/install-azure-cli-windows?view=azure-cli-latest
#>

# Login
az login

# Set the Subscription
az account set -s "Subscription Name or ID"

# Save all DNS zone names in zonas zonasdns.txt
# Import in Excel and leave only the lines with the zone name
az network dns zone list > zonasdns.txt

# Export
foreach($line in Get-Content .\zonasdns.txt) {
  az network dns zone export -g "Resource Group Name" -n $line -f "$line.txt"
}