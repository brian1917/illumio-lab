#!/bin/bash

# Install Expect
apt-get update -y
apt-get install expect -y

# Install the Splunk software
cd /opt
dpkg -i /tmp/splunk/splunk-8.2.0-e053ef3c985f-linux-2.6-amd64.deb

# Call the set-admin script
/tmp/splunk/start.exp
