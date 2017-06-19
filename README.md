# Azure Deploy Templates
The files in this repository are used to deploy Launch Sitecore to an Azure XP deployment using Sitecore 8.2 Update 3. I would like to thank [Rob Habraken](https://www.robhabraken.nl/) for his excellent articles, samples and tools for Sitecore Azure Deployments.

# Launch Sitecore in an Azure XP cloud deployment

The Launch Sitecore site is a good starting place for testing Sitecore deployments. It is a fairly simple site that demonstraits many different sitecore features. This makes it ideal for a test environment.

In this post, I will document the steps taken to deploy Launch Sitecore into the Sitecore Azure XP Environment. I will only show how to setup the CD using Blue/Green deployments. Other servers could be deployed this way if needed.

## The Tools
The list of tools was chosen to keep the environment as simple as possible. These tools are standard in most Sitecore development environments

1. The Sitecore 8.2.3 XP deployment files.
1. The Azure hosting environment
1. Team Development for Sitecore classic
1. Visual Studio Online with a build server 
1. Launch Sitecore
1. VS Code
1. Microsoft Azure Storage explorer

## Setup Launch Sitecore Build
The first step is to actually build Launch Sitecore on a build server. We want to build an MSDeploy package for code and an update package for the Launch Sitecore items.

### Creating the projects
To start, we setup Launch Sitecore in a local development environment. The files in the the VS solution were added to a VSO project and two TDS classic projects were added to the soltuion. One for the Core database and one for Master. 

The items in the Launch Sitecore package were added to the TDS projects and everything was commited to source control.

The LaunchSitecore.Master project was setup to bundle the LaunchSitecore.Core project into a single update package. The Release configuration was setup to generate only an item package at build time.

### Creating the build
The VS build was easy to setup with minimal customizations. The first step was to choose an Azure Web App build:

![Create build template](./images/CreateVsBuildtemplate.png)

Next, the build was customized by disabling the azure deploy and test tasks:

![Build settings](./images/VsBuildSettings.png)

Since the build is creating Sitecore Update Packages, these packages need to be added to the build artifacts. This is done with the "Copy Packages to Artifacts" copy task. The configuration for this is:

![Copy Package Settings](./images/VsBuildCopyPackages.png)

The last step is to run the build. The build artifacts will be used later.

## Deploying the Sitecore environment
There are a large number of steps to installing the Sitecore azure environment. I chose to use the XP environment with the lowest settings. This was done purely for research purposes, and other environment configurations should work correctly.

### Azure deployment package storage
When installing the Sitecore Azure packages, the packages and the Sitecore templates need to be stored in an online blob container so the build can access them. I will describe how these were setup. In some cases, the relative paths to the files are important.

#### Sitecore Components ####
The first set of files to upload to blob storage is the Sitecore deployment files. These should go in a folder together. I called my storage container **sitecore82u3**:

![Sitecore assets](./images/SitecoreAssets.png)

These files can be downloaded from http://dev.sitecore.net. The **Sitecore.Cloud.Integration.Bootload.wdp.zip** file was obtained from the Sitecore GitHub mentioned in this article: [Configure the Bootloader module for a Sitecore deployment ](https://doc.sitecore.net/cloud/working_with_sitecore_azure_toolkit/configuring/configure_the_bootloader_module_for_a_sitecore_deployment).

The **Sitecore 8.2 rev. 170407_cd-nodb.scwdp.zip** was obtained by following the directions on Rob's excellent blog post [Blue Green Sitecore Deployments on Azure](https://www.robhabraken.nl/index.php/2740/blue-green-sitecore-deployments-on-azure/). Please see the section toward the bottom entitled **Databaseless SCWDPs**.

These files contain the full Sitecore installations, and should be stored in a non-public blob. This means you will have to use the Azure Storage Explorer to create a shared access signature for each file.

#### Deployment Scripts ####
One of the problems we ran into building our deployments for Sitecore 8.2 update 3 was that the scripts needed to be referenced via a URL instead of the local file system. The 8.2 update 1 scripts were OK on the local file system.

This initially caused us problems because certain scripts needed to be stored in specific folders relative to other scripts and the shared access token got in the way of constructing the urls. Our solution to this was to create a public blob storage container called **sitecore** and store all of our scripts in there. Since it was public, no shared access signature was needed and everything worked correctly.

You can obtain the Sitecore toolkit deployment scripts from Sitecore's Git Repository at: [Sitecore-Azure-Quickstart-Templates](https://github.com/Sitecore/Sitecore-Azure-Quickstart-Templates). I created a folder under my /sitecore Blob Container called **xp** and uploaded everything in the /Sitecore 8.2.3/xp folder to it. This serves as the basis for your deployment scripts.

This should be everything you need to install the default XP instance in Sitecore Azure.

#### Sitecore Package Deployer ####
The next step is to install the Sitecore Package Deployer into your Sitecore environments. This is done by configuring it as a module:

    "modules": {
      "value": {
        "items": [
          {
            "name": "bootloader",
            "templateLink": "https://????.blob.core.windows.net/sitecore/BootLoader/bootloader.json",
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

The sitecore package deployer files from our Git repo should be uploaded to the **/sitecore/SitecorePackageDeployer** folder to enable these modules:

![Sitecore Package Deployer Folder](./images/SitecorePackageDeployerFolder.png)

You can obtain an example script for the above install from the file **SC82U3_XP/azuredeploy.parameters.json.example** in [GitHub](https://github.com/HedgehogDevelopment/AzureDeployTemplates).

### Running the install script###
An install script called **Install.ps1** has been included in our [GitHub](https://github.com/HedgehogDevelopment/AzureDeployTemplates). This will need to be modified slightly to contain paths to your Sitecore license file, [Sitecore Azure Toolkit](https://doc.sitecore.net/cloud/82/working_with_sitecore_azure/configuring_sitecore_azure/getting_started_with_sitecore_azure_toolkit) and blob storage repos described above.

Once the fole has been modified, run it from PowerShell and it will prompt you for credentials and create your environment.




