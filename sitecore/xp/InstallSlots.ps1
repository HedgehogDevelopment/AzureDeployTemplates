# Variables
$InstanceName = "learn-sitecore-xp-prod-rg"
$DeploymentId = "learn-sitecore"
$AzureToolKitModuleUrl = "D:\Software\Sitecore\AzureToolKit\Sitecore Azure Toolkit 1.1 rev 170804\Tools\Sitecore.Cloud.Cmdlets.psm1"
$ArmTemplateUrl = "https://sitecoreblobs.blob.core.windows.net/armtemplates82u4/xp/slots.azuredeploy.json"
$ArmParameters = "..\\armtemplates82u4\xp\slots.azuredeploy.parameters.json"
$LicenseFile = "D:\Software\Sitecore\license.xml"

﻿# Ensure your PowerShell environment is already configured on your system
# Import-Module Azure -AllowClobber
# Import-Module AzureRM -AllowClobber
# Set-ExecutionPolicy Unrestricted

#Point to the sitecore cloud tools on your local filesystem
Import-Module $AzureToolKitModuleUrl

#Add the azure account
Add-AzureRmAccount

# Staging variables
$defaultWebDbName = $DeploymentId + "-web-db";
$defaultMasterDbName = $DeploymentId + "-master-db";
$webDbNameAppSetting = "SlotWebDbName"
$masterDbNameAppSetting = "SlotMasterDbName"
$dbChannelRegex = "-(web|master)(-[a-z0-9]+)?-db"
$stagingDbNameEvaluator = {
    param($m)
    $currentName = $m.Groups[2].Value.Trim('-')
   
    $stagingName = get-date -Format yyyyMMddHHmmss
    return "-" + $m.Groups[1].Value + "-" + $stagingName + "-db";
}

$cdWebApp = $DeploymentId + "-cd"
$prodCdSlot = Get-AzureRmWebAppSlot -ResourceGroupName $InstanceName -Name $cdWebApp -Slot production
$prodWebDbName = ($prodCdSlot.SiteConfig.AppSettings | ? { $_.Name -eq $webDbNameAppSetting }).Value
$prodWebDbName = if ($prodWebDbName) { $prodWebDbName } else { $defaultWebDbName }

$cmWebApp = $DeploymentId + "-cm"
$prodCmSlot = Get-AzureRmWebAppSlot -ResourceGroupName $InstanceName -Name $cmWebApp -Slot production
$prodMasterDbName = ($prodCmSlot.SiteConfig.AppSettings | ? { $_.Name -eq $masterDbNameAppSetting }).Value
$prodMasterDbName = if ($prodMasterDbName) { $prodMasterDbName } else { $defaultMasterDbName }

$stagingWebDbName = [regex]::Replace($prodWebDbName, $dbChannelRegex, $stagingDbNameEvaluator)
$stagingMasterDbName = [regex]::Replace($prodMasterDbName, $dbChannelRegex, $stagingDbNameEvaluator)

$inputParameters = @{ 
 "deploymentId" = $DeploymentId;
 "productionMasterSqlDatabaseName" = $prodMasterDbName;
 "productionWebSqlDatabaseName" = $prodWebDbName;
 "stagingMasterSqlDatabaseName" = $stagingMasterDbName; 
 "stagingWebSqlDatabaseName" = $stagingWebDbName; 
}


Write-Host "Deploying instance $InstanceName. Params:)"
Write-Host ($inputParameters | Out-String)
Start-SitecoreAzureDeployment -Location "East US" -Name $InstanceName -ArmTemplateUrl $ArmTemplateUrl -ArmParametersPath $ArmParameters -LicenseXmlPath $LicenseFile -SetKeyValue $inputParameters -Verbose