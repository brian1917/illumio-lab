#!/bin/bash

# This script checks to see if a ca.crt exists.
# If it does not, it creates the ca.crt.
# The script then creates a cert for the hostname provided in the arguments.
# The first argument is the name and the second argument is the domain.
# If the second argument is blank poc.segmentationpov.com is used.

# Example
# ./create-certs.sh lw01 - creates cert for lw01.poc.segmentationpov.com
# ./create-certs.sh www02 test.com - creates cert for ww02.test.com

# The outputted files for each host include the csr, key, crt, and p12 container.

# Set these variables for your CA and certs
country="US"
state="Massachusetts"
locality="Boston"
organization="PittaLab"
domain="poc.segmentationpov.com"

# Make the output directory
if [ ! -d output ]; then
  mkdir -p output;
fi

# If it doesn't exist, create the openssl config for the CA and create the CA.
if [ ! -f "output/ca.crt" ]; then
    echo "[ req ]
default_bits = 2048
encrypt_key  = no
default_md   = SHA256
prompt       = no
utf8         = yes
distinguished_name = req_distinguised_name
x509_extensions = v3_ca

[ v3_ca ]
basicConstraints     = critical, CA:true
subjectKeyIdentifier = hash
keyUsage             = keyEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly
extendedKeyUsage     = ipsecUser, ipsecEndSystem, emailProtection

[ req_distinguised_name ]
C  = ${country}
ST = ${state}
L  = ${locality}
O  = ${organization}
CN = ca.${domain}" > output/ca.cnf

    echo "[INFO] - Creating a new CA ..."
    openssl req \
    -new \
    -newkey rsa:2048 \
    -days 120 \
    -nodes \
    -x509 \
    -config "output/ca.cnf" \
    -keyout "output/ca.key" \
    -out "output/ca.crt"
    echo "[INFO] - CA created."
fi

# Create the openssl configuration file for the workloads
echo "[ req ]
default_bits = 2048
encrypt_key  = no # Change to encrypt the private key using des3 or similar
default_md   = SHA256
prompt       = no
utf8         = yes
distinguished_name = req_distinguised_name
req_extensions = v3_req

[ req_distinguised_name ]
C  = ${country}
ST = ${state}
L  = ${locality}
O  = ${organization}
CN = ${1}.${domain}

[ v3_req ]
basicConstraints     = CA:FALSE
subjectKeyIdentifier = hash
keyUsage             = digitalSignature, keyEncipherment, dataEncipherment, keyAgreement
extendedKeyUsage     = anyExtendedKeyUsage, ipsecUser, ipsecEndSystem
subjectAltName       = @alt_names

[ alt_names ]
DNS.1 = ${1}.${domain}" > output/workload.cnf

# Generate the private key for the service.
openssl genrsa -out "output/${1}.${domain}.key" 2048

# Generate a CSR using the configuration and the key just generated.
openssl req \
  -new -key "output/${1}.${domain}.key" \
  -out "output/${1}.${domain}.csr" \
  -config "output/workload.cnf"
  
# Sign the CSR with our CA. If a ca.srl file exists we use CAserial, if not we use CAcreateserial
if [ -f "output/ca.srl" ]; then
    openssl x509 \
    -req \
    -days 365 \
    -in "output/${1}.${domain}.csr" \
    -CA "output/ca.crt" \
    -CAkey "output/ca.key" \
    -CAserial "output/ca.srl" \
    -extensions v3_req \
    -extfile "output/workload.cnf" \
    -out "output/${1}.${domain}.crt" 
else
    openssl x509 \
    -req \
    -days 365 \
    -in "output/${1}.${domain}.csr" \
    -CA "output/ca.crt" \
    -CAkey "output/ca.key" \
    -CAcreateserial \
    -extensions v3_req \
    -extfile "output/workload.cnf" \
    -out "output/${1}.${domain}.crt" 
fi


# Create the pkcs12 container
openssl pkcs12 -export -inkey output/${1}.${domain}.key -in output/${1}.${domain}.crt -out output/${1}.${domain}.p12 -passout pass: -descert -des3