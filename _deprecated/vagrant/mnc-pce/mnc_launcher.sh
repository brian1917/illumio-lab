#!/bin/bash

# 4-node cluster
NODES=("core0" "core1" "data0" "data1")

# Bring up all nodes
echo "BRINGING UP CLUSTER NODES..."
vagrant up

# Start all nodes at runlevel 1
echo "STARTING ALL NODES AT RUNLEVEL 1 ..."
for NODE in ${NODES[*]}
do
    vagrant ssh $NODE -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl start --runlevel 1' &
done
wait

# Wait for the PCE to be running at runlevel 1
echo "WAITING FOR ALL NODES TO BE RUNNING ..."
for NODE in ${NODES[*]}
do
    STATUS=$(vagrant ssh ${NODE} -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status')
    while [[ $STATUS != *"RUNNING"* ]]
    do
        sleep 3s
        STATUS=$(vagrant ssh ${NODE} -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl status')
        echo "${NODE} not running. Checking again in 3 seconds ..."
    done
    echo "${NODE} is running" 
done

# Setup the databse on data0
echo "RUNNING DATABASE SETUP ON DATA0 NODE..."
vagrant ssh data0 -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-db-management setup'

# Set runlevel 5 on data0
echo "SETTING PCE TO RUNLEVEL 5..."
vagrant ssh data0 -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl set-runlevel 5'

# Wait for the cluster to be fully running
echo "WAITING FOR CLUSTER-STATUS TO BE RUNNING..."
STATUS=$(vagrant ssh core0 -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl cluster-status')
while [[ $STATUS != *"RUNNING"* ]]
do
    echo "PCE cluster not running. Checking again in 3 seconds ..."
    sleep 3s
    STATUS=$(vagrant ssh core0 -c 'sudo -u ilo-pce /opt/illumio-pce/illumio-pce-ctl cluster-status')
done
echo "PCE Cluster is running"

# Create the first user
# The Vagrantfile provisioning script sets up a /tmp/illumio_user file with information needed for provisioning first user.
echo "CREATING FIRST USER..."
vagrant ssh core0 -c 'source /tmp/illumio_user && export ILO_PASSWORD=${ILLUMIO_PWD} && sudo -E -u ilo-pce /opt/illumio-pce/illumio-pce-db-management create-domain --user-name ${ILLUMIO_USER} --full-name ${ILLUMIO_FULL_NAME} --org-name ${ILLUMIO_ORG} && sudo rm -f /tmp/illumio_user'