﻿# -skipLab1 indicates that the files should be copied to each environment's
# storage container, and that Azure Data Factory should not be provisioned.
# -skipLab4 indicates that HDInsight Kafka will not be used. This is the
# same as setting the provisionKafka parameter to 'No' within the
# azuredeploy.all.parameters.json file.
Param(
  [string] [Parameter(Mandatory = $true)] $subscriptionId,
  [string] [Parameter(Mandatory = $true)] $resourceGroupName,
  [string] [Parameter(Mandatory = $true)] $clusterName,
  [string] [Parameter(Mandatory = $true)] $clusterCount,
  [string] $resourceGroupLocation = 'eastus',
  [switch] $skipLab1
)

$destContainerName = "databricks-labs"
$sourceFolder = Get-Location
$clusterInstanceName = $clusterName
$resourceGroupInstanceName = $resourceGroupName

$skipLab1String = "No"
if ($skipLab1) {
  $skipLab1String = "Yes"
}

Login-AzureRmAccount 

$sub = Select-AzureRmSubscription -SubscriptionId $subscriptionId
Write-Host("Deploying instances with prefix " + $clusterInstanceName + " in Resource Group " + $resourceGroupInstanceName + " in subscription " + $sub.Subscription.SubscriptionName + " (" + $sub.Subscription.SubscriptionId + ")")
Set-Location $sourceFolder
.\Deploy-AzureResourceGroup.ps1 -ResourceGroupName $resourceGroupInstanceName `
  -ResourceGroupLocation $resourceGroupLocation `
  -TemplateFile 'azuredeploy.all.json' `
  -TemplateParametersFile 'azuredeploy.all.parameters.json' `
  -ClusterName $clusterInstanceName `
  -ClusterCount $clusterCount `
  -SkipLab1 $skipLab1String
$storageAccountName = $clusterInstanceName
Select-AzureRmSubscription -SubscriptionId $subscriptionId

$storageKey = (Get-AzureRmStorageAccountKey -Name $storageAccountName -ResourceGroupName $resourceGroupInstanceName).Value[0]

$sourceAccountName = "retaildatasamples"
$sourceContainer = "data"
$sourceSAS = "?sv=2017-04-17&ss=b&srt=co&sp=rl&se=2019-12-31T18:29:33Z&st=2017-09-18T10:29:33Z&spr=https&sig=bw1EJflDFx9NuvLRdBGql8RU%2FC9oz92Dz8Xs76cftJM%3D"
$contextSource = New-AzureStorageContext -StorageAccountName $sourceAccountName -SasToken $sourceSAS

Write-Host("Creating " + $clusterCount + " storage containers. This can take a while.")
$contextDest = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey
For ($i = 0; $i -lt $clusterCount; $i++) {
  $destContainerName = $clusterName + $i
  ### Create a Blob Container in the Storage Account
  New-AzureStorageContainer -Context $contextDest -Name $destContainerName;
    
  if ($skipLab1) {
    # Copy blob files to the storage container if skipping Lab 1
    Get-AzureStorageBlob -Context $contextSource -Container $sourceContainer -Blob "*.csv" | Start-AzureStorageBlobCopy -DestContext $contextDest -DestContainer $destContainerName
    Get-AzureStorageBlob -Context $contextSource -Container $sourceContainer -Blob "*.txt" | Start-AzureStorageBlobCopy -DestContext $contextDest -DestContainer $destContainerName
  }

  Write-Host("Copy the following to your Databricks cluster init configuration (blob files will be located in a container named '" + $destContainerName + "'):")
  Write-Host("spark.hadoop.fs.azure.account.key." + $storageAccountName + ".blob.core.windows.net " + $storageKey) -ForegroundColor Cyan
}
Write-Host("Storage container creation complete, and deployment operations are finished. If there are no errors, you are free to begin using the workspace and clusters.") -ForegroundColor Green