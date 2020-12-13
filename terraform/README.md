# Terraform scripts

Some simple scripts to learn Terraform with.

- terraform init
- terraform plan
- terraform apply
- terraform show
- terraform destroy

# Hints

Ensure you have a valid AWS config in ~/.aws/crdentials. My examples use a profile called 'work-user'.

Override region for your purposes with eg:
- terraform apply -var region=eu-west-3
- terraform apply -var region=eu-west-1 -var inst-type=t4g.micro -var-file=arm.tfvars 
- terraform apply -var region=eu-west-1 -var db-inst-type=t4g.micro -var web-inst-type=t4g.micro -var-file=arm.tfvars
