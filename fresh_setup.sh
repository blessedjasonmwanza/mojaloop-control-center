rm -rf /.ansible
source setlocalenv.sh
terragrunt run-all init
terragrunt run-all apply --terragrunt-exclude-dir control-center-post-config --terragrunt-non-interactive
