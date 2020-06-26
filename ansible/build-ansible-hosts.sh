#!/bin/bash

# The first argument is the variables file name - no directory

# Remove existing hosts file
rm -f ../ansible/hosts > /dev/null 2>&1

# Set up Linux and Windows workloads arrays
windows_wklds=()
windows_server_types=()
linux_wklds=()
dc=()
member=()

# Populate the arrays
for w in $(jq -r '.windows_wklds | keys[]' ${1}); do
    if [ $(jq -r '. | .windows_wklds["'${w}'"] | .win_server_type'  ${1}) == "dc" ]; then
        dc+=("$w")
    elif [ $(jq -r '. | .windows_wklds["'${w}'"] | .win_server_type'  ${1}) == "member" ]; then
        member+=("$w")
    else
        windows_wklds+=("$w")
    fi
done
for l in $(jq -r '.linux_wklds | keys[]' ${1}); do
    linux_wklds+=("$l")
done
for t in $(jq -r '.windows_wklds | .[] | .win_server_type' ${1}); do
    windows_server_types+=("$t")
done

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


# Check if we are building an MNC and populate
if [ $(cat ${1} | jq -r .pce.cluster_type) == "sc" ]; then
    echo "[pce]" >> ../ansible/hosts
    echo sc1-core0-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=core0 >> ../ansible/hosts >> ../ansible/hosts
    echo sc1-core1-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=core1 >> ../ansible/hosts >> ../ansible/hosts
    echo sc1-data0-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=data0>> ../ansible/hosts
    echo sc1-data1-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=data1>> ../ansible/hosts
    echo "" >> ../ansible/hosts
    echo "[pce:vars]" >> ../ansible/hosts
    echo "ansible_user=centos" >> ../ansible/hosts
    echo "ansible_ssh_extra_args='-o StrictHostKeyChecking=no'" >> ../ansible/hosts
    echo "" >> ../ansible/hosts
    echo "[sc2]" >> ../ansible/hosts
    echo sc2-core0-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=core0 >> ../ansible/hosts >> ../ansible/hosts
    echo sc2-core1-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=core1 >> ../ansible/hosts >> ../ansible/hosts
    echo sc2-data0-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=data0>> ../ansible/hosts
    echo sc2-data1-$(cat ${1} | jq -r .pce.org_name).poc.segmentationpov.com node_type=data1>> ../ansible/hosts
    echo "" >> ../ansible/hosts
    echo "[sc2:vars]" >> ../ansible/hosts
    echo "ansible_user=centos" >> ../ansible/hosts
    echo "ansible_ssh_extra_args='-o StrictHostKeyChecking=no'" >> ../ansible/hosts
    echo "" >> ../ansible/hosts
fi

# Put the SC2 group in the hosts file for template processing even if it's not a supercluster
if [ $(cat ${1} | jq -r .pce.cluster_type) != "sc" ]; then
    echo "[sc2]" >> ../ansible/hosts
    echo "" >> ../ansible/hosts
fi


# Write the Linux hosts if it's not the ansible server
if [ ${#linux_wklds[@]} -gt 0 ]; then
    echo "[linux]" >> ../ansible/hosts
    for i in "${linux_wklds[@]}"
    do
        echo "${i}.poc.segmentationpov.com" >> ../ansible/hosts
    done


# Write the Linux variables to the host files
    echo "
[linux:vars]
ansible_user=centos
ansible_ssh_extra_args='-o StrictHostKeyChecking=no'
" >> ../ansible/hosts

fi
echo "[ansible]
127.0.0.1

[ansible:vars]
ansible_user=centos
ansible_ssh_extra_args='-o StrictHostKeyChecking=no'
" >> ../ansible/hosts

# Write the Domain Controller Hosts
if [ ${#dc[@]} -gt 0 ]; then
    echo "[dc]" >> ../ansible/hosts
    n=0
    for i in "${dc[@]}"
    do
    echo ${i}.poc.segmentationpov.com >> ../ansible/hosts
    dc="${i}.poc.segmentationpov.com"
    n=$((n+1))
    done


# Write the DC variables
    echo "
[dc:vars]
ansible_user=Administrator
ansible_password=$(cat ${1} | jq -r .windows_admin_pwd)
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
" >> ../ansible/hosts
fi

# Write the Member Hosts
if [ ${#member[@]} -gt 0 ]; then
    echo "[member]" >> ../ansible/hosts
    n=0
    for i in "${member[@]}"
    do
    echo ${i}.poc.segmentationpov.com >> ../ansible/hosts
    n=$((n+1))
    done


# Write the Member variables
    echo "
[member:vars]
dc=${dc}
ansible_user=Administrator
ansible_password=$(cat ${1} | jq -r .windows_admin_pwd)
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
" >> ../ansible/hosts
fi

# Write the Windows Hosts
if [ ${#windows_wklds[@]} -gt 0 ]; then
    echo "[win]" >> ../ansible/hosts
    n=0
    for i in "${windows_wklds[@]}"
    do
    echo ${i}.poc.segmentationpov.com win_server_type=${windows_server_types[$n]}>> ../ansible/hosts
    if [ ${windows_server_types[$n]} == "dc" ]; then
      dc="${i}.poc.segmentationpov.com"
    fi
    n=$((n+1))
    done


# Write the Windows variables
    echo "
[win:vars]
dc=${dc}
ansible_user=Administrator
ansible_password=$(cat ${1} | jq -r .windows_admin_pwd)
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore" >> ../ansible/hosts
fi

##### START CREATING WKLD-LABELS.CSV #####

# Setup the header row
echo "hostname,name,role,app,env,loc,interfaces" > ../ansible/temporary-labels-file.csv

# Ansible server
echo $(jq -r '. | .ansible_server | .name' ${1}),"","ANSIBLE","INFRA-MGMT",$(jq -r '. | .ansible_server | .env' ${1}),$(jq -r '. | .ansible_server | .loc' ${1}), >> ../ansible/temporary-labels-file.csv

# Windows servers
for w in $(jq -r '.windows_wklds | keys[]' ${1} ); do
    line=$(echo $w | tr [a-z] [A-Z]),"",
    line=$line$(jq -r '. | .windows_wklds["'${w}'"] | .role' ${1}),
    line=$line$(jq -r '. | .windows_wklds["'${w}'"] | .app' ${1}),
    line=$line$(jq -r '. | .windows_wklds["'${w}'"] | .env' ${1}),
    line=$line$(jq -r '. | .windows_wklds["'${w}'"] | .loc' ${1}),""
    echo $line >> ../ansible/temporary-labels-file.csv
done

# Linux Servers
for w in $(jq -r '.linux_wklds | keys[]' ${1} ); do
    line=${w},"",
    line=$line$(jq -r '. | .linux_wklds["'${w}'"] | .role' ${1}),
    line=$line$(jq -r '. | .linux_wklds["'${w}'"] | .app' ${1}),
    line=$line$(jq -r '. | .linux_wklds["'${w}'"] | .env' ${1}),
    line=$line$(jq -r '. | .linux_wklds["'${w}'"] | .loc' ${1}),""
    echo $line >> ../ansible/temporary-labels-file.csv
done

# Replace the instances of null with blank values
# Not using the -i option to replace in the file since it doesn't work the same on Mac and Linux
sed 's/null//g' ../ansible/temporary-labels-file.csv > ../ansible/wkld-labels.csv

# Remove the temporary file
rm -f ../ansible/temporary-labels-file.csv