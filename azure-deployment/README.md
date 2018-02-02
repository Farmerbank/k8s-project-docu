Azure deployment
================

### Requirements
* Azure cli (2.0)
* Terraform
* rke

### Authenticate with Azure CLI
* Set subscription: `az account set --subscription="SUBSCRIPTION_ID"`

### Authenticate with Service Principal
* Set subscription: `az account set --subscription="SUBSCRIPTION_ID"`
* `az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID" -o json`

  JSON output gebruiken voor credentials:  `client_id == [appId]`, `client_secret == [password]`, `tenant_id == [tenant]`
* Login: `az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID`

### Deploy
* Create ssh key in .ssh_keys `ssh-keygen -t rsa -N '' -f .ssh_keys/id_rsa`
* export TF_VAR_params: `export TF_VAR_node_count=3` `export TF_VAR_ssh_public_key=$(cat .ssh_keys/id_rsa.pub)` `export TF_VAR_resource_group=rke`
* `terraform init`
* `terraform apply`
* `rke up`