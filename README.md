# EKS-cluster-Monitoring
Creates an EKS cluster on AWS with Monitoring tools Grafana, Prometheus and Alertmanager setup.

## Getting started

Before running the provided script on your local machine, make sure to complete the following prerequisites:
1.	AWS Account and Permissions: Ensure you have an AWS account and the necessary permissions to create resources in AWS. The IAM user executing the Terraform script should have appropriate permissions to create and manage resources, such as VPCs, EKS clusters, EC2 instances, and other related resources.
2.	AWS CLI: Install the AWS Command Line Interface (CLI) on your local machine. The AWS CLI allows you to interact with AWS services from the command line. You can download the AWS CLI from the official AWS website: https://aws.amazon.com/cli/
3.	Terraform: Install Terraform, an infrastructure-as-code tool, to create, update, and manage your infrastructure. Download Terraform from the official website: https://www.terraform.io/downloads.html
4.	Configure AWS CLI: Run aws configure to set up your AWS CLI with the required AWS Access Key, Secret Key, default region, and output format. These credentials will be used by Terraform to interact with your AWS account.
5.	kubectl: Install the Kubernetes command-line tool, kubectl, to interact with the Kubernetes cluster. Download kubectl from the official Kubernetes website: https://kubernetes.io/docs/tasks/tools/install-kubectl/
6.	Helm: Install Helm, a package manager for Kubernetes, to manage and deploy applications on your Kubernetes cluster. Download Helm from the official website: https://helm.sh/docs/intro/install/
7.	Terraform Provider Plugins: Ensure that the required Terraform provider plugins are installed. The script uses the following providers:
•	AWS Provider
•	Kubernetes Provider
•	Helm Provider
Terraform automatically downloads the required providers when you run terraform init. Make sure your Terraform version supports the specified provider versions in the script.
8.	Configure Terraform Backend (Optional): If you want to store your Terraform state remotely (e.g., in an S3 bucket), configure the Terraform backend according to the official documentation: https://www.terraform.io/docs/language/settings/backends/index.html


## Deploy your EKS cluster and set up monitoring tools:

Once you have completed these prerequisites, you can proceed with the following steps to deploy your EKS cluster and set up monitoring tools:
1.	Create a new directory for your Terraform script and save the provided script in a file with a .tf extension, such as eks_cluster.tf.
2.	Open a terminal, navigate to the directory containing your Terraform script, and run terraform init to initialize your Terraform workspace. This command downloads the required provider plugins and sets up the backend for storing Terraform state.
3.	Run terraform validate to check the syntax and validate the configuration.
4.	Run terraform plan to review the proposed changes before applying them.
5.	Run terraform apply to create the resources defined in the script. This command will prompt you to confirm that you want to proceed with the changes. Type yes and press Enter to start the deployment process.
6.	After the terraform apply command completes successfully, you can use kubectl to interact with your new EKS cluster. The script generates a kubeconfig.yaml file that you can use to authenticate and communicate with the cluster. To set up kubectl, run:

`export KUBECONFIG=kubeconfig.yaml`

7.	To verify that your EKS cluster is running and the monitoring tools are deployed, run kubectl get pods --all-namespaces to list all the running pods in the cluster.
8.	To access the monitoring tools, such as Prometheus, Grafana, and Alertmanager, use the LoadBalancer service URLs or IPs assigned to these services. You can find

## Details of terraform script

Below is a detailed documentation of the terraform script to set up an EKS cluster in AWS and set up monitoring tools. The script is organized in blocks, and each block will be described.

**Block 1**: Variables
1.	region: The AWS region where the EKS cluster will be created (default: "eu-north-1").
2.	cluster_name: The name of the EKS cluster (default: "my-5EKS-cluster").
3.	availability_zones: List of availability zones to use for the subnets (default: ["eu-north-1a", "eu-north-1b", "eu-north-1c"]).
4.	private_subnets_cidrs: List of CIDR blocks for the private subnets (default: ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]).
5.	public_subnets_cidrs: List of CIDR blocks for the public subnets (default: ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]).

**Block 2**: Terraform Configuration
Defines the required providers and their versions:
1.	AWS provider: "hashicorp/aws" version ~> 4.0.
2.	Kubernetes provider: "hashicorp/kubernetes" version ~> 2.0.
3.	Helm provider: "hashicorp/helm" version ~> 2.0.

**Block 3**: AWS Provider Configuration
Sets the AWS region to the value of the region variable.

**Block 4**: VPC Module
Creates a VPC using the terraform-aws-modules/vpc/aws module, version 4.0.1. The VPC is configured with:
1.	Name: cluster_name.
2.	CIDR block: 10.0.0.0/16.
3.	Availability zones, private subnets, and public subnets set to the values of the respective variables.
4.	Enabled NAT gateway with a single NAT gateway.
5.	Enabled DNS hostnames and auto-assigning public IP addresses to instances launched in the subnets.

**Block 5**: Security Group for Worker Group Management
Creates a security group for worker group management, with ingress rules allowing traffic on TCP ports 0-65535 from the specified CIDR blocks.

**Block 6**: Kubernetes Secret
Creates a Kubernetes secret named "terraform-token" with custom data in the "kube-system" namespace. This secret depends on the kubernetes_service_account.terraform resource.

**Block 7**: EKS Module
Creates an EKS cluster using the terraform-aws-modules/eks/aws module, version 19.13.1. The cluster is configured with:
1.	Name: cluster_name.
2.	Subnet IDs set to the public subnets created in the VPC module.
3.	Tags: Terraform and KubernetesCluster.
4.	VPC ID set to the VPC created in the VPC module.
5.	Public and private cluster endpoint access.
6.	Managed node groups with instance type t3.large and desired capacity 2, max capacity 3, and min capacity 1.

**Block 8**: Update Kubeconfig
Updates the local Kubeconfig file with the EKS cluster's information. This requires the AWS CLI to be installed locally where Terraform is executed.

**Block 9-11**: Kubernetes and Helm Providers
Configures the Kubernetes and Helm providers using the EKS cluster's endpoint, CA certificate, and AWS CLI authentication token. The providers are set up as follows:

**Block 9**: Kubernetes Provider with Alias
1.	Alias: "bootstrap".
2.	Host: EKS cluster endpoint.
3.	Cluster CA certificate.
4.	Exec authentication with AWS CLI.

**Block 10**: Kubernetes Provider
1.	Host: EKS cluster endpoint.
2.	Cluster CA certificate.
3.	Exec authentication with AWS CLI.

**Block 11**: Helm Provider
1.	Kubernetes settings: EKS cluster endpoint, cluster CA certificate.
2.	Exec authentication with AWS CLI.

**Block 12**: Monitoring Namespace
Creates a Kubernetes namespace named "monitoring".

**Block 13**: Service Account for Terraform
Creates a Kubernetes service account named "terraform" in the "kube-system" namespace with the service account token automatically mounted.

**Block 14**: Cluster Role Binding
Creates a Kubernetes cluster role binding named "terraform" that binds the "cluster-admin" cluster role to the "terraform" service account created earlier.

**Block 15**: Prometheus Helm Release
Deploys the "kube-prometheus-stack" Helm chart from the "https://prometheus-community.github.io/helm-charts" repository in the "monitoring" namespace. The release is named "prometheus" and depends on the "monitoring" namespace. The service type is set to "LoadBalancer".

**Block 16**: Grafana Helm Release
Deploys the "grafana" Helm chart from the "https://grafana.github.io/helm-charts" repository in the "monitoring" namespace. The release is named "grafana" and depends on the "monitoring" namespace. The service type is set to "LoadBalancer".

**Block 17**: AWS EBS CSI Driver Helm Release
Deploys the "aws-ebs-csi-driver" Helm chart from the "https://kubernetes-sigs.github.io/aws-ebs-csi-driver" repository in the "kube-system" namespace. The release is named "aws-ebs-csi-driver" and has the following configurations:
1.	Enable volume scheduling.
2.	Enable volume resizing.
3.	Enable volume snapshot.
4.	Set the AWS region.

**Block 18**: Kubernetes Storage Class
Creates a Kubernetes storage class named "ebs-gp3" with the storage provisioner "ebs.csi.aws.com", reclaim policy "Delete", volume binding mode "WaitForFirstConsumer", and the EBS volume type set to "gp3".

**Block 19**: Alertmanager Helm Release
Deploys the "alertmanager" Helm chart from the "https://prometheus-community.github.io/helm-charts" repository in the "monitoring" namespace. The release is named "alertmanager" and depends on the "monitoring" namespace. The service type is set to "LoadBalancer" and has custom tolerations for "node.kubernetes.io/not-ready" with a toleration seconds of 300.

Note- If Alertmanager is stuck on pending, troubleshoot by checking pod logs and PVC provisioning. Most likely there is an issue with IAM role attached to instance which cannot create EBS volume. Resolution is to create IAM policy (see json below) to read and write EBS features and attach to the IAM role. Once completed, you can redeploy Alertmanager and it should work.

Json to create the IAM policy
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteSnapshot",
                "ec2:DeleteTags",
                "ec2:DeleteVolume",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInstances",
                "ec2:DescribeSnapshots",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumesModifications",
                "ec2:DetachVolume",
                "ec2:ModifyVolume"
            ],
            "Resource": "*"
        }
    ]
}
```


**Block 20-22**: Outputs
1.	eks_cluster_id: The name/ID of the EKS cluster.
2.	eks_cluster_security_group_id: The security group ID attached to the EKS cluster.
3.	aws_auth_configmap_yaml: The Kubernetes ConfigMap in YAML format.


## Generate the web links 
To generate the web links for Prometheus, Grafana, and Alertmanager, you can use the following kubectl commands:

1.	**Prometheus**:
_Copy code_
`kubectl get svc -n monitoring prometheus-kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'` 

If the output is empty, try the following command for IP-based LoadBalancer:
_Copy code_
`kubectl get svc -n monitoring prometheus-kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}' `

2.	**Grafana**:
_Copy code_
`kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' `

If the output is empty, try the following command for IP-based LoadBalancer:
_Copy code_
`kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}' `

3.	**Alertmanager**:
_Copy code_
`kubectl get svc -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'` 

If the output is empty, try the following command for IP-based LoadBalancer:

_Copy code_
`kubectl get svc -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` 


After obtaining the hostname or IP address, you can access each monitoring tool by opening the provided link in a web browser with the appropriate default port:
•	Prometheus: http://[HOSTNAME_OR_IP]:9090
•	Grafana: http://[HOSTNAME_OR_IP]:3000
•	Alertmanager: http://[HOSTNAME_OR_IP]:9093


To reset the Grafana admin password, follow these steps: Username by default is admin
You can use the grafana-cli command within the Grafana pod to reset the admin password. Follow these steps:

1.	Find the Grafana pod name:
Run the following command to list the Grafana pod(s) in the monitoring namespace:

_Copy code_
`kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana `

Take note of the Grafana pod name, which should look like grafana-xxxxxxx-xxxxx.

2.	Execute a shell in the Grafana pod:
Replace <GRAFANA_POD_NAME> with the actual Grafana pod name obtained in the previous step and run the following command:

_Copy code_
`kubectl exec -it <GRAFANA_POD_NAME> -n monitoring -- /bin/bash `

This will open an interactive shell inside the Grafana pod.

3.	Reset the Grafana admin password:
In the pod shell, run the following command to reset the Grafana admin password, replacing <NEW_PASSWORD> with the desired new password:

_Copy code_
`grafana-cli admin reset-admin-password <NEW_PASSWORD> `

After running the command, you should see a confirmation message indicating that the admin password has been reset.

4.	Exit the Grafana pod shell:
Type exit and press Enter to exit the shell inside the Grafana pod.

5.	Access Grafana with the new password:
Open the Grafana web interface in your browser using the previously obtained link (http://[HOSTNAME_OR_IP]:3000). Log in with the username admin and your new password.


## Grafana Dashboards

Dashboards can either be created or imported on the GUI. To import Dashboards to Grafana, follow steps Below;

1. Add Data Source to Grafana e.g. Prometheus, CloudWatch etc. in Administration - Data Sources
2. Once data source has been added, navigate to Dashboards, click on Add Dashboards
3. Select import Dashboards
4. You can then import various dashboards using JSON files created or gotten from https://grafana.com/grafana/dashboards/ depending on the type of dashboard required
5. Select the data source to use, then save dashboard

## Add Domain names to Monitoring tools and SSL/TLS Certificates to Loadbalancers for Https

1. Obtain Domain name or use existing Domains available,
2. Add DNS records to Domains in Domain registrar e.g Route53
3. Add CNAME records for each Monitoring tool, (Grafana, Prometheus, and Alertmanager) e.g grafana.fogbyte.services etc. Enter DNS values for each Loadbalancers on the CNAME records. (you can get the ladbalancer DNS values in ALB)

Recap;
- Go to your domain registrar's website or DNS management service.
- Create CNAME records or A records with aliases for each load balancer.
- Set the record values to the respective DNS names of the load balancers.
After the DNS records have propagated, you should be able to access Grafana, Prometheus, and Alertmanager using the custom domain names associated with each load balancer.

4. You would need to configure the Ingress rules for each application to specify the desired domain name. This ensures that the applications respond to requests coming from your custom domain.

For example, for Grafana, Prometheus, and Alertmanager, you can add the following set block to each respective Helm release in your Terraform configuration:

_Copy code_
```
set {
  name  = "server.ingress.hosts[0].name"
  value = "your-domain-name.com"
}
```

Replace "your-domain-name.com" with your actual domain name. (This has already been added to the script.)

This configuration will update the Ingress rules for each application during deployment, directing traffic to the load balancer associated with your custom domain. It ensures that requests made to your domain name are routed correctly to each application.

5. To configure your applications (Grafana, Prometheus, Alertmanager) with the new domain names using AWS CLI, you need to update their respective configurations. Here are the commands to update the configurations for each application:

**Grafana**:
To update the domain name for Grafana, you can use the following command:

_Copy code_
`kubectl patch service -n monitoring grafana -p '{"spec":{"externalName": "<your-domain-name.com>"}}'`

Replace <your-domain-name.com> with your actual domain name.

**Prometheus**:
To update the domain name for Prometheus, you need to edit the Prometheus Service. Run the following command:

_Copy code_
`kubectl edit service -n monitoring (Your prometheus service name)`

In the editor, find the spec section and update the externalName field with your domain name. Save the changes and exit the editor.

**Alertmanager**:
To update the domain name for Alertmanager, you need to edit the Alertmanager Service. Run the following command:

_Copy code_
`kubectl edit service -n monitoring (your alertmanager service name)`

In the editor, find the spec section and update the externalName field with your domain name. Save the changes and exit the editor.

After making these changes, the applications will use the new domain names for communication. Remember to replace <your-domain-name.com> with your actual domain name.

6. To secure the new domains for your applications, you can enable SSL/TLS encryption by obtaining and installing SSL certificates. Here are the general steps to follow:

**Obtain SSL Certificates:**

Purchase SSL certificates from a trusted certificate authority (CA) such as Let's Encrypt, DigiCert, or AWS Certificate manager (recommended if your domain is already on Route53).

**Configure SSL Certificates on the Load Balancer:**

For Application Load Balancer (ALB): Follow AWS documentation to configure SSL certificates on your ALB. This typically involves uploading the certificate to AWS Certificate Manager (ACM) and associating it with the ALB's listener.

To add a certificate from AWS Certificate Manager (ACM) to your load balancer, you need to follow these steps:

- Sign in to the AWS Management Console and open the EC2 service.
- Go to the "Load Balancers" section.
- Select the load balancer to which you want to add the ACM certificate.
- In the "Listeners" tab, click on the listener for which you want to configure SSL/TLS.
- Add HTTPS port forwarding to the respective instance port. 
- Under the "SSL certificate" section, choose "Change".
- In the "Certificate type" dropdown, select "ACM Certificate".
- From the "ACM Certificate" dropdown, select the ACM certificate you want to associate with the load balancer.
- Click "Save" to apply the changes.
- Repeat for all three loadbalancers

The load balancer will now use the selected ACM certificate for SSL/TLS termination. Make sure the load balancer's security groups allow traffic on the required ports (e.g., port 443 for HTTPS). After the changes are applied, your load balancer will use the ACM certificate for secure communication with clients.

**Verify SSL Configuration:**

After updating the DNS records, wait for the DNS propagation to take effect.
Access your applications using the new domain names (e.g., https://grafana.fogbyte.services) and verify that SSL is properly configured and the certificate is valid.
