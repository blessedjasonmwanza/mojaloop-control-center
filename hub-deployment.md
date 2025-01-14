# EXPERIMENTAL: Mojaloop Hub On-Premise Deployment Guidelines  
This document outlines the Mojaloop Hub deployment process, with a specific focus on on-premise environments. The guidelines are intended for organizations seeking to use Mojaloop to enhance financial inclusion by providing interoperable digital financial services.

## Table of Contents  
1. [Introduction](#introduction)  
2. [Prerequisites](#prerequisites)  
3. [Getting Started](#getting-started)  
4. [Configuration](#configuration)  
5. [Deployment](#deployment)  

## Introduction
In this guide, we focus on the process of deploying Mojaloop Hub in an on-premise environment. An on-premise setup means that the entire system, including all components like servers and network infrastructure, will be hosted and managed internally within your organization's data center, instead of relying on cloud services.
### Key Components
1. Bastion Server: The bastion server acts as a secure gateway into your private network. Since direct access to internal servers is restricted, the bastion server allows administrative access (for example, through SSH) to these servers, while keeping them hidden from the external network. This minimizes security risks.
2. Internal HAProxy Server: HAProxy is used internally to manage and distribute network traffic across different services or microservices within your private network. The internal HAProxy ensures that the load is evenly distributed between various backend systems, ensuring high availability and performance of your internal applications.
3. External HAProxy Server: The external HAProxy server sits at the boundary of your network, handling incoming requests from external clients or the internet. It acts as a reverse proxy, routing these requests to the correct internal services. By balancing the load across multiple servers, it ensures better performance, fault tolerance, and scalability. It can also handle SSL encryption, securing the communication between clients and servers.
4. MicroK8s Cluster: MicroK8s is a streamlined version of Kubernetes designed to efficiently manage containerized applications.It orchestrates the deployment, scaling, and management of applications in containers across multiple nodes (servers) within your private network. Each node in the MicroK8s cluster runs both Kubernetes control plane components and worker nodes, facilitating resource management and application deployment.
5. NAT Gateway: The NAT (Network Address Translation) Gateway allows the instances in your private network (like the MicroK8s nodes) to access the internet while maintaining security. These instances can fetch updates, access external APIs, or interact with cloud services, but they remain hidden from the external world, minimizing exposure to potential security threats.
6. DNS Configuration: Domain Name System (DNS) setup is critical for routing traffic correctly. You will need to ensure that DNS records are properly configured to route traffic to the right servers, whether they are public or private. This is especially important for ensuring that external clients can access the services via a clear and reliable domain name.
7. High Availability and Scalability: The deployment utilizes various load balancing techniques (both internal and external) to ensure that the system is both highly available and scalable. This means that if one server fails, the system continues to operate without interruption. The system can also scale up to accommodate increased traffic and usage, ensuring consistent performance as demand grows.

![hub-on-premise](https://github.com/user-attachments/assets/712f85d0-5d85-4562-bb8c-ef5b0d7e1646)

## Prerequisites  
Ensure the following prerequisites are met before you begin:

### Base Infrastructure Minimum Requirements

| Component      | OS              | CPU    | RAM      | Storage                          | EIP   |
|----------------|-----------------|--------|----------|----------------------------------|-------|
| bastion        | Ubuntu 24.04 LTS | 1vCPU  | 1GB      | 10GB                             | 1 EIP |
| internal haproxy    | Ubuntu 24.04 LTS | 2vCPU  | 2GB      | 10GB                             |       |
| external haproxy    | Ubuntu 24.04 LTS | 2vCPU  | 2GB      | 10GB                             | 1 EIP |
| microk8s-1     | Ubuntu 24.04 LTS | 8vCPU  | 32GB     | 100GB                            |       |
| microk8s-2     | Ubuntu 24.04 LTS | 8vCPU  | 32GB     | 100GB                            |       |
| nicrok8s-3     | Ubuntu 24.04 LTS | 8vCPU  | 32GB     | 100GB                            |       |
| nat-gateway/instance |  |   |      |                                                     | 1 EIP |                                                                 

### DNS Records Configuration

**DNS Zone Requirements:**  
Ensure that at least one DNS zone is configured for `<hubdomain.com>` to allow the creation of the A record for `haproxy.<hubdomain.com>`.

Please create the following DNS record with in the AWS Route53:

| Domain Name                          | Record Type | IP Address         | TTL  |
|--------------------------------------|-------------|--------------------|------|
| haproxy.<hubdomain.com>                | A           | bastion-public-ip  | 300  |

## Configuration

### Configuring the External HAProxy Proxy Node

#### Install HAProxy
Run the following commands to install HAProxy:

```bash
apt-get update
apt-get upgrade
apt-get -y install haproxy
```

#### Update `/etc/haproxy/haproxy.cfg`
Modify the `/etc/haproxy/haproxy.cfg` file with the following configuration:

```yaml
frontend external-k8s-tls
  mode tcp
  bind <ext-haproxy-private-ip>:443
  default_backend external-k8s-tls

frontend external-k8s
  mode tcp
  bind <ext-haproxy-private-ip>:80
  default_backend external-k8s

backend external-k8s-tls
  mode tcp
  balance roundrobin
  option ssl-hello-chk
    server node1 <microk8s-1-private-ip>:32443 send-proxy-v2-ssl
    server node2 <microk8s-2-private-ip>:32443 send-proxy-v2-ssl
    server node3 <microk8s-3-private-ip>:32443 send-proxy-v2-ssl

backend external-k8s
  mode tcp
  balance roundrobin
    server node1 <microk8s-1-private-ip>:32080
    server node2 <microk8s-2-private-ip>:32080
    server node3 <microk8s-3-private-ip>:32080
```

#### Test and Restart HAProxy
1. Test the configuration for errors:
   ```bash
   haproxy -f /etc/haproxy/haproxy.cfg -c
   ```

2. Restart the HAProxy service:
   ```bash
   systemctl restart haproxy
   ```

### Configuring the Internal HAProxy Proxy Node

#### Install HAProxy
Run the following commands to install HAProxy:

```bash
apt-get update
apt-get upgrade
apt-get -y install haproxy
```

#### Update `/etc/haproxy/haproxy.cfg`
Modify the `/etc/haproxy/haproxy.cfg` file with the following configuration:

```yaml
frontend internal-k8s-tls
  mode tcp
  bind <int-haproxy-private-ip>:443
  default_backend internal-k8s-tls

frontend internal-k8s
  mode tcp
  bind <int-haproxy-private-ip>:80
  default_backend internal-k8s

backend internal-k8s-tls
  mode tcp
  balance roundrobin
  option ssl-hello-chk
    server node1 <microk8s-1-private-ip>:31443
    server node2 <microk8s-2-private-ip>:31443
    server node3 <microk8s-3-private-ip>:31443

backend internal-k8s
  mode tcp
  balance roundrobin
    server node1 <microk8s-1-private-ip>:31080
    server node2 <microk8s-2-private-ip>:31080
    server node3 <microk8s-3-private-ip>:31080
```

#### Test and Restart HAProxy
1. Test the configuration for errors:
   ```bash
   haproxy -f /etc/haproxy/haproxy.cfg -c
   ```

2. Restart the HAProxy service:
   ```bash
   systemctl restart haproxy
   ```

### Update Hub Repository in Gitlab

1. Update `custom-config/bare-metal-vars.yaml` with the appropriate values, ensuring no dummy values are used:
```yaml
external_load_balancer_dns: <ext-haproxy-public-ip>
nat_public_ips: ["<nat-publicip>"]
internal_load_balancer_dns: <<int-haproxy-private-ip>>
egress_gateway_cidr: <x.x.x.x/x>
bastion_public_ip: <bastion-public-ip>
haproxy_server_fqdn: haproxy.<hubdomain.com>
private_subdomain: "int.<hubdomain.com>"
public_subdomain: "<hubdomain.com>"
int_interop_switch_subdomain: intapi
ext_interop_switch_subdomain: extapi
target_group_internal_https_port: 31443
target_group_internal_http_port: 31080
target_group_external_https_port: 32443
target_group_external_http_port: 32080
target_group_internal_health_port: 31081
target_group_external_health_port: 32081
private_network_cidr: x.x.x.x/x
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----

  -----END OPENSSH PRIVATE KEY-----

os_user_name: ubuntu
base_domain: "<hubdomain.com>"
kubeapi_loadbalancer_fqdn: none
master_hosts_0_private_ip: "<microk8s-1-private-ip>"
agent_hosts: {}
master_hosts:
  <hostname-microk8s-1>:
    ip: <microk8s-1-private-ip>
    node_taints: []
    node_labels:
      workload-class.mojaloop.io/CENTRAL-LEDGER-SVC: "enabled"
      workload-class.mojaloop.io/CORE-API-ADAPTERS: "enabled"
      workload-class.mojaloop.io/CENTRAL-SETTLEMENT: "enabled"
      workload-class.mojaloop.io/QUOTING-SERVICE: "enabled"
      workload-class.mojaloop.io/ACCOUNT-LOOKUP-SERVICE: "enabled"
      workload-class.mojaloop.io/ALS-ORACLES: "enabled"
      workload-class.mojaloop.io/CORE-HANDLERS: "enabled"
      workload-class.mojaloop.io/KAFKA-CONTROL-PLANE: "enabled"
      workload-class.mojaloop.io/KAFKA-DATA-PLANE: "enabled"
      workload-class.mojaloop.io/RDBMS-CENTRAL-LEDGER-LIVE: "enabled"
      workload-class.mojaloop.io/RDBMS-ALS-LIVE: "enabled"
      workload-class.mojaloop.io/MONITORING: "enabled"
  <hostname-microk8s-2>:
    ip: <microk8s-2-private-ip>
    node_taints: []
    node_labels:
      workload-class.mojaloop.io/CENTRAL-LEDGER-SVC: "enabled"
      workload-class.mojaloop.io/CORE-API-ADAPTERS: "enabled"
      workload-class.mojaloop.io/CENTRAL-SETTLEMENT: "enabled"
      workload-class.mojaloop.io/QUOTING-SERVICE: "enabled"
      workload-class.mojaloop.io/ACCOUNT-LOOKUP-SERVICE: "enabled"
      workload-class.mojaloop.io/ALS-ORACLES: "enabled"
      workload-class.mojaloop.io/CORE-HANDLERS: "enabled"
      workload-class.mojaloop.io/KAFKA-CONTROL-PLANE: "enabled"
      workload-class.mojaloop.io/KAFKA-DATA-PLANE: "enabled"
      workload-class.mojaloop.io/RDBMS-CENTRAL-LEDGER-LIVE: "enabled"
      workload-class.mojaloop.io/RDBMS-ALS-LIVE: "enabled"
      workload-class.mojaloop.io/MONITORING: "enabled"
  <hostname-microk8s-3>:
    ip: <microk8s-3-private-ip>
    node_taints: []
    node_labels:
      workload-class.mojaloop.io/CENTRAL-LEDGER-SVC: "enabled"
      workload-class.mojaloop.io/CORE-API-ADAPTERS: "enabled"
      workload-class.mojaloop.io/CENTRAL-SETTLEMENT: "enabled"
      workload-class.mojaloop.io/QUOTING-SERVICE: "enabled"
      workload-class.mojaloop.io/ACCOUNT-LOOKUP-SERVICE: "enabled"
      workload-class.mojaloop.io/ALS-ORACLES: "enabled"
      workload-class.mojaloop.io/CORE-HANDLERS: "enabled"
      workload-class.mojaloop.io/KAFKA-CONTROL-PLANE: "enabled"
      workload-class.mojaloop.io/KAFKA-DATA-PLANE: "enabled"
      workload-class.mojaloop.io/RDBMS-CENTRAL-LEDGER-LIVE: "enabled"
      workload-class.mojaloop.io/RDBMS-ALS-LIVE: "enabled"
      workload-class.mojaloop.io/MONITORING: "enabled"
k6s_callback_fqdn: none
enable_k6s_test_harness: false
test_harness_private_ip: none
route53_external_dns_access_key: "<xxxxxxxxxxx>"
route53_external_dns_secret_key: "<xxxxxxxxxxx>"
enable_external_ingress_k8s_lb: true
enable_internal_ingress_k8s_lb: true
enable_external_egress_lb: true
external_dns_credentials_client_id_name: "AWS_ACCESS_KEY_ID"
external_dns_credentials_client_secret_name: "AWS_SECRET_ACCESS_KEY"
cert_manager_credentials_client_id_name: "AWS_ACCESS_KEY_ID"
cert_manager_credentials_client_secret_name: "AWS_SECRET_ACCESS_KEY"
dns_resolver_ip: 8.8.8.8
```

Create `custom-config/common-vars.yaml`:
```yaml
loki_ingester_retention_period: 24h
prometheus_retention_period: 1d
longhorn_backup_job_enabled: false
managed_svc_enabled: false
```

Create `custom-config/mojaloop-vars.yaml`:
```yaml
mojaloop_chart_version: 16.0.4
finance_portal_chart_version: 4.2.3
```

Create `custom-config/platform-stateful-resources.yaml`:
```yaml
central-ledger-db:
  logical_service_config:
    logical_service_port: 3306
```

### 5. Deployment  
To deploy your infrastructure, navigate to the CI/CD pipeline and trigger the `deploy-infra` job.
