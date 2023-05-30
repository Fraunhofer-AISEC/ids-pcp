# IDS PKI and Certification Process (PCP) Simulation

This repository provides a Proof of Concept implementation for a technical representation of the certification process in the International Data Spaces (IDS). It requires setting up a PKI for all devices under one Device SubCA and additionally providing user certificates for developers, connector operators, evaluators and certifiers by a User SubCA. Both SubCAs are placed under one Root CA trusted by all participants in the data space.

At the start of the certification process, an applicant (developer or device operator) describes the organization or component to be certified in metadata files called Company Description or Software Manifests. The correctness of those descriptions ate then confirmed by the applicant as well as from evaluator and certifier during the certification process. This confirmation is technically represented by a signature from the responsible entity. This PoC utilized JSON Web Signatures ([RFC 7515](https://datatracker.ietf.org/doc/html/rfc7515)) for those signatures.

The signed artefacts can be utilized to prove the integrity of a connector's software stack and the trustworthiness of the connector operator during establishing a communication channel. Generating the necessary measurements from the currently running software and performing the remote attestation based on the generated manifests and descriptions is not in scope for this repository but is addressed in https://github.com/Fraunhofer-AISEC/cmc.

## Prerequistes

**Note:** The tooling was developed and tested on Ubuntu 22.04LTS with go version 1.19.2, and cfssl version 1.6.4.

* Install **Go** (https://golang.org/doc/install) in a version greater than 1.16.  
* Install Cloudflare's **CFSSL** tool used for setting up the PKI  
according to the instructions in https://github.com/cloudflare/cfssl/tree/master.  
The following command can be used for go with a version greater than 1.18:
```sh
go install github.com/cloudflare/cfssl/cmd/...@latest
```
* Install **SqLite3** which is used by CFSSL to manage the databases for OCSP providers
```sh
sudo apt install sqlite3
```
* Compile the program used for signing artefacts as JSON Web Signature (based on [Go JOSE](https://pkg.go.dev/gopkg.in/square/go-jose.v2))
``` sh
cd pcp_utils
go build sign_artefact.go
```

## Quick Start with Demo Setup
The script ```examples/example_pcp_demo_setup.sh``` uses the PCP Tool to simulate the certification for a demo setup described in the ```examples/demo_setup/input``` folder. Output of the tool is the folder ```examples/demo_setup/pki``` containing the PKI with all necessary keys and certificates as well as the folder ```examples/demo_setup/signed``` with signed manifests and descriptions:
```sh
cd examples
# Generate PKI and sign files for demo setup with
./example_pcp_demo_setup.sh
```

## Explanation and Usage of the PCP Tool
* The content for software manifests and descriptions needs to be prepared and placed in one folder which is passed to the tool as path to the ```input``` folder. Examples for those manifests and descriptions can be seen in the ```examples/demo_setup/input```.
* The provided "PKI and Certification Process simulation" (PCP) tool in the folder ```pki_and_signing/``` is used to setup the necessary PKI and sign description artefactes.
* The established keys and certificates for all required CAs, users and connectors are stored in the folder which is passed to the tool as path to a ```pki``` folder. For the example setup it is put into the ```examples/demo_setup/pki```.
* The signed software manifests and descriptions are placed into the folder which is passed to the tool as path to an ```output``` folder. For the example setup it is put into the ```examples/demo_setup/signed```.
* The PCP tool allows generation of fresh key pairs for the connector. The private key is placed in ```pki/<fqdn>/<fqdn>-key.pem```, the public key in the folder for device certificates ```pki/devices/<fqdn>.pem```  
    Note: For better protection, the key should be generated and used protected by hardware mechanisms (e.g. inside of a TPM), but for a simple demo setup it can be generated with this tool and can be used for signing a provided attestation report.

The PCP script ```pcp.sh``` offers the following commands:

* ```pcp.sh <pki-dir> ca```
		Sets up the general PKI structure into the folder ```<pki-dir>``` with the root CA as well as two intermediary CAs for users and devices and prepares the database for the OCSP servers.
* ```pcp.sh <pki-dir> gen [developer|evaluator|certifier|operator|device] <common name>```
		Generates a private key and respective x509v3 certificate with the specified role and the provided name used as Subject. The certificate is signed by the Device SubCA for connectors and by the User SubCA for the other user roles.
* ```pcp.sh <pki-dir> <input-dir> <output-dir> eva <name of manifest/company description> <first signer> <second signer> <third signer>```
		Signs the specified software manifest or company description with the keys of the three users specified (developer/operator, evaluator, certifier) to represent the result of a successful certification process.
* ```pcp.sh <pki-dir> <input-dir> <output-dir> sig [operator|device] <artefact to be signed> <signer>```
		Signs the specified input file with the key specified (operator or device). It should be used for signing connector descriptions (with operator key) or attestation reports (with device key).
* ```pcp.sh <pki-dir> clean-ca```
		Deletes the sub-folders in ```<pki-dir>``` folder with all generated certificates and keys.
* ```pcp.sh <output-dir> clean-signed```
		Deletes the content of ```<output-dir>``` which is intended to be signed manifests or descriptions. Warning: Only utilize this command if the directory contains solely files which can be regenerated with the tool!

## Usage of OCSP Servers
The designed PKI supports running OCSP Servers for checking revocation of certifications.

The OCSP-Servers need to be run at pre-defined interfaces:

* for the Root CA locally at: 127.0.0.1:8887 (the URL is ingrained in the respective SubCA certificates)
* for the User CA locally at: 127.0.0.1:8888 (the URL is ingrained in the respective user certificates)
* for the Device CA locally at: 127.0.0.1:8889 (the URL is ingrained in the respective device certificates)

The following instructions show exemplary which commands should be used for the OCSP Server for user certificates (controlled by the User SubCA):
````sh
# Open two terminals (1 and 2) and move to pki folder
cd demo_setup/pki/

# Terminal 1: Start the OCSP Server
cfssl ocsprefresh -db-config ocsp/sqlite_db_users.json -ca ca/user_sub_ca.pem -responder ocsp/ocsp_users.pem -responder-key ocsp/ocsp_users-key.pem
cfssl ocspdump -db-config ocsp/sqlite_db_users.json> ocsp/ocspdump_users.txt  
cfssl ocspserve -port=8888 -responses=ocsp/ocspdump_users.txt  -loglevel=0

# Terminal 2: Query the OCSP Server for status of the certificate for certifier_A (which should be still valid)
openssl ocsp -issuer ocsp/ocsp_users.pem -issuer ca/user_sub_ca.pem -no_nonce -cert users/certifier_A.pem -CAfile ca/ca.pem -text -url http://localhost:8888

# Terminal 2: For revocation of the certificate of Certifier A get the serial number and aki from
cfssl certinfo -cert users/certifier_A.pem

# Terminal 2: Revoke the certificate of Certifier A with the identified serial number and aki (in hex, letters lower case, without ":")
cfssl revoke -db-config ocsp/sqlite_db_users.json -serial "<serial>" -aki "<aki>" -reason="<reason>"
# example: cfssl revoke -db-config ocsp/sqlite_db_users.json -serial "18248994571872289389976161865184472389841125095" -aki "80bb388bfb5733d451ded7e44675cfe0dd31da" -reason="superseded"

# Terminal 1: Stop and update OCSP Provider
cfssl ocsprefresh -db-config ocsp/sqlite_db_users.json -ca ca/user_sub_ca.pem -responder ocsp/ocsp_users.pem -responder-key ocsp/ocsp_users-key.pem
cfssl ocspdump -db-config ocsp/sqlite_db_users.json ocsp/ocspdump_users.txt
cfssl ocspserve -port=8888 -responses=ocsp/ocspdump_users.txt -loglevel=0

# Terminal 2: Query the OCSP Server for status of the certificate to show revocation
openssl ocsp -issuer ocsp/ocsp_users.pem -issuer ca/user_sub_ca.pem -no_nonce -cert users/certifier_A.pem -CAfile ca/ca.pem -text -url http://localhost:8888
````
