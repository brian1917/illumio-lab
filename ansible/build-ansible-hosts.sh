#!/bin/bash

# The first argument is the variables file name - no directory

# Remove existing hosts file
rm -f ../ansible/hosts > /dev/null 2>&1

# Set up Linux and Windows workloads arrays
linux_wklds=()
snc_nodes=()
core_nodes=()
data_nodes=()
windows_wklds=()

# Check if we are building an SNC and populate
if [ $(cat ${1} | jq -r .pce.cluster_type) == "snc" ]; then
    echo "[pce]" >> ../ansible/hosts
    echo snc-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=snc0 >> ../ansible/hosts
    echo "" >> ../ansible/hosts
    echo "[pce:vars]" >> ../ansible/hosts
    echo "ansible_user=centos" >> ../ansible/hosts
    echo "ansible_ssh_extra_args='-o StrictHostKeyChecking=no'" >> ../ansible/hosts
    echo "" >> ../ansible/hosts
fi

# Check if we are building an MNC and populate
if [ $(cat ${1} | jq -r .pce.cluster_type) == "mnc" ]; then
    echo "[pce]" >> ../ansible/hosts
    echo core0-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=core0 >> ../ansible/hosts >> ../ansible/hosts
    echo core1-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=core1 >> ../ansible/hosts >> ../ansible/hosts
    echo data0-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=data0>> ../ansible/hosts
    echo data1-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=data1>> ../ansible/hosts
    echo "" >> ../ansible/hosts
    echo "[pce:vars]" >> ../ansible/hosts
    echo "ansible_user=centos" >> ../ansible/hosts
    echo "ansible_ssh_extra_args='-o StrictHostKeyChecking=no'" >> ../ansible/hosts
    echo "" >> ../ansible/hosts
fi


# Get Linux workloads
while read -r line; do
    if [ "$line" != "" ]; then
        linux_wklds+=("$line")
    fi
done <<< "$(cat ${1} | jq -r '.linux_wklds | keys[]')"

# Get Windows workloads
while read -r line; do
  if [ "$line" != "" ]; then
    windows_wklds+=("$line")
  fi
done <<< "$(cat ${1} | jq -r '.windows_wklds | keys[]')"

# Write the Linux hosts if it's not the ansible server
if [ ${#linux_wklds[@]} -gt 0 ]; then
    echo "[linux]" >> ../ansible/hosts
    for i in "${linux_wklds[@]}"
    do
        echo "${i}.segmentationpov.com" >> ../ansible/hosts
    done

# Write the Linux variables to the host files
    echo "
[linux:vars]
ansible_user=centos
ansible_ssh_extra_args='-o StrictHostKeyChecking=no'
" >> ../ansible/hosts

fi

# Write the Windows Hosts
if [ ${#windows_wklds[@]} -gt 0 ]; then
    echo "[win]" >> ../ansible/hosts
    for i in "${windows_wklds[@]}"
    do
    echo ${i}.segmentationpov.com >> ../ansible/hosts
    done


    # Write the Windows variables
    echo "
[win:vars]
ansible_user=Administrator
ansible_password=Illumio123
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore" >> ../ansible/hosts
fi