#!/bin/bash

# * * * * * * * * * * * START CONFIGURATION * * * * * * * * * * *

ven_activation_code=$(cat /vagrant/lxc/VEN_ACTIVATION_CODE) # change this to static variable if running outside automation
snc_pce_fqdn="pce-snc.poc.segmentationpov.com"
ubuntu_ven="/vagrant/ven-sw/illumio-ven-18.2.0-4097.u16.amd64.deb"
workloads_file="/vagrant/lxc/workloads_20.csv"
flows_file="/vagrant/lxc/flows.csv"

# * * * * * * * * * * * END CONFIGURATION * * * * * * * * * * *

# If running from automation, override the variables above with the variables.config file"
if [[ $1 == "auto" ]]; then
    source /vagrant/config-do-not-edit
    workloads_file="/vagrant/"${workloads_file}
    ubuntu_ven="/vagrant/"${ubuntu_ven}
    flows_file="/vagrant/"${flows_file}
fi

# # INSTALL LXD
# sudo apt remove --purge lxd lxd-client -y
# snap install lxd --channel=3.0/stable

# # CONFIGURE LXD
# cat <<EOF | lxd init --preseed
# config: {}
# networks:
# - config:
#     ipv4.address: auto
#     ipv6.address: none
#   description: ""
#   managed: false
#   name: lxdbr0
#   type: ""
# storage_pools:
# - config:
#     size: 55GB
#   description: ""
#   name: default
#   driver: zfs
# profiles:
# - config: {}
#   description: ""
#   devices:
#     eth0:
#       name: eth0
#       nictype: bridged
#       parent: lxdbr0
#       type: nic
#     root:
#       path: /
#       pool: default
#       type: disk
#   name: default
# cluster: null
# EOF

# # ADD TO THE HOSTS FILE
# echo "${pce_ip_address}   ${snc_pce_fqdn}" >> /etc/hosts

# CREATE A TEMPORARY CSV IN TMP DIRECTORY WITH LINE ENDINGS STRIPPED
sed 's/\r$//' ${workloads_file} > "/tmp/$(basename ${workloads_file})"

# READ DATA FROM NEW WORKLOADS FILE
i=0
cat "/tmp/$(basename ${workloads_file})" | awk -F "," '{ print $1 }' | while read h
do
    ((i++))
    if [[ $i -gt 1 ]]; then
        # LAUNCH LXC
        lxc launch ubuntu:16.04 $h
        
        # Wait for IP Address
        lxc_ip_address=$(lxc list ${1} -c 4 | awk '!/IPV4/{ if ( $2 != "" ) print $2}')
        while [ ${#lxc_ip_address} -le 4 ]
        do
            lxc_ip_address=$(lxc list ${1} -c 4 | awk '!/IPV4/{ if ( $2 != "" ) print $2}')
        done
        # Push files
        lxc file push ${ubuntu_ven} $1/root/

        # Add PCE to hosts file
        lxc exec ${1} -- nohup bash -c "echo \"${pce_ip_address}   ${snc_pce_fqdn}\" >> /etc/hosts" 
       
        # Install VEN
        lxc exec ${1} -- nohup bash -c "apt-get install ./$(basename ${ubuntu_ven}) -y &"
        
        #Activate VEN
        echo "${1} - Aciviating VEN ..."
        lxc exec ${1} -- nohup bash -c "/opt/illumio_ven/illumio-ven-ctl activate -m ${snc_pce_fqdn}:8443 -a ${ven_activation_code} &"
        fi
done

