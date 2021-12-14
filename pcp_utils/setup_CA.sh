# Copyright(c) 2021 Fraunhofer AISEC
# Fraunhofer-Gesellschaft zur Foerderung der angewandten Forschung e.V.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the License); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A script to provide the basic parts of the IDS PKI: Root CA, Device SubCA, User SubCA and their respective OCSP Servers
# The OCSP Providers are designed to run on the localhost (127.0.0.1) under different ports: 8887 for the OCSP for subCAs, 8888 for the OCSP for users, 8889 for the OCSP for devices
# The script expects one parameter with the path to the folder the pki setup shall be placed into
if [ "$#" != "1" ] ; then
	echo "Usage: ./setup_CA.sh <pki_dir>"
	exit 1
fi

PKIINPUT="$(dirname "$0")"
PKIDIR="$1"
CADIR="$PKIDIR/ca"
OCSPDIR=$(readlink -f "$PKIDIR/ocsp")
USERDIR="$PKIDIR/users"
DEVICEDIR="$PKIDIR/devices"
shift

printf "PKIINPUT is %s\n" "$PKIINPUT"
printf "PKIDIR is %s\n" "$PKIDIR"

mkdir -p $PKIDIR
mkdir -p $CADIR
mkdir -p $OCSPDIR
mkdir -p $USERDIR
mkdir -p $DEVICEDIR

# 1. Set up root CA (using ca.json to generate ca.pem and ca-key.pem)
cfssl gencert -initca "$PKIINPUT/ca.json" | cfssljson -bare "$CADIR/ca"

# 2. Set up an OCSP Server for the Root CA
# Setup the database based on the .sql file derived from ~/go/src/github.com/cloudflare/cfssl/certdb/sqlite/migrations/001_CreateCertificates.sql
cat "$PKIINPUT/certs_subcas.sql" | sqlite3 "$OCSPDIR/certdb_subcas.db"
echo "{\"driver\":\"sqlite3\",\"data_source\":\"$OCSPDIR/certdb_subcas.db\"}" > "$OCSPDIR/sqlite_db_subcas.json"

# Generate key/certificate for OCSP Signing
cfssl genkey "$PKIINPUT/ocsp_subcas.json" | cfssljson -bare "$OCSPDIR/ocsp_subcas"
cfssl sign -ca "$CADIR/ca.pem" -ca-key "$CADIR/ca-key.pem" "$OCSPDIR/ocsp_subcas.csr" | cfssljson -bare "$OCSPDIR/ocsp_subcas"

# 3. Set up the intermediate CAs (using device_sub_ca.json and user_sub_ca.json)
cfssl genkey "$PKIINPUT/device_sub_ca.json" | cfssljson -bare "$CADIR/device_sub_ca" 
cfssl sign -ca "$CADIR/ca.pem" -ca-key "$CADIR/ca-key.pem" -db-config "$OCSPDIR/sqlite_db_subcas.json" --config "$PKIINPUT/ca-config.json" -profile intermediate "$CADIR/device_sub_ca.csr" | cfssljson -bare "$CADIR/device_sub_ca"

cfssl genkey "$PKIINPUT/user_sub_ca.json" | cfssljson -bare "$CADIR/user_sub_ca"  
cfssl sign -ca "$CADIR/ca.pem" -ca-key "$CADIR/ca-key.pem" -db-config "$OCSPDIR/sqlite_db_subcas.json" --config "$PKIINPUT/ca-config.json" -profile intermediate "$CADIR/user_sub_ca.csr" | cfssljson -bare "$CADIR/user_sub_ca"

# 4. Set up OCSP Servers for the User Sub CAs
cat "$PKIINPUT/certs_users.sql" | sqlite3 "$OCSPDIR/certdb_users.db"
echo "{\"driver\":\"sqlite3\",\"data_source\":\"$OCSPDIR/certdb_users.db\"}" > "$OCSPDIR/sqlite_db_users.json"

# Generate key/certificate for OCSP Signing
cfssl genkey "$PKIINPUT/ocsp_users.json" | cfssljson -bare "$OCSPDIR/ocsp_users"
cfssl sign -ca "$CADIR/user_sub_ca.pem" -ca-key "$CADIR/user_sub_ca-key.pem" "$OCSPDIR/ocsp_users.csr" | cfssljson -bare "$OCSPDIR/ocsp_users"

# 5. Set up OCSP Servers for the User Sub CAs
cat "$PKIINPUT/certs_devices.sql" | sqlite3 "$OCSPDIR/certdb_devices.db"
echo "{\"driver\":\"sqlite3\",\"data_source\":\"$OCSPDIR/certdb_devices.db\"}" > "$OCSPDIR/sqlite_db_devices.json"

# Generate key/certificate for OCSP Signing
cfssl genkey "$PKIINPUT/ocsp_devices.json" | cfssljson -bare "$OCSPDIR/ocsp_devices"
cfssl sign -ca "$CADIR/device_sub_ca.pem" -ca-key "$CADIR/device_sub_ca-key.pem" "$OCSPDIR/ocsp_devices.csr" | cfssljson -bare "$OCSPDIR/ocsp_devices"

