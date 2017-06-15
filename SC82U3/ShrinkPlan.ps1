#Import the stuff we need 
Import-Module AzureRM
Import-Module ..\Tools\Sitecore.Cloud.Cmdlets.psm1

#Add the azure account
Add-AzureRmAccount

$Name="sc82u3-launch1"

$NewDatabaseEdition = "Standard";
$NewDatabasePricingTier = "S0" # the default database tier of Sitecore XP provisioning script is S1
$NewHostingPlanTier = "Basic"; # the default hosting plan tier of Sitecore XP provisioning script is Standard

Write-Host "Group all databases into one server...";
New-AzureRmSqlDatabaseCopy -ResourceGroupName $Name -ServerName "$Name-web-sql" -DatabaseName "$Name-web-db" -CopyServerName "$Name-sql" -CopyDatabaseName "$Name-web-db"
Remove-AzureRmSqlServer -ResourceGroupName $Name -ServerName "$Name-web-sql" -Force

Write-Host "Starting database scaling...";
$DatabaseNames = "core-db", "master-db", "web-db", "reporting-db"; 
Foreach ($DatabaseName in $DatabaseNames)
{
    Set-AzureRmSqlDatabase -DatabaseName "$Name-$DatabaseName" -ServerName "$Name-sql" -ResourceGroupName $Name -Edition $NewDatabaseEdition -RequestedServiceObjectiveName $NewDatabasePricingTier
}

Write-Host "Starting hosting plan scaling...";
$HostingPlans = "cd-hp", "cm-hp", "prc-hp", "rep-hp";
Foreach($HostingPlan in $HostingPlans)
{
    Set-AzureRmAppServicePlan -ResourceGroupName $Name -Name "$Name-$HostingPlan" -Tier $NewHostingPlanTier
}
