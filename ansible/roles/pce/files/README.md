# PCE Files
The files in this directory should include the following:
* `pce_ui.rpm` - the PCE UI RPM
* `pce.rpm` - the PCE rpm
* `server.crt` - the cert bundle for the PCE
* `server.key` - the key for the PCE
* `ven_bundle.bz2` - the VEN bundle

The playbook opted to have less variables and hardcoded the generic names so it expects the files exactly in that naming convention. 