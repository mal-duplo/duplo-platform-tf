name        = "platform-admin" 
region      = "us-east-1"    # match the original infra’s region
azcount     = 2
subnet_cidr = 24

# custom_data from the extractor -> goes into duplocloud_infrastructure_setting
settings = {
  K8sVersion                 = "1.34"
  EnableDefaultEbsEncryption = "true"
  EnableHelmOperatorFluxV2   = "True"
  K8sHelmOperator            = "flux2-2.17.0"
}