<#
.SYNOPSIS
	Installs SPSBE 2018 Demo SPA

.DESCRIPTION

.PARAMETER Department
	Department prefix in 2-4 characters. E.g. SPS or MAV.
	Used as a prefix in naming all the Azure resources.

.PARAMETER Environment
	Environment that you are deploying to. Valid values are:
	 PRD (Production)
	 ACC (Acceptance)
	 TST (Test)
	 DEV (Development)

.PARAMETER Location
	Location for the deployment of the Azure Web App. Valid values are:
		eastasia,southeastasia,centralus,eastus,eastus2,
		westus,northcentralus,southcentralus,northeurope,
		westeurope,japanwest,japaneast,brazilsouth,
		australiaeast,australiasoutheast,southindia,centralindia,
		westindia,canadacentral,canadaeast,uksouth,ukwest,
		westcentralus,westus2,koreacentral,koreasouth


.EXAMPLE

	C:\PS> Deploy-SPADemo -Department MAV -Environment DEV -Location westeurope

.NOTES
	Author  : Octavie van Haaften (Mavention)
	For 	  : SPSBE 2018
	Date    : 20-10-2018
	Version	: 1.0
#>

#Requires -Version 5.0 -Modules AzureAD, AzureRM.Resources
[CMDLetBinding()]
Param(
    # Department
    [Parameter(Mandatory = $true, HelpMessage = "Department prefix in 2-4 characters. E.g. SYN or MAV")]
    [ValidateLength(2, 4)]
    [String]
    $Department,
    # Environment: [PRD/ACC/TST/DEV]
    [Parameter(Mandatory = $true, HelpMessage = "Environment: [PRD/ACC/TST/DEV]")]
    [ValidateSet("PRD", "ACC", "TST", "DEV")]
    [String]
    $Environment,
    # Location in format: [westeurope,eastus,etc.]
    [Parameter(Mandatory = $true, HelpMessage = "Location in format: [westeurope,eastus,etc.]")]
    [ValidateSet("eastasia", "southeastasia", "centralus", "eastus", "eastus2", "westus", "northcentralus", "southcentralus", "northeurope", "westeurope", "japanwest", "japaneast", "brazilsouth", "australiaeast", "australiasoutheast", "southindia", "centralindia", "westindia", "canadacentral", "canadaeast", "uksouth", "ukwest", "westcentralus", "westus2", "koreacentral", "koreasouth")]
    [String]
    $LocationPrimary
)


function Get-AzureRmWebAppPublishingCredentials($resourceGroupName, $webAppName, $slotName = $null){
	if ([string]::IsNullOrWhiteSpace($slotName)){
		$resourceType = "Microsoft.Web/sites/config"
		$resourceName = "$webAppName/publishingcredentials"
	}
	else{
		$resourceType = "Microsoft.Web/sites/slots/config"
		$resourceName = "$webAppName/$slotName/publishingcredentials"
	}
	$publishingCredentials = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2015-08-01 -Force
    	return $publishingCredentials
}

function Get-KuduApiAuthorisationHeaderValue($resourceGroupName, $webAppName, $slotName = $null){
    $publishingCredentials = Get-AzureRmWebAppPublishingCredentials $resourceGroupName $webAppName $slotName
    return ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishingCredentials.Properties.PublishingUserName, $publishingCredentials.Properties.PublishingPassword))))
}

function Upload-FileToWebApp($webAppName, $slotName = "", $resourceGroupName, $localPath, $kuduPath){

    $kuduApiAuthorisationToken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName
    if ($slotName -eq ""){
        $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    else{
        $kuduApiUrl = "https://$webAppName`-$slotName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    }
    $virtualPath = $kuduApiUrl.Replace(".scm.azurewebsites.", ".azurewebsites.").Replace("/api/vfs/site/wwwroot", "")

    Invoke-RestMethod -Uri $kuduApiUrl `
                        -Headers @{"Authorization"=$kuduApiAuthorisationToken;"If-Match"="*"} `
                        -Method PUT `
                        -InFile $localPath `
                        -ContentType "multipart/form-data"
}

#
#
# Variables
#
$Department = $Department.ToUpper()

switch ($LocationPrimary) {
    eastasia {$Region = "EA";	$RegionFull = "East Asia"}
    southeastasia {$Region = "SEA";	$RegionFull = "Southeast Asia"}
    centralus {$Region = "CU";	$RegionFull = "Central US"}
    eastus {$Region = "EU";	$RegionFull = "East US"}
    eastus2 {$Region = "EU2";	$RegionFull = "East US 2"}
    westus {$Region = "WU";	$RegionFull = "West US"}
    northcentralus {$Region = "NCU";	$RegionFull = "North Central US"}
    southcentralus {$Region = "SCU";	$RegionFull = "South Central US"}
    northeurope {$Region = "NE";	$RegionFull = "North Europe"}
    westeurope {$Region = "WE";	$RegionFull = "West Europe"}
    japanwest {$Region = "JW";	$RegionFull = "Japan West"}
    japaneast {$Region = "JE";	$RegionFull = "Japan East"}
    brazilsouth {$Region = "BS";	$RegionFull = "Brazil South"}
    canadacentral {$Region = "CC";	$RegionFull = "Canada Central"}
    canadaeast {$Region = "CE";	$RegionFull = "Canada East"}
    westcentralus {$Region = "WCU";	$RegionFull = "West Central US"}
    westus2 {$Region = "WU2";	$RegionFull = "West US 2"}
    australiaeast	{$Region = "AE";	$RegionFull = "Australia East"}
    australiasoutheast	{$Region = "ASE";	$RegionFull = "Australia Southeast"}
    southindia {$Region = "SI";	$RegionFull = "South India"}
    centralindia	{$Region = "CI";	$RegionFull = "Central India"}
    westindia {$Region = "WI";	$RegionFull = "West India"}
    uksouth {$Region = "US";	$RegionFull = "UK South"}
    ukwest {$Region = "UW";	$RegionFull = "UK West"}
    koreacentral	{$Region = "KC";	$RegionFull = "Korea Central"}
    koreasouth {$Region = "KS";	$RegionFull = "Korea South"}
}
$RegionPrimary = $Region

#
#
# Creating Resource Group
#
$ResourceGroupName = ("$($Department)-RG-AAWS-$($Environment)-$($RegionPrimary)").ToUpper()
Write-Host "Creating Resource Group $ResourceGroupName"

if (!($ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    $ResourceGroupTags = @{Department = "$Department"; DisplayName = "$ResourceGroupName"; ResourceGroup = "$ResourceGroupName"; Region = "$RegionPrimary"; Environment = "$Environment"}

    $ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LocationPrimary -Tag $ResourceGroupTags
}
else {
    Write-Host "Resource group $ResourceGroupName already exists."
}

Write-Host "Deploying AAWS using ARM Template. Please wait..."
$templateParameters = @{
  departmentPrefix = $Department
  environment = $Environment
  locationPrimary = $LocationPrimary
  regionPrimary = $RegionPrimary
}

#Deploying resources with the resource management file
$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, ".\SPSBE-DEMO-ARMTemplate.json")
$result = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFile `
    -TemplateParameterObject $templateParameters `
    -Force

#
#
# Uploading homepage to West Europe
#
#
Write-Host "Uploading custom homepage for West-Europe"
$webappName = $result.Outputs.webappNamePrimary.value
$FilePath = $PSScriptRoot + "\hostingstart-we.html"
Upload-FileToWebApp $webappName "" $ResourceGroupName $FilePath "hostingstart.html"

Write-Host "Finished"

[Diagnostics.Process]::Start( "https://$webappName.azurewebsites.net".ToLower() )


