$mgmtgroups = Get-AzManagementGroup

foreach ($mgmtgroup in $mgmtgroups)
{
    if ($mgmtgroup.DisplayName -ne "Tenant Root Group")
    {
        Get-AzManagementGroup -GroupName $mgmtgroup.DisplayName -Expand -Recurse
    }
}