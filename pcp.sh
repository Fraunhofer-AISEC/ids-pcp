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

set -e

if [ "$#" != "2" ] && [ "$#" != "4" ] && [ "$#" != "7" ] && [ "$#" != "8" ]; then
	echo "Usage must be one of: 
	./pcp.sh <pki-dir> ca
		Sets up the folder <dir>/pki with the initial root CA as well as two intermediary CAs for users and devices and prepares the database for the OCSP servers. 
	./pcp.sh <pki-dir> gen [developer|evaluator|certifier|operator|device] <common name>
		Generates a private key and respective x509v3 certificate with the specified role and the provided name used as Subject. The certificate is signed by the Device SubCA for devices and by the User SubCA for the other (user) roles.
	./pcp.sh <pki-dir> <input-dir> <output-dir> eva <name of manifest/company description> <first signer> <second signer> <third signer>
		Signs the specified software manifest or company description with the keys of the three users specified (developer/operator, evaluator, certifier) to represent the result of a successful certification process.
	./pcp.sh <pki-dir> <input-dir> <output-dir> sig [operator|device] <artefact to be signed> <signer>
		Signs the specified input file (artefact) with the (operator or device) key specified. It may be used for signing connector descriptions (with operator key) or attestation reports (device key). 
	./pcp.sh <pki-dir> clean-ca
		Deletes the content of <pki-dir> folder with all generated certificates and keys.
		Warning: Only utilize this command if the directory contains solely files which can be regenerated with the tool!
	./pcp.sh <output-dir> clean-signed
		Deletes the content of <output-dir> which is intended to be signed manifests or descriptions. 
		Warning: Only utilize this command if the directory contains solely files which can be regenerated with the tool!
	"
	exit 1
fi

TOOLDIR=$(dirname "$0")/pcp_utils

PKI="$1"
shift
if [ "$1" != "ca" ] && [ "$1" != "gen" ] && [ "$1" != "clean-pki" ] && [ "$1" != "clean-signed" ]; then
	INPUT="$1"
	shift
	SIGNED="$1"
	shift
fi
if [ "$1" == "clean-signed" ]; then
	SIGNED=$PKI
fi

echo "$@"

case "$1" in
  ca)
    mkdir -p "$PKI"
    $TOOLDIR/setup_CA.sh "$PKI"
    ;;
  gen)
    $TOOLDIR/generate_key_and_csr.sh "$PKI" $2 $3
    $TOOLDIR/sign_cert.sh "$PKI" $2 $3
    ;;
  eva)
    mkdir -p $(dirname "$SIGNED/$2")
    $TOOLDIR/sign_artefact "$INPUT/$2" $PKI $3 $4 $5 "$SIGNED/$2"
    ;;
  sig)
    mkdir -p $(dirname "$SIGNED/$3")
    $TOOLDIR/sign_artefact "$INPUT/$3" $PKI $2 $4 "$SIGNED/$3"
    ;;
  clean-pki)
    rm -r $PKI/*
    ;;
  clean-signed)
    rm -r $SIGNED/*
    ;;
  *)
    ;;
esac

