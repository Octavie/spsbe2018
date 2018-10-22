<#
.SYNOPSIS
	Deploys SPSBE 2018 package and provisions a demo site

.DESCRIPTION

.PARAMETER Environment
	Environment that you are deploying to. Valid values are:
	 PRD (Production)
	 ACC (Acceptance)
	 TST (Test)
	 DEV (Development)

.PARAMETER PackageName
	Name of the SPFx package

.PARAMETER TemplateFile
	Filename of the PnP site template file

.EXAMPLE

	C:\PS> Provision-DemoSite -Environment PRD -TemplateFile pnp-spsbe-site-template.xml

.NOTES
	Author  : Octavie van Haaften (Mavention)
	For 	  : SPSBE
	Date    : 20-10-2018
	Version	: 1.0
#>

[CMDLetBinding()]
Param(
    # Environment: [PRD/ACC/TST/DEV]
    [Parameter(Mandatory = $true, HelpMessage = "Environment: [PRD/ACC/TST/DEV]")]
    [ValidateSet("PRD", "ACC", "TST", "DEV")]
    [String]
    $Environment,
    [Parameter(Mandatory = $true, HelpMessage = "Name of the SPFx package")]
    [string]
    $packageName,
    [Parameter(Mandatory = $true, HelpMessage = "Filename of the PnP Site Template")]
    [string]
    $TemplateFile
)

switch ($Environment) {

    "DEV" { $tenantName = "mavenocha"}
    "TST" { $tenantName = "mavenocha"}
    "ACC" { $tenantName = "mavenocha"}
    "PRD" { $tenantName = "mavenocha"}
}

$cred = Get-Credential -Message "Enter SPO Credentials"

Write-Host "Connecting to SPO"
Connect-PnPOnline -Url https://$tenantName.sharepoint.com -Credentials $cred

if ( $Environment -eq "PRD" ) {
    $siteTitle = "SPSBE 2018"
    $siteAlias = "demo-spsbe2018".ToLower()
}
else {
    $siteTitle = "SPSBE 2018 - $Environment"
    $siteAlias = "$Environment-demo-spsbe2018".ToLower()
}

Write-Host "Creating site $siteTitle"
$siteUrl = New-PnPSite -Type TeamSite -Title $siteTitle -Alias $siteAlias

Connect-PnPOnline -Url $siteUrl -Credentials $cred
Write-Host "Adding site app catalog"
Add-PnPSiteCollectionAppCatalog -Site $siteUrl

if ( $Environment -eq "PRD") {
    $packageFile = $packageName + ".sppkg"
}
else {
    $packageFile = $packageName + "-$Environment.sppkg"
}
$packageToDeploy = Join-Path $PSScriptRoot $packageFile

Write-Host "Adding package $packageToDeploy to Site AppCatalog"
Add-PnPApp -Path $packageToDeploy -Scope Site -Publish -SkipFeatureDeployment

# Let PnP finish adding the App (it's async)
Start-Sleep -Seconds 10

Write-Host "Applying custom template"
Apply-PnPProvisioningTemplate -Path $TemplateFile

Write-Host "Finished"
