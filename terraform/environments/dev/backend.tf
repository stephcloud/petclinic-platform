terraform {
  backend "s3" {
    bucket       = "petclinic-terraform-state-720035686687"
    key          = "petclinic/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
