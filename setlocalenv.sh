export IAC_TEMPLATES_TAG=$IAC_TERRAFORM_MODULES_TAG
yq '.' environment.yaml > environment.json
for var in $(jq -r 'to_entries[] | "\(.key)=\(.value)"' ./environment.json); do export $var; done
export destroy_ansible_playbook="mojaloop.iac.control_center_post_destroy"
export d_ansible_collection_url="git+https://github.com/thitsax/iac-ansible-collection-roles.git#/mojaloop/iac"
export destroy_ansible_inventory="$ANSIBLE_BASE_OUTPUT_DIR/control-center-post-config/inventory"
export destroy_ansible_collection_complete_url=$d_ansible_collection_url,$ansible_collection_tag
export ANSIBLE_BASE_OUTPUT_DIR=$PWD/output
export TF_STATE_BASE_ADDRESS="https://${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/terraform/state"
export GITLAB_URL=$(jq -r '.gitlab_hosts_var_maps.server_hostname' environment.json)
export GITLAB_SERVER_TOKEN=$(jq -r '.gitlab_hosts_var_maps.server_token' environment.json)
export DOMAIN=$(jq -r '.all_hosts_var_maps.base_domain' environment.json)
export PROJECT_ID=$(jq -r '.docker_hosts_var_maps.gitlab_bootstrap_project_id' environment.json)
