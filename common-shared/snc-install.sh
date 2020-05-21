#!/bin/bash

## SNC PCE configuration script for Centos 7
## If you're using this script for manual installation (i.e., not through Vagrant, Terraform, etc.) set the variables in the Configuration for Manual Deployment section.


# * * * * * * * * * * * CONFIGURATION FOR MANUAL DEPLOYMENT * * * * * * * * * * *
# Use the variables below if you are running this script manually on a PCE box.

# SNC Config
snc_pce_fqdn="pce-snc.poc.segmentationpov.com"
pce_ip_address="192.168.100.2"

# PCE User
user_email="name@domain.com"
user_fullname="First Last"
org_name="Pitta-Local-Lab"
password="THIS-IS-A-PLACEHOLDER" # this needs to be 8 characters, one uppercase, and one lowercase.

# File locations for RPM and cert info on the CentOS box.
pce_rpm="/vagrant/pce-sw/illumio-pce-18.2.0-12887.H1.x86_64.rpm"
ui_rpm="" # Leave blank if installing a PCE version before 19.3. 19.3 and above requires UI RPM.
ven_bundle="/vagrant/ven-sw/illumio-ven-bundle-18.3.1-5239.tar.bz2"
crt="/vagrant/certs/star_poc_segmentationpov_com_bundle.crt"
key="/vagrant/certs/star_poc_segmentationpov_com.key"

# * * * * * * * * * * * END CONFIGURATION * * * * * * * * * * * * * * * * * * * *

# If running from vagrant, source the vagrant configuration file to override variables above and add /vagrant/prefix
if [[ $1 == "vagrant" ]]; then
    source /vagrant/config-do-not-edit
    # Adjust location variables to be from /vagrant
    pce_rpm="/vagrant/${pce_rpm}"
    ui_rpm="/vagrant/${ui_rpm}"
    ven_bundle="/vagrant/${ven_bundle}"
    crt="/vagrant/${crt}"
    key="/vagrant/${key}"
fi

# If running from aws, read the variables file to override variables above.
if [[ $1 == "aws" ]]; then
    # SNC Config
    snc_pce_fqdn=$(cat /tmp/variables.json | jq -r '.pce.org_name').$(cat /tmp/variables.json | jq -r '.pce.domain_name')
    pce_ip_address=$2

    # PCE User
    user_email=$(cat /tmp/variables.json | jq -r '.pce.user_email')
    user_fullname=$(cat /tmp/variables.json | jq -r '.pce.user_full_name')
    org_name=$(cat /tmp/variables.json | jq -r '.pce.org_name')
    password=$(cat /tmp/variables.json | jq -r '.pce.user_pwd')

    # File locations for RPM and cert info
    ui_rpm="/tmp/ui.rpm"
    pce_rpm="/tmp/pce.rpm"
    ven_bundle="/tmp/ven_bundle.tar.bz2"
    crt="/tmp/poc-segmentationpov-com/star_poc_segmentationpov_com_bundle.crt"
    key="/tmp/poc-segmentationpov-com/star_poc_segmentationpov_com.key"
fi

# Set the hostname
hostnamectl set-hostname $snc_pce_fqdn

# Start NTP service
yum install -y ntp
systemctl start ntpd
systemctl enable ntpd

# Stop iptables service
systemctl stop firewalld
systemctl disable firewalld

# Update Security limits
echo "
*               soft    core            unlimited
*               hard    core            unlimited
*               hard    nproc           65535
*               soft    nproc           65535
*               hard    nofile          65535
*               soft    nofile          65535" >> /etc/security/limits.conf

# Add IP address to /etc/hosts
echo "${pce_ip_address}   ${snc_pce_fqdn}" >> /etc/hosts

# Install the PCE, UI, and any required dependencies
yum install -y ${pce_rpm} 
yum install -y ${ui_rpm}

# Copy server key and cert and update permissions
cp ${key} /var/lib/illumio-pce/cert/$(basename ${key})
cp ${crt} /var/lib/illumio-pce/cert/$(basename ${crt})
chmod 400 /var/lib/illumio-pce/cert/$(basename ${key})
chown ilo-pce:ilo-pce /var/lib/illumio-pce/cert/$(basename ${key})
chmod 440 /var/lib/illumio-pce/cert/$(basename ${crt})
chown ilo-pce:ilo-pce /var/lib/illumio-pce/cert/$(basename ${crt})

# Write the runtime_env.yaml
echo "# Configuration not done via setup tool
install_root: \"/opt/illumio-pce\"
runtime_data_root: \"/var/lib/illumio-pce/runtime\"
persistent_data_root: \"/var/lib/illumio-pce/data\"
ephemeral_data_root: \"/var/lib/illumio-pce/tmp\"
log_dir: \"/var/log/illumio-pce\"
private_key_cache_dir: \"/var/lib/illumio-pce/keys\"
pce_fqdn: ${snc_pce_fqdn}
service_discovery_fqdn: ${snc_pce_fqdn}
cluster_public_ips:
  cluster_fqdn:
    - ${pce_ip_address}
node_type: snc0
web_service_private_key: \"/var/lib/illumio-pce/cert/$(basename ${key})\"
web_service_certificate: \"/var/lib/illumio-pce/cert/$(basename ${crt})\"
email_address: illumio-noreply@${snc_pce_fqdn#*.}
email_display_name: noreply
service_discovery_encryption_key: HN45NIRfeURhceajznWpmg==
smtp_relay_address: 127.0.0.1:25
export_flow_summaries_to_syslog:
- accepted
- potentially_blocked
- blocked
expose_user_invitation_link: true
internal_service_ip: ${pce_ip_address}" > /etc/illumio-pce/runtime_env.yml

# Start the PCE at runlevel 1
echo "Starting PCE at runlevel 1..."
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl start --runlevel 1
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status -w 180

# Run db set up after the PCE is running
echo "Running databse setup..."
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-db-management setup

# Set to run-level 5
echo "Setting the PCE runlevel to 5..."
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl set-runlevel 5
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status -w 180

# Create a user
echo "Creating a user ..."
export ILO_PASSWORD=${password}
sudo -E -u ilo-pce /opt/illumio-pce/illumio-pce-db-management create-domain --user-name ${user_email} --full-name ${user_fullname} --org-name ${org_name}
echo "Setting up VEN library..."
sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl ven-software-install --orgs all --default --no-prompt ${ven_bundle}
echo "PCE should be functional and ready to log in."
