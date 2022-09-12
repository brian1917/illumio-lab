#!/bin/bash

# Update yum
yum update -y

# Start NTP service
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


# Add core0 to the hosts file of each machine pointing (no load balancing)
echo "${4}  ${3}" >> /etc/hosts

# Install the PCE
yum install -y ${5}

# Copy server key and cert and update permissions
cp ${10} /var/lib/illumio-pce/cert/server.key
chmod 400 /var/lib/illumio-pce/cert/server.key
chown ilo-pce:ilo-pce /var/lib/illumio-pce/cert/server.key

cp ${11} /var/lib/illumio-pce/cert/server.crt
chmod 400 /var/lib/illumio-pce/cert/server.crt
chown ilo-pce:ilo-pce /var/lib/illumio-pce/cert/server.crt

# Add root cert to bundle
cat ${12} >> /etc/ssl/certs/ca-bundle.crt

# The node type is either core, data0, or data1 in a 4-node cluster.
if [[ ${1} = *"core"* ]]; then
    NODE_TYPE="core"
else
    NODE_TYPE=${1}
fi

# Create runtime_env.yaml to install folder and update placeholder values
 echo "# Configuration done manually
install_root: \"/opt/illumio-pce\"
runtime_data_root: \"/var/lib/illumio-pce/runtime\"
persistent_data_root: \"/var/lib/illumio-pce/data\"
ephemeral_data_root: \"/var/lib/illumio-pce/tmp\"
log_dir: \"/var/log/illumio-pce\"
private_key_cache_dir: \"/var/lib/illumio-pce/keys\"
pce_fqdn: ${3}
service_discovery_fqdn: ${3}
cluster_public_ips:
  cluster_fqdn:
  - ${4}
node_type: ${NODE_TYPE}
internal_service_ip: ${2}
web_service_private_key: \"/var/lib/illumio-pce/cert/server.key\"
web_service_certificate: \"/var/lib/illumio-pce/cert/server.crt\"
email_address: brian.pitta@illumio.com
service_discovery_encryption_key: HN45NIRfeURhceajznWpmg==
expose_user_invitation_link: true
export_flow_summaries_to_syslog:
- accepted
- potentially_blocked
- blocked" > /etc/illumio-pce/runtime_env.yml

# For Core0, put in the info we need for users
if [[ ${1} = "core0" ]]; then
    echo ILLUMIO_ORG=\"${6}\" > /tmp/illumio_user
    echo ILLUMIO_USER=\"${7}\" >> /tmp/illumio_user
    echo ILLUMIO_PWD=\"${8}\" >> /tmp/illumio_user
    echo ILLUMIO_FULL_NAME=\"${9}\"} >> /tmp/illumio_user
fi


