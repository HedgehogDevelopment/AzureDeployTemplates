Blog Post

## 1. Intro, Setting up the Solution and VSO Build ##

In this blog post series I am going to setup a Sitecore instance on Azure, with the initial deployment including some custom built modules as add-ons to the setup.
Then I'll go through enabling blue/green deployments on the CD instance, allowing us to utilize an Azure staging slot in order to preview our new release before it goes live, and then swap that slot out with the current live website. This will give us zero downtime deployments, so the front end users of the site will not be affected.

Blue/Green Deployments have been mentioned in the past by various Sitecore MVPs, like [Rob Habraken](https://www.robhabraken.nl/index.php/2740/blue-green-sitecore-deployments-on-azure/) and [Bas Lijten](http://blog.baslijten.com/sitecore-on-azure-create-custom-web-deploy-packages-using-the-sitecore-azure-toolkit/). In this series of posts, we will dive deeper into the setup for custom modules with the new Sitecore Azure Toolkit (v1.1), new Sitecore ARM templates (for Sitecore 8.2 Update3+) and some PowerShell scripts that we've created to make this a devops engineer's dream!

1. Intro, Setting up the solution and VSO build [this]
2. Preparing the default scripts and packages for Azure Deployment [Link]
3. Adding custom modules to an Azure Deployment [Link]
4. Adding our project's code and items to the Azure Deployment [Link]
5. Deploying to a Slot [Link]
6. True Blue Green Deployments for Sitecore on Azure [Link]

## The Tools
The list of tools was chosen to keep the environment as simple as possible. These tools are standard in most Sitecore development environments

1. The Sitecore 8.2.3 XP deployment files.
2. The Azure hosting environment
3. Team Development for Sitecore Classic
4. Visual Studio Online with a build server 
5. Launch Sitecore project codebase
6. VS Code
7. Microsoft Azure Storage explorer

## Setup Launch Sitecore Build
The first step is to actually build Launch Sitecore on a build server. We want to build an MSDeploy package for code and a Sitecore Update Package for the Launch Sitecore items.

### Creating the projects
A local development environment for Launch Sitecore needs to be built. The files in the the VS solution were added to a VSO project and two TDS Classic projects were added to the soltuion. One for the Core database and one for Master.

The items in the Launch Sitecore package were added to the TDS projects and everything was commited to the VSO source code repository. A very similar solution structure for this can be found on [Sean Holmesby's LaunchSitecoreTDS repository](https://github.com/SaintSkeeta/LaunchSitecoreTDS). (Note that Sean's repository actually has 4 TDS projects, where the Base templates and Media items are separated into their own TDS Classic projects in order to demonstrate other TDS Classic features. This also means the assets/img folder is not part of the web project, so ensure you add that if you're using this example solution to test this out).

For our demo, the LaunchSitecore.Master project was setup to bundle the LaunchSitecore.Core project into a single update package. The Release configuration was setup to generate only an item package at build time.

### Creating the build
The VS build was easy to setup with minimal customizations. The first step was to choose an Azure Web App build:

![Create build template](./Images/CreateVsBuildTemplate.png?raw=true)

Next, the build was customized by disabling the azure deploy and test tasks:

![Build settings](./Images/VsBuildSettings.png?raw=true)

The Azure Deploy task was disabled since we don't want to deploy directly to Azure and the Test task was disabled because we don't have any tests at this time.

Since the build is creating Sitecore Update Packages, these packages need to be added to the build artifacts. This is done with the "Copy Packages to Artifacts" copy task. The configuration for this is:

![Copy Package Settings](./Images/VsBuildCopyPackages.png?raw=true)

The last step is to run the build. 
Now we have a working solution, with code and items being output as the build artifacts from the VSO build, which will can now use later in our deployment.










## 2. Preparing the default scripts and packages for Azure Deployment ##

This is part 2 in my series of blog posts on Sitecore deployments on Azure. The other posts in this series can be found here:-

1. Intro, Setting up the solution and VSO build [Link]
2. Preparing the default scripts and packages for Azure Deployment [this]
3. Adding custom modules to an Azure Deployment [Link]
4. Adding our project's code and items to the Azure Deployment [Link]
5. Deploying to a Slot [Link]
6. True Blue Green Deployments for Sitecore on Azure [Link]

Installing Sitecore in an Azure environment can be complex due to the large number of options availble to the user. I chose to use the XP environment (the most complex) with the lowest settings. This was done purely for research purposes, other environment configurations should work well with minor modifications to the scripts included here.
This post goes over preparing the default packages for a Sitecore Azure deployment. Later (in the next post) we will be extending this to add a custom module to the install.

### Azure deployment package storage
The Sitecore Azure packages and Azure templates need to be stored in [an online blob container](https://docs.microsoft.com/en-us/azure/storage/storage-create-storage-account) so the deployment scripts can access them. The arrangement of the azure templates is dependent on relative paths, so it is important to follow the exact procedures in this post.

#### Sitecore Components ####
The first set of files to upload to blob storage are the Sitecore deployment files. These should be located in a single folder. I called my storage container **sitecore82u3**:

![Sitecore assets](./Images/SitecoreAssets.png?raw=true)

The **Sitecore 8.2 rev. 170407_cd.scwdp.zip**, **Sitecore 8.2 rev. 170407_cm.scwdp.zip**, **Sitecore 8.2 rev. 170407_prc.scwdp.zip** and **Sitecore 8.2 rev. 170407_rep.scwdp.zip** packages are the default packages from Sitecore. They can be downloaded for any particular Sitecore instance from that version's download page. i.e You can find the packages for Sitecore 8.2 Update 4 under the 'Download options for Azure AppService' section [here](https://dev.sitecore.net/Downloads/Sitecore_Experience_Platform/82/Sitecore_Experience_Platform_82_Update4.aspx). 


These files contain the full Sitecore installations, and should be stored in a non-public blob. This means you will have to use the Azure Storage Explorer to create [a shared access signature](https://docs.microsoft.com/en-us/azure/storage/storage-dotnet-shared-access-signature-part-1) for each file. The full URL's for each file with the shared access signature should be added to the appropriate location in your **azuredeploy.parameters.json** file. An example file is included in our [GitHub](https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/SC82U3_XP/azuredeploy.parameters.json.example).

Note: The **_nodb** and **_Bootload** packages seen in the image will be discussed later in this blog post series. They will not yet be needed for the default setup described in this post.

#### Deployment Scripts ####

##### Additional Change Required for Sitecore 8.2 Update 4 (rev. 170614) #####
When testing with Sitecore 8.2 Update 4, we found that the deployment failed with the error.
`"message": "Package deployment failed\r\nAppGallery Deploy Failed:
'Microsoft.Web.Deployment.DeploymentClientServerException: Missing source parameter 'Social Link Domain' (Social Link
Domain). This must be set for successful synchronization.`

As it turns out, there is an additional parameter in the deployment package, which is not references in the parameters. [Bas Lijten](http://blog.baslijten.com/) pointed out to me that to fix this, you can either manually add that parameter to the ARM template, or rebuild the Web Deploy Package, removing the parameter.
We opted to add it to the ARM template, passing a blank value. the following was added to the nested/application.json template file, for the CM deployment (the parameter is only required on CM for the xp setup)
`"Social Link Domain": ""`
The updated version of this file can be found on our [Github repo](https://github.com/HedgehogDevelopment/AzureDeployTemplates/tree/master/sitecore/xp/nested/application.json.8.2.4.fix).  Within there we currently hard code the domain used by the Social Connect module....but you can modify it to read from parameters if you like, passing in a correct value. For now, the hard coded value gets us past the deployment issue, so grab the file and rename it to application.json, overwriting the default one that comes from Sitecore's repo. (it's a  copy of the files from [Sitecore's repo](https://github.com/Sitecore/Sitecore-Azure-Quickstart-Templates/blob/master/Sitecore%208.2.3/xp/nested/application.json) with the change above added, is up to date as of the 13th of July, 2017).

##### Uploading the Default Scripts #####
One of the problems we ran into building our deployments for Sitecore 8.2 update 3 (using v1.1 of the Sitecore Azure Toolkit) was that the scripts and templates needed to be referenced via a URL instead of the local file system. The 8.2 update 1 scripts (with v1.0 of the Sitecore Azure Toolkit) worked fine if they were on the local file system, but the newer method did not.

This initially caused us problems because certain scripts needed to be stored in specific folders relative to other scripts and the shared access token got in the way of constructing the urls.

#### Deployment Scripts: Option 1 - Give public access  ####
Our solution to this was to create a public blob storage container called **sitecore** and store all of the scripts in there. Since it was public, no shared access token was needed and everything worked correctly.

This was the option we went with....being the easiest to setup. You can see an alternative to this method further down the page.

The default ARM templates need to be uploaded into a storage container. Download the default ARM template scripts from the [Sitecore GitHub repository](https://github.com/Sitecore/Sitecore-Azure-Quickstart-Templates/tree/master/Sitecore%208.2.3/xp) repository. These scripts need to be uploaded into the **sitecore** Blob Container into a folder called **xp**. Everything in the /Sitecore 8.2.3/xp folder from Sitecore's default repository should be uploaded to the **xp** folder in the storage container.

![Upload Azure Templates](./Images/UploadAzureTemplatestoBlobStorage.png?raw=true)

Finally, grant public access to the container by right clicking it, and selecting 'Set Public Access Level...'. Grant Public read access for container and blobs, and click Apply.
![Set Public Access Level](./Images/SetPublicAccessLevel.png?raw=true)

Now you can navigate to the azuredeploy.json file in the Azure Storage Explorer, right click it, select Properties and retrieve the Uri property. This will be the URL you set in the PowerShell script later as the -ArmTemplateUrl value.

#### Deployment Scripts: Option 2 - Give a single SAS to the entire templates container  ####
An alternative way of granting access to the ARM templates is to grant a Shared Access Signature on the container (instead of giving it public access), and then set the `$templatelinkAccessToken` parameter. You can do this by passing in the $templatelinkAccessToken value though the -SetKeyValue argument in your deployment. A full explanation can be found [here](http://lets-share.senktas.net/2017/07/sitecore-on-azure-sas-token.html).

Now you have the ARM templates in a storage container, and the packages also in a container, this should be everything you need to install the default XP instance in Sitecore Azure.

### Running the install script
An install script called **Install.ps1.example** has been included in our [GitHub](https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/SC82U3_XP/Install.ps1.example). This will need to be renamed to **Install.ps1** and modified slightly to contain paths to your Sitecore license file, [Sitecore Azure Toolkit](https://doc.sitecore.net/cloud/working_with_sitecore_azure_toolkit/deployment/getting_started_with_sitecore_azure_toolkit) and the ArmTemplateUrl described above. If you went with Option 2 for getting the URLs for the ARM templates, you may also need to modify the script to pass in the appropriate parameters as well.

Once the file has been modified, update your local azure.deploy.parameters.json file with your blob storage URLs (to the CM, CD, PRC and REP packages), and Mongo connection strings (you can setup some free ones using [MLab](http://www.mlab.com/). You also need to update the other parameters with usernames/passwords as you wish, as described [here](https://doc.sitecore.net/cloud/working_with_sitecore_azure_toolkit/deployment/getting_started_with_sitecore_azure_toolkit).

Save the file, and run the Install.ps1 script from PowerShell. It will prompt you for credentials and create your default environment. After about 20-30 minutes, you will have a working, default Sitecore instance.

Next we will look into adding custom modules to our install process.







## 3.  Adding custom modules to an Azure Deployment ##

This is part 3 in my series of blog posts on Sitecore deployments on Azure. The other posts in this series can be found here:-

1. Intro [Link]
2. Preparing the scripts and packages for Azure Deployment [Link]
3. Adding custom modules to an Azure Deployment [this]
4. Adding our project's code and items to the Azure Deployment [Link]
5. Deploying to a Slot [Link]
6. True Blue Green Deployments for Sitecore on Azure [Link]

In the previous post, we setup a default Sitecore install, using the basic packages from Sitecore. Now we want to modify that install so that our initial install contains the [Sitecore Package Deployer](https://github.com/HedgehogDevelopment/SitecorePackageDeployer/) module. This module allows us to drop in Sitecore Update Packages on the file system, which will automatically be installed into the website. This is an excellent way for us to enable continuous integration to the website, being able to install our item updates to the website along with our code.

#### Cleanup Prior Post's Resource Group #### 
First, make sure you remove the resource group you created in the previous blog post from your Azure account. We are completely recreating that entire resource group....but, as mentioned, we're adding the custom package. This way our default install will be Default Sitecore + the Module.

#### Bootstrap Module ####
The **Sitecore.Cloud.Integration.Bootload.wdp.zip** file was obtained from the Sitecore GitHub mentioned in this article: [Configure the Bootloader module for a Sitecore deployment ](https://doc.sitecore.net/cloud/working_with_sitecore_azure_toolkit/deployment/configure_the_bootloader_module_for_a_sitecore_deployment).

Upload it to your online blob storage container, the same way we uploaded the CM, CD, PRC and REP packages earlier (into the sitecore82u3 container).

#### Import Cmdlets for Module Package Creation ####
The Sitecore Azure Toolkit has some additional Cmdlets that allow you to create scwdp packages from modules. Typically these modules come in the form of Zip packages, that we find from the Sitecore Marketplace, or as .update packages, like those that can be created through TDS Classic.

The [Sitecore documentation](https://doc.sitecore.net/cloud/working_with_sitecore_azure_toolkit/packaging/the_web_deploy_packages_for_a_module) for creating these packages mentions the use of the `ConvertTo-SCModuleWebDeployPackage` Cmdlet. To use this Cmdlet run the following in a PowerShell window.
`Import-Module .\Tools\Sitecore.Cloud.Cmdlets.dll -Verbose`
Notice that this pulls in the Cmdlets from the DLL, not the psm1 script that was used earlier.
This will bring in a bunch of Cmdlets that help us create packages for Sitecore deployments, including the one mentioned above. (Note: Beware that a similarly named Cmdlet, ConvertTo-SitecoreWebDeployPackage, was already brought in by the psm1 import. This Cmdlet produced incorrect packages for me, so I would advise against using it for now).

#### Create the Sitecore Package Deployer Package ####

##### Option 1: Use the above Cmdlet to create the package #####
Using the above Cmdlet, create the scwdp.zip package from your update or zip package.

`ConvertTo-SCWebDeployPackage -Path [PathToUpdatePackage] -Destination [FolderToSaveSCWDPPackage]`

Note: For more advanced scenarios, you can modify the output module package as described by the [Sitecore documentation](https://doc.sitecore.net/cloud/working_with_sitecore_azure_toolkit/packaging/the_web_deploy_packages_for_a_module). This can allow you to apply transformations, embed files, adjust parameters etc. as needed for a more complex package and deployment.

##### Option 2: Manually Create the Package #####
Initially, when attempting to take the Sitecore Package Deployer module's update file, and using these commands on it, I found that the toolkit didn't correct package up the module. It seems as those these commands work find on the basic Sitecore modules (WFFM, EXM, SXA etc.) but not for any other modules.

To get around this, I copied the package for the bootloader, unzipped it...and kept the same structure inside. I then copied over the Sitecore Package Deployer files into that directory.
Then I zipped it up, and renamed it to .scwdp.zip. Simple!
We've uploaded the resulting scwdp.zip file to our Github repo, here. [https://github.com/HedgehogDevelopment/AzureDeployTemplates/tree/master/sitecore/SitecorePackageDeployer/SitecorePackageDeployer-1.8.scwdp.zip]


Once you have a properly build scwdp.zip package, upload it to your online blob storage container like the other packages.

#### Sitecore Package Deployer Configuration ####
The module requires some configuration for itself. As we can see, the bootloader also comes with a .json file (addons/bootloader.json).
I took this file, and modified it for the Sitecore Package Deployer module.
Here is the result:-
[https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/sitecore/SitecorePackageDeployer/SitecorePackageDeployer.azuredeploy.json]

Now upload this json file to your blob storage folder. I placed it in the SitecorePackageDeployer folder.

#### Module Configuration ####
The last step is to wire it all up.
To install the Sitecore Package Deployer into your Sitecore environments we just need to configure it as a module in the **azuredeploy.parameters.json** file:

    "modules": {
      "value": {
        "items": [
          {
            "name": "bootloader",
            "templateLink": "https://????.blob.core.windows.net/sitecore/xp/addons/bootloader.json",
            "parameters": {
              "msDeployPackageUrl": "https://????.blob.core.windows.net/sitecore82u3/Sitecore.Cloud.Integration.Bootload.wdp.zip?[shared access signature]"
            }
          },
          {
            "name": "sitecore-package-deployer",
            "templateLink": "https://????.blob.core.windows.net/sitecore/SitecorePackageDeployer/SitecorePackageDeployer.azuredeploy.json",
            "parameters": {
              "msDeployPackageUrl": "https://????.blob.core.windows.net/sitecore/SitecorePackageDeployer/SitecorePackageDeployer-1.8.scwdp.zip"
            }
          }
        ]
      }
    }

You will need to configure the urls in the above module snippet to point at the correct locations in your blob storage.

You can obtain an example script for the above install from the file **SC82U3_XP/azuredeploy.parameters.json.example** from [here](https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/SC82U3_XP/azuredeploy.parameters.json.example).

Notice that the Bootloader module is defined first in the items array. This is that bootloader that we pulled down from Sitecore earlier. It is a tiny module that facilitates the installation of custom modules...which, in this case, is our Sitecore Package Deployer.

The Sitecore Package Deployer configuration follows, pointing to our new scwdp package, and configuration.

Running the same Install.ps1 script from the previous post now builds up an entire Sitecore Azure instance, WITH our custom module included.

In the next post, we will look at adding our own project's built code and items to the install.






## 4.  Adding our project's code and items to the Azure Deployment ##

This is part 4 in my series of blog posts on Sitecore deployments on Azure. The other posts in this series can be found here:-

1. Intro, Setting up the solution and VSO build [Link]
2. Preparing the default scripts and packages for Azure Deployment [Link]
3. Adding custom modules to an Azure Deployment [Link]
4. Adding our project's code and items to the Azure Deployment [this]
5. Deploying to a Slot [Link]
6. True Blue Green Deployments for Sitecore on Azure [Link]

In the previous post, we setup a complete Sitecore Azure instance, adding some custom modules to the default install.

Now we want to modify the scripts so that the compiled LaunchSitecore site is also provisioned into the new XP environment that setup. To make this easy, we decided to use the MSDeploy package created during the VSO build (see part 1 in this series). This package contains all the compiled code for the site. The compiled code for the CM and CD should be exactly the same.
 
#### Cleanup Prior Post's Resource Group #### 
First, make sure you remove the resource group you created in the previous blog post from your Azure account. We are completely recreating that entire resource group....but, as mentioned, we're adding our project's code into the mix (through the MSDeploy package our build created). This way our default install will be Default Sitecore + the Sitecore Package Deployer Module + the MSDeploy package from our project.

Setting up the install script to push an MSDeploy package generated by a build server is relatively simple.

#### Upload the custom scripts to allow for MSDeploy packages to be installed. ####
The first step is to upload our custom scripts to the **sitecore** container in blob storage that was created earlier (with the default scripts). Upload our [custom scripts for MSDeploy](https://github.com/HedgehogDevelopment/AzureDeployTemplates/tree/master/sitecore/xp/custom).
Place these in the same relative folder path (/xp/custom) so that the relative paths continue to match up.

![Upload Scripts](./Images/CreateSitecoreFolderInBlobStorage.png?raw=true)

#### Updating the deploy parameters
The deploy script needs to be configured to deploy the MSDeploy package into the new instance using the "modules" confiuguration section of the **azuredeploy.parameters.json** file. This is the same location that we adding the custom module, the Sitecore Package Deployer, in the previous post.

    "modules": {
      "value": {
        "items": [
          {
            "name": "bootloader",
            "templateLink": "https://????.blob.core.windows.net/sitecore/xp/addons/bootloader.json",
            "parameters": {
              "msDeployPackageUrl": "https://????.blob.core.windows.net/sitecore82u3/Sitecore.Cloud.Integration.Bootload.wdp.zip?[shared access signature]"
            }
          },
          {
            "name": "sitecore-package-deployer",
            "templateLink": "https://????.blob.core.windows.net/sitecore/SitecorePackageDeployer/SitecorePackageDeployer.azuredeploy.json",
            "parameters": {
              "msDeployPackageUrl": "https://????.blob.core.windows.net/sitecore/SitecorePackageDeployer/SitecorePackageDeployer-1.8.scwdp.zip"
            }
          },
          {
            "name": "launch-sitecore",
            "templateLink": "https://????.blob.core.windows.net/sitecore/custom/InstallMSDeployPackage.azuredeploy.json",
            "parameters": {
              "msDeployPackageUrl": "https://????.blob.core.windows.net/LaunchSitecore/Release1.2.zip?[shared access signature]"
            }
          }
        ]
      }
    }

The first two modules should be the same as configured above. The last one is the new one, and it uses the InstallMSDeployPackage script from our [GitHub](https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/sitecore/xp/custom/InstallMSDeployPackage.azuredeploy.json) and the MSDeploy package created during the build.

Simply upload the MSDeploy package to your blob storage, just like the other packages, and copy the URL (with Shared Access Signature) into the config.
Also upload the InstallMSDeployPackage.azuredeploy.json file into your blob storage, and copy the URL into the config.

That's all it takes to get out custom code included in the default install. We can now run the Install.ps1 script to setup the entire instance, with the custom module and our project code included.

### Deploying the Sitecore Items
Once the website is setup and running, the Sitecore items can be deployed to the new sitecore instance using the Sitecore Update Package generated during the build and the Sitecore Package Deployer installed on the CM. Simply ftp the .scitem.update package created during the build to the **[cm ftp address]/site/wwwroot/App_Data/SitecorePackageDeployer** folder. The package deployer will find the update package and install the items in the Sitecore database. 

**Please Note:** We experienced some performance problems deploying items on the CM server when the application logging was set to "Information". Your results may be different. Please see these options for improving the performance of the update package installation. [https://sitecore.stackexchange.com/questions/6384/filewatcher-error-internal-buffer-overflow]

When the item deployment completes, you should publish the site and have a complete working Sitecore instance in the cloud.

In the next post, we will go into Blue/Green deployments, utilizing an Azure 'staging slot' to give us Zero down time deployments.






## 5. Deploying to a Slot ##

This is part 5 in my series of blog posts on Sitecore deployments on Azure. The other posts in this series can be found here:-

1. Intro, Setting up the solution and VSO build [Link]
2. Preparing the default scripts and packages for Azure Deployment [Link]
3. Adding custom modules to an Azure Deployment [Link]
4. Adding our project's code and items to the Azure Deployment [Link]
5. Deploying to a Slot [this]
6. True Blue Green Deployments for Sitecore on Azure [Link]

In the previous post, we setup have our complete Sitecore Azure setup, including a custom module and our initial project included.

At this point, we want to setup Azure staging slots, so the next release of our project can go there. This allows up to deploy the new code to a private website (the slot), and test it out, before pushing it live for the public to see.
We are going to script this, to make this really easy for the devops team to automate. The following tasks need to be performed:

- Create a 'databaseless' cd package.
- Configure the deployment parameters for the slot
- Setup a powershell script to run the deployment


### Create and Upload the Databaseless Package
The **Sitecore 8.2 rev. 170407_cd-nodb.scwdp.zip** was obtained by following the directions on Rob's excellent blog post [Blue Green Sitecore Deployments on Azure](https://www.robhabraken.nl/index.php/2740/blue-green-sitecore-deployments-on-azure/). Please see the section toward the bottom entitled **Databaseless SCWDPs**.

Upload this package to your blob storage.

### Configuring the deployment parameters
Using the file **azuredeploy.parameters_slot.json.example** [https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/SC82U3_XP/azuredeploy.parameters_slot.json.example] as a starting point, create a **azuredeploy.parameters_slot.json** file, which will make configuring the deployment much easier. Most of the settings should be the same as the settings in the **azuredeploy.parameters.json** file. The notable differences are the paths to the modules (the '_cdslot' variations) and the additional settings for the web and master database servers. *The package referenced in the CD package will reference the databaseless package we just created and uploaded.*

The **azuredeploy.parameters_slot.json** should be updated to point at a new MSDeploy package for the instance of Launch Sitecore you are deploying. This will push a new version of the code.

As with the earlier posts, take the _cdslot configuration files for the bootloader [https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/sitecore/xp/custom/bootloader_cdslot.json], SitecorePackageDeployer [https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/sitecore/SitecorePackageDeployer/SitecorePackageDeployer.azuredeploy_cdslot.json] and the InstallMSDeployPackage [https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/sitecore/xp/custom/InstallMSDeployPackage.azuredeploy_cdslot.json] and upload them into your Blob Storage.

You then need to get the public URLs for these files, and add them into your azuredeploy.parameters_slot.json file, mentioned above.

#### The CD Slot Arm Template
Now upload the main azuredeploy slot template [https://github.com/HedgehogDevelopment/AzureDeployTemplates/blob/master/sitecore/xp/azuredeploy.cd_slot.json] to your blob storage. (remember to keep the same relative path to the other arm template files as it is in our Github repo).


### The Powershell scripts
The powershell script to install the deployment slot is very similar to the script used to install the original instance, instead it uses the azuredeploy_cdslot template instead. 
The example script is called **ProvisionAndDeploySlot.ps1.example**. You should update the parameters to point to your Sitecore installation and execute the powershell script. This will install a slot called "cd_staging" in your azure web instance, along with the new version of the LaunchSitecore site (rememeber you updated the package path to the new MSDeploy package).

Once run, this entire Staging slot is provisioned with a clean version of the code from the new release. It is currently using the same databases as production though (more on that in the next post), but it is kept private, allowing us to test the new code out to see how our site looks, before affected any of our public users.

## Swapping live for Staging
Once the staging instance has tested and we are ready to push live, the instance can be easily swapped out with the one in production. Select the cd server in the Azure dashboard and click on the Swap button:

![Swap Instance](./Images/SwapInstance.png?raw=true)

Viewing the website, we can see that the new release of our code has been deployed to the production website....and because we had it running in the staging slot earlier, it has already been warmed up....so there is no downtime to our front end users.

In the next post we will talk more about making this a 'true' blue green deployment scenario, including taking a snapshot of the databases, creating backups, and rolling back a deployment.




## 6. True Blue Green Deployments for Sitecore on Azure ##
(Yet to be fleshed out)


This example uses the Sitecore Package Deployer to install Sitecore items. This allows new versions of the Sitecore items to be deployed very easily. Unfortunately, once those items are deployed into your instance of Sitecore, they could have adverse effects on the website that is running an older version of the code.

There are a number of possible solutions to this issue. The Azure environment can be easily controlled with Powershell, so many possible scenarios can be implemented to reduce or eliminate downtime depending on your needs.

A simple solution to reduce downtime in a complete blue/green deployment scenario is to backup the current web database and re-point the live environment to the backup. This will freeze the website and allow it to function while deploying and testing the new version. After deploying and testing the new version with new items, the staging slot can be swapped with the live slot. The old version of the website can be preserved for a few days incase there are issues, and deleted when no longer needed.

Backup & rollback scenarios are not covered by these scripts either. This can be easily accomplised by backing up the master & core databases along with the CM instance using PowerShell scripts. This isn't a perfect rollback scenario, but it will allow the instance to be restored to its pre-deployment state

# Conclusion
The latest version of Sitecore Azure is very powerful. With the appropriate planning, tooling and scripting, you can easily deploy and manage your Sitecore environments throughout the SDLC. Because of the tremendous flexibility and scriptability of Azure, many Sitecore hosting scenarios can be created and easily managed.