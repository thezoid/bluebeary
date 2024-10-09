# Terraform Deployment

## Overview

This project outlines the Terraform configuration for deploying a comprehensive Azure infrastructure.

## Resources to be Deployed

The following resources are part of this Terraform deployment:

- Azure Resource Groups
- Azure VNets and Subnets
- Azure Virtual Desktop Host Pools, Application Groups, and Workspaces
- Network Security Groups (NSGs) with barebones, predefined security rules
- Azure Bastion for secure RDP and SSH access
- A handful of standard servers to install core systems on (ex. SCCM, AD DS)

## Deployment Directions

Please ensure you review the Terraform files for detailed configurations and adjust the variables in `variables.tf` as per your project requirements. You should also create your own `terraform.tfvars` to define your variables.

1. **Initialization**: Run `terraform init` to initialize the Terraform environment and download the required providers.
2. **Planning**: Execute `terraform plan -out=tfplan` to review the deployment plan and ensure the configurations are as expected.
3. **Applying**: Deploy the resources with `terraform apply "tfplan"` to create the infrastructure in Azure.
4. **Verification**: Use the Azure portal or Azure CLI to verify the deployment of the resources.
5. **Destruction**: First plan the tear down of the reasources with `terraform plan -destroy -out=destroytfplan` and then run `terraform apply "destroytfplan"` to execute the tear down
