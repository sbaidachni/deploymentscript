# Azure Deployment Script Test

This template demonstrates how we can use Azure Deployment Scripts to execute code in VNET environment.

The proposed environment contains a resource group, a storage account and Azure AI Cognitive Search service that are in the same VNET. The primary goal of the deployment script is to upload data into the storage account and create an entity (like an index) in AI Cognitive Search. It demonstrates how any random Python code can be executed at the end of the deployment process.

Step 1. Login to Azure

```bash
az login -t <your tenant>
export  ARM_SUBSCRIPTION_ID=<your-subscription-id> #use set for Windows
```

Step 2. Use terraform to deploy the resources

Navigate to the **infra** folder of the repo, and execute the following code from there:

```bash
terraform init
terraform plan
terraform apply -var="resource_group_name=<your resource group>" -var="resource_group_location=<resource group location>" -var="storage_account_name=<your storage account name>" -var="ai_search_name=<ai search name>"
```
