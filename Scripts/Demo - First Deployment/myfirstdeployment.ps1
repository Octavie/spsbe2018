Login-AzureRmAccount

$ResourceGroupName = "SPSBE-FirstResourceGroup" 

New-AzureRmResourceGroup -Name $ResourceGroupName -Location "West Europe" 
New-AzureRmAppServicePlan -Name spsbe-appiesfirstserviceplan -Location "West Europe" -ResourceGroupName $ResourceGroupName  -Tier Free
New-AzureRmWebApp -Name spsbe-appiesfirstweb -AppServicePlan spsbe-appiesfirstserviceplan -ResourceGroupName $ResourceGroupName  -Location "West Europe" 


Connect-PnPOnline -Url https://mavenocha-admin.sharepoint.com
New-PnPSite -Type CommunicationSite -Title MyFirstSiteCollection -Url https://mavenocha.sharepoint.com/sites/myfirstsitecollection