#!/bin/bash

# SET DEFAULT PROVIDER
provider="vmware_fusion"

# PROCESS ARGUMENTS
while getopts "pswabhxz" opt; do
    case ${opt} in
        p) pce=true;;
        s) setup=true;;
        w) wl=true;;
        a) all=true;;
        b) provider="virtualbox";;
        x) destroy_snc=true;;
        z) destroy_wl=true;;
        h)
            echo "Usage: ./launcher.sh [OPTION]"
            echo "   -h        Display this help message."
            echo "   -p        Build the PCE."
            echo "   -s        Setup the PCE with Labels, Services, IPlists, and a Pairing Key (needed for Workloads)."
            echo "   -w        Build the workloads server."
            echo "   -b        Use VirtualBox with Vagrant (default VMware)."
            echo "   -x        Destroy existing SNC PCE (destroys run first)."
            echo "   -z        Destroy existing Workloads server (destroys run first)."
            echo "   -a        Destroys any running SNC and WL server and Builds all (PCE and workloads server). Same as -pswxz"
            help=true;;
        \?) ./$0 -h && exit 1
    esac
done

if [[ $pce != true ]] && [[ $setup != true ]] && [[ $wl != true  ]] && [[ $all != true  ]] && [[ $help != true ]] && [[ $destroy_snc != true ]] && [[ $destroy_wl != true ]];then
    ./$0 -h && exit 1
fi

# MOVE TO THE ROOT DIRECTORY AND CAPTURE THE PWD
cd "`dirname \"$0\"`"
dir=$(pwd)

## DESTROY INSTANCES IF NEEDED
if [[ $all = true ]] || [[ $destroy_snc = true ]]; then
    echo "Destroying SNC PCE instance..."
    cd snc-pce
    vagrant destroy -f
    cd ..
fi

## DESTROY INSTANCES IF NEEDED
if [[ $all = true ]] || [[ $destroy_wl = true ]]; then
    echo "Destroying Workload server instance..."
    cd workloads-lxc
    vagrant destroy -f
    cd ..
fi

# GET THE VARIABLES FROM THE CONFIG SCRIPT
source "${dir}/variables.config"

# CREATE ENVIRONMENT VARIABLE FOR VAGRANT FILE
export PCE_IP_ADDRESS=$pce_ip_address

# COPY VARIABLES FILE
cp variables.config ../common-shared/config-do-not-edit

### SNC PCE SECTION ###
if [[ $all = true ]] || [[ $pce = true ]]; then

    # BRING UP SNC
    cd snc-pce/
    vagrant up --provider=${provider}

    # WAIT FOR THE CLUSTER TO BE FULLY RUNNING
    echo "WAITING FOR CLUSTER-STATUS TO BE RUNNING..."
    status=$(vagrant ssh -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl cluster-status')
    while [[ $status != *"RUNNING"* ]]
    do
        echo "PCE cluster not running. Checking again in 3 seconds ..."
        sleep 3s
        status=$(vagrant ssh -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl cluster-status')
    done
    echo "PCE Cluster is running"
    
    # GO BACK TO HOMELAB ROOT DIRECTORY
    cd "${dir}"

fi

if [[ $all = true ]] || [[ $setup = true ]] || [[ $wl = true ]]; then

    # RUN THE PCE SETUP TO DELETE DEFAULT LABELS, CREATE NEW LABELS, CREATE IPLISTS, AND CREATE SERVICES
    
    if [[ $all = true ]] || [[ $pce = true ]]; then
        echo "Waiting 15 seconds before trying to login to PCE via workloader..."
        sleep 15s
    fi
    
    # LOG IN TO WORKLOADER
    export PCE_NAME=lab
    export PCE_FQDN=${snc_pce_fqdn}
    export PCE_PORT=8443
    export PCE_USER=${user_email}
    export PCE_PWD=${password}
    export PCE_DISABLE_TLS=true
    echo "Logging in to workloader ..."
    workloader pce-add

    if [[ $all = true ]] || [[ $setup = true ]] ; then
    echo "Importing the template file ..."
    workloader template-import ${pce_setup_template_absolute_path}
    fi 

fi

### WORKLOADS SECTION ###
if [[ $all = true ]] || [[ $wl = true ]]; then
    echo "Generating a pairing key ..."
    workloader get-pk > ../common-shared/lxc/VEN_ACTIVATION_CODE

    cd lxc-server
    echo "Starting Ubuntu LXC server ..."
    vagrant up --provider=${provider}
    echo "Configuring LXC server ..."
    vagrant ssh default -c 'cd /vagrant/lxc/ && sudo ./lxc-configuration.sh auto'
    
    # GO BACK TO HOMELAB ROOT DIRECTORY
    cd "${dir}"

    # Label the workloads
    workloader wkld-import ../common-shared/${workloads_file} --update-pce --no-prompt
    
    # Upload flows files
    echo "Importing flows ..."
    workloader flow-import ../common-shared/${flows_file}
fi