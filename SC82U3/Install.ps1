#Import the stuff we need 
Import-Module AzureRM
Import-Module ..\Tools\Sitecore.Cloud.Cmdlets.psm1

#Add the azure account
Add-AzureRmAccount

$Name="sc82u3-launch1"

Start-SitecoreAzureDeployment -Location "East US" -Name $Name -ArmTemplateUrl "https://ctsitecorepackages.blob.core.windows.net/sitecore/xp/azuredeploy.json" -ArmParametersPath ".\azuredeploy.parameters.json" -LicenseXmlPath "C:\Charlie\Installs\Sitecore\license.xml" -Verbose