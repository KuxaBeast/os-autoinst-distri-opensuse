#################################
# ha-sap-terraform-deployments project configuration file
# Find all the available variables and definitions in the variables.tf file
#################################

# Region where to deploy the configuration
aws_region = "%REGION%"

# Use an already existing vpc. Make sure the vpc has the internet gateway already attached
#vpc_id = "vpc-xxxxxxxxxxxxxxxxx"

# Use an already existing security group
#security_group_id = "sg-xxxxxxxxxxxxxxxxx"

# vpc address range in CIDR notation
# Only used if the vpc is created by terraform or the user doesn't have read permissions in this
# resource. To use the current vpc address range set the value to an empty string
# To define custom ranges
vpc_address_range = "10.0.0.0/16"
# Or to use already existing vpc address ranges
#vpc_address_range = ""

#################################
# General configuration variables
#################################

# Deployment name. This variable is used to complement the name of multiple infrastructure resources adding the string as suffix
# If it is not used, the terraform workspace string is used
# The name must be unique among different deployments
# deployment_name = "mydeployment"

# aws-cli credentials data
# access keys parameters have preference over the credentials file (they are self exclusive)
#aws_access_key_id = my-access-key-id
#aws_secret_access_key = my-secret-access-key
# aws-cli credentials file. Located on ~/.aws/credentials on Linux, MacOS or Unix or at C:\Users\USERNAME\.aws\credentials on Windows
aws_credentials = "/root/amazon_credentials"

# If BYOS images are used in the deployment, SCC registration code is required. Set `reg_code` and `reg_email` variables below
# By default, all the images are PAYG, so these next parameters are not needed
#reg_code = "<<REG_CODE>>"
#reg_email = "<<your email>>"
reg_code = "%SCC_REGCODE_SLES4SAP%"

# To add additional modules from SCC. None of them is needed by default
#reg_additional_modules = {
#    "sle-module-adv-systems-management/12/x86_64" = ""
#    "sle-module-containers/12/x86_64" = ""
#    "sle-ha-geo/12.4/x86_64" = "<<REG_CODE>>"
#}

# Default os_image and os_owner. These values are not used if the specific values are set (e.g.: hana_os_image)
# BYOS example with sles4sap 15 sp1 (this value is a pattern, it will select the latest version that matches this name)
#os_image = "suse-sles-sap-15-sp1-byos"
#os_owner = "amazon"
os_image = "%SLE_IMAGE%"
os_owner = "self"

# The project requires a pair of SSH keys (public and private) to provision the machines
# The private key is only used to create the SSH connection, it is not uploaded to the machines
# Besides the provisioning, the SSH connection for this keys will be authorized in the created machines
# These keys are provided using the next two variables in 2 different ways
# Path to already existing keys
public_key  = "~/.ssh/id_rsa.pub"
private_key = "~/.ssh/id_rsa"

# Or provide the content of SSH keys
#public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCt06V...."
#private_key = <<EOF
#-----BEGIN OPENSSH PRIVATE KEY-----
#b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABFwAAAAdzc2gtcn
#...
#P9eYliTYFxhv/0E7AAAAEnhhcmJ1bHVAbGludXgtYWZqOQ==
#-----END OPENSSH PRIVATE KEY-----
#EOF

# Authorize additional keys optionally (in this case, the private key is not required)
# Path to local files or keys content
#authorized_keys = ["/home/myuser/.ssh/id_rsa_second_key.pub", "/home/myuser/.ssh/id_rsa_third_key.pub", "ssh-rsa AAAAB3NzaC1yc2EAAAA...."]

# An additional pair of SSH keys is needed to provide the HA cluster the capability to SSH among the machines
# This keys are uploaded to the machines!
# If `pre_deployment = true` is used, this keys are autogenerated
cluster_ssh_pub = "salt://sshkeys/cluster.id_rsa.pub"
cluster_ssh_key = "salt://sshkeys/cluster.id_rsa"

##########################
# Other deployment options
##########################

# Repository url used to install HA/SAP deployment packages"
# The latest RPM packages can be found at:
# https://download.opensuse.org/repositories/network:/ha-clustering:/Factory/{YOUR OS VERSION}
# Contains the salt formulas rpm packages.
# To auto detect the SLE version
#ha_sap_deployment_repo = "https://download.opensuse.org/repositories/network:ha-clustering:sap-deployments:devel/"
# Otherwise use a specific SLE version:
#ha_sap_deployment_repo = "https://download.opensuse.org/repositories/network:ha-clustering:sap-deployments:devel/SLE_15/"
#ha_sap_deployment_repo = ""
ha_sap_deployment_repo = "%HA_SAP_REPO%"

# Provisioning log level (error by default)
#provisioning_log_level = "info"

# Print colored output of the provisioning execution (true by default)
#provisioning_output_colored = false

# Enable pre deployment steps (disabled by default)
pre_deployment = true

# To disable the provisioning process
#provisioner = ""

# Run provisioner execution in background
background = false

# QA variables

# Define if the deployment is used for testing purpose
# Disable all extra packages that do not come from the image
# Except salt-minion (for the moment) and salt formulas
# true or false (default)
#qa_mode = false

# Execute HANA Hardware Configuration Check Tool to bench filesystems
# qa_mode must be set to true for executing hwcct
# true or false (default)
#hwcct = false

#########################
# HANA machines variables
#########################

# Instance type to use for the hana cluster nodes
#hana_instancetype = "r3.8xlarge"
hana_instancetype = "%MACHINE_TYPE%"

# Disk type for HANA
#hana_data_disk_type = "gp2"

# Disk size for HANA database content in GB
# For S/4HANA a big disk size is required, at least 350GB
#hana_data_disk_size  = 1024 # 1024GB

# Number of nodes in the cluster
#hana_count = "2"

# HANA machines image. By default, PAYG images are used
# BYOS example with sles4sap 15 sp1 (this value is a pattern, it will select the latest version that matches this name)
#hana_os_image = "suse-sles-sap-15-sp1-byos"
# Or use a specific ami image
#hana_os_image = "ami-xxxxxxxxxxxx"
# Custom owner for private AMI
#hana_os_owner = "amazon"

# Enable system replication and HA cluster
#hana_ha_enabled = true

# The next variables define how the HANA installation software is obtained.
# The installation software must be located in a AWS S3 bucket

# 'hana_inst_master' is a S3 bucket where HANA installation files (extracted or not) are stored
# `hana_inst_master` must be used always! It is used as the reference path to the other variables

# Local folder where HANA installation master will be mounted
#hana_inst_folder = "/sapmedia/HANA"

# To configure the usage there are multiple options:
# 1. Use an already extracted HANA Platform folder structure.
# The last numbered folder is the HANA Platform folder with the extracted files with
# something like `HDB:HANA:2.0:LINUX_X86_64:SAP HANA PLATFORM EDITION 2.0::XXXXXX` in the LABEL.ASC file
hana_inst_master = "%HANA_BUCKET%"

# 2. Combine the `hana_inst_master` with `hana_platform_folder` variable.
#hana_inst_master = "s3://sapdata/sap_inst_media/"
# Specify the path to already extracted HANA platform installation media, relative to hana_inst_master mounting point.
# This will have preference over hana archive installation media
#hana_platform_folder = "51053381"

# 3. Specify the path to the HANA installation archive file in either of SAR, RAR, ZIP, EXE formats, relative to the 'hana_inst_master' mounting point
# For multipart RAR archives, provide the first part EXE file name.
#hana_archive_file = "51053381_part1.exe"

# 4. If using HANA SAR archive, provide the compatible version of sapcar executable to extract the SAR archive
# HANA installation archives be extracted to path specified at hana_extract_dir (optional, by default /sapmedia/HANA)
#hana_archive_file = "IMDB_SERVER.SAR"
#hana_sapcar_exe = "SAPCAR"

# For option 3 and 4, HANA installation archives are extracted to the path specified
# at hana_extract_dir (optional, by default /sapmedia_extract/HANA). This folder cannot be the same as `hana_inst_folder`!
#hana_extract_dir = "/sapmedia_extract/HANA"

# The following SAP HANA Client variables are needed only when you are using a HANA database SAR archive for HANA installation.
# HANA Client is used by monitoring & cost-optimized scenario and it is already included in HANA platform media unless a HANA database SAR archive is used
# You can provide HANA Client in one of the two options below:
# 1. Path to already extracted hana client folder, relative to hana_inst_master mounting point
#hana_client_folder = "SAP_HANA_CLIENT"
# 2. Or specify the path to the hana client SAR archive file, relative to the 'hana_inst_master'. To extract the SAR archive, you need to also provide compatible version of sapcar executable in variable hana_sapcar_exe
# It will be extracted to hana_client_extract_dir path (optional, by default /sapmedia_extract/HANA_CLIENT)
#hana_client_archive_file = "IMDB_CLIENT20_003_144-80002090.SAR"
#hana_client_extract_dir = "/sapmedia_extract/HANA_CLIENT"

# Device used by node where HANA will be installed
#hana_disk_device = "/dev/xvdd"

# IP address used to configure the hana cluster floating IP. It must belong to the same subnet than the machines!
hana_cluster_vip = "192.168.1.10"

# Select HANA cluster fencing mechanism. 'native' by default
# Find more information in `doc/fencing.md` documentation page
#hana_cluster_fencing_mechanism = "sbd"

# Enable Active/Active HANA setup (read-only access in the secondary instance)
#hana_active_active = true

# HANA cluster secondary vip. This IP address is attached to the read-only secondary instance. Only needed if hana_active_active is set to true
#hana_cluster_vip_secondary = "192.168.1.11"

# Each host IP address (sequential order). The first ip must be in 10.0.0.0/24 subnet and the second in 10.0.1.0/24 subnet
hana_ips = ["10.0.1.5", "10.0.2.6"]

# HANA instance configuration
# Find some references about the variables in:
# https://help.sap.com
# HANA instance system identifier. It's composed of 3 characters string
#hana_sid = "prd"
# HANA instance number. It's composed of 2 integers string
#hana_instance_number = "00"
# HANA instance master password. It must follow the SAP Password policies
#hana_master_password = "YourPassword1234"
# HANA primary site name. Only used if HANA's system replication feature is enabled (hana_ha_enabled to true)
#hana_primary_site = "Site1"
# HANA secondary site name. Only used if HANA's system replication feature is enabled (hana_ha_enabled to true)
#hana_secondary_site = "Site2"
hana_master_password = "Linux1234"

# Cost optimized scenario
#scenario_type = "cost-optimized"

#######################
# SBD related variables
#######################

# In order to enable SBD, an ISCSI server is needed as right now is the only option
# All the clusters will use the same mechanism
# In order to enable the iscsi machine creation _fencing_mechanism must be set to 'sbd' for any of the clusters

# iSCSI server image. By default, PAYG image is used. The usage is the same as the HANA images
#iscsi_os_image = "suse-sles-sap-15-sp1-byos"
#iscsi_os_owner = "amazon"

# iSCSI server address. It should be in same iprange as hana_ips
#iscsi_srv_ip = "10.0.0.254"
# Number of LUN (logical units) to serve with the iscsi server. Each LUN can be used as a unique sbd disk
#iscsi_lun_count = 3
# Disk size in GB used to create the LUNs and partitions to be served by the ISCSI service
#iscsi_disk_size = 10

##############################
# Monitoring related variables
##############################

# Enable the host to be monitored by exporters
#monitoring_enabled = true

# Monitoring server image. By default, PAYG image is used. The usage is the same as the HANA images
#monitoring_os_image = "suse-sles-sap-15-sp1-byos"
#monitoring_os_owner = "amazon"

# IP address of the machine where Prometheus and Grafana are running. Must be in 10.0.0.0/24 subnet
#monitoring_srv_ip = "10.0.0.253"

########################
# DRBD related variables
########################

# netweaver will use AWS efs for nfs share by default, unless drbd is enabled
# Enable drbd cluster
drbd_enabled = false

#drbd_instancetype = "t2.micro"

# DRBD machines image. By default, PAYG image is used. The usage is the same as the HANA images
#drbd_os_image = "suse-sles-sap-15-sp1-byos"
#drbd_os_owner = "amazon"

#drbd_data_disk_size = 15

#drbd_data_disk_type = "gp2"

# Each drbd cluster host IP address (sequential order).
drbd_ips = ["10.0.5.20", "10.0.6.21"]
drbd_cluster_vip = "192.168.1.20"

# Select DRBD cluster fencing mechanism. 'native' by default
#drbd_cluster_fencing_mechanism = "sbd"

# NFS share mounting point and export. Warning: Since cloud images are using cloud-init, /mnt folder cannot be used as standard mounting point folder
# If DRBD is used, it will create the NFS export in /mnt_permanent/sapdata/{netweaver_sid} to be connected as {drbd_cluster_vip}:/{netwaever_sid} (e.g.: )192.168.1.20:/HA1
#drbd_nfs_mounting_point = "/mnt_permanent/sapdata"

#############################
# Netweaver related variables
#############################

#netweaver_enabled = true

# Netweaver APP server count (PAS and AAS)
# Set to 0 to install the PAS instance in the same instance as the ASCS. This means only 1 machine is installed in the deployment (2 if HA capabilities are enabled)
# Set to 1 to only enable 1 PAS instance in an additional machine`
# Set to 2 or higher to deploy additional AAS instances in new machines
#netweaver_app_server_count = 2

#netweaver_instancetype = "r3.8xlarge"

# Netweaver machines image. By default, PAYG image is used. The usage is the same as the HANA images
#netweaver_os_image = "suse-sles-sap-15-sp1-byos"
#netweaver_os_owner = "amazon"

#AWS efs performance mode used by netweaver nfs share, if efs storage is used
#netweaver_efs_performance_mode = "generalPurpose"
#netweaver_ips = ["10.0.2.7", "10.0.3.8", "10.0.2.9", "10.0.3.10"]
#netweaver_virtual_ips = ["192.168.1.20", "192.168.1.21", "192.168.1.22", "192.168.1.23"]

# Netweaver installation configuration
# Netweaver system identifier. It's composed of 3 characters string
#netweaver_sid = "ha1"
# Netweaver ASCS instance number. It's composed of 2 integers string
#netweaver_ascs_instance_number = "00"
# Netweaver ERS instance number. It's composed of 2 integers string
#netweaver_ers_instance_number = "10"
# Netweaver PAS instance number. If additional AAS machines are deployed, they get the next number starting from the PAS instance number. It's composed of 2 integers string
#netweaver_pas_instance_number = "01"
# Netweaver master password. It must follow the SAP Password policies such as have 8 characters at least combining upper and lower case characters and numbers. It cannot start with special characters.
#netweaver_master_password = "SuSE1234"

# Enabling this option will create a ASCS/ERS HA available cluster together with a PAS and AAS application servers
# Set to false to only create a ASCS and PAS instances
#netweaver_ha_enabled = true

# Select Netweaver cluster fencing mechanism. 'native' by default
#netweaver_cluster_fencing_mechanism = "sbd"

# Set the Netweaver product id. The 'HA' sufix means that the installation uses an ASCS/ERS cluster
# Below are the supported SAP Netweaver product ids if using SWPM version 1.0:
# - NW750.HDB.ABAP
# - NW750.HDB.ABAPHA
# - S4HANA1709.CORE.HDB.ABAP
# - S4HANA1709.CORE.HDB.ABAPHA
# Below are the supported SAP Netweaver product ids if using SWPM version 2.0:
# - S4HANA1809.CORE.HDB.ABAP
# - S4HANA1809.CORE.HDB.ABAPHA
# - S4HANA1909.CORE.HDB.ABAP
# - S4HANA1909.CORE.HDB.ABAPHA

# Example:
#netweaver_product_id = "NW750.HDB.ABAPHA"

# Path where netweaver sapmnt data is stored.
#netweaver_sapmnt_path = "/sapmnt"

# Preparing the Netweaver download basket. Check `doc/sap_software.md` for more information

# AWS S3 bucket where all the Netweaver software is available. The next paths are relative to this folder.
#netweaver_s3_bucket = "s3://path/to/your/netweaver/installation/s3bucket"

# SAP SWPM installation folder, relative to the netweaver_s3_bucket folder
#netweaver_swpm_folder     =  "your_swpm"
# Or specify the path to the sapcar executable & SWPM installer sar archive, relative to the netweaver_s3_bucket folder
# The sar archive will be extracted to path specified at netweaver_extract_dir under SWPM directory (optional, by default /sapmedia_extract/NW/SWPM)
#netweaver_sapcar_exe = "your_sapcar_exe_file_path"
#netweaver_swpm_sar = "your_swpm_sar_file_path"
# Folder where needed SAR executables (sapexe, sapdbexe) are stored, relative to the netweaver_s3_bucket folder
#netweaver_sapexe_folder   =  "download_basket"
# Additional media archives or folders (added in start_dir.cd), relative to the netweaver_s3_bucket folder
#netweaver_additional_dvds = ["dvd1", "dvd2"]
