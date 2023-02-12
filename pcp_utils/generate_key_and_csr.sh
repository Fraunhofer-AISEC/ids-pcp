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

# This script triggers the generation of a private-public key pair and a respective CSR.
# It expects the directory used for the pki, the intended profile and the subject name for the intended certificate (without whitespaces)
if [ "$#" != "3" ] ; then
	echo "Usage: ./generate_key_and_csr.sh <pki_dir> [developer|evaluator|certifier|operator|device] <common name>"
	exit 1
fi

if [ "$2" != "developer" ] && [ "$2" != "evaluator" ] && [ "$2" != "certifier" ] && [ "$2" != "operator" ] && [ "$2" != "device" ]; then
	echo "Usage: ./generate_key_and_csr.sh <pki_dir> [developer|evaluator|certifier|operator|device] <common name>"
	exit 1
fi

PKIINPUT="$(dirname "$0")"
PKIDIR=$1
SUBJECT=$3
JSON="{
  \"CN\": \"$SUBJECT\",
  \"names\": [
  {
    \"C\": \"DE\",
    \"L\": \"Garching\",
    \"O\": \"Fraunhofer AISEC\",
    \"OU\": \"$2\"
  }
  ]
}"


mkdir -p $PKIDIR/$SUBJECT
printf "%s\n" "$JSON" > "$PKIDIR/$SUBJECT/$SUBJECT.json"
cfssl genkey -config "$PKIINPUT/ca-config.json" -profile $2 "$PKIDIR/$SUBJECT/$SUBJECT.json" | cfssljson -bare "$PKIDIR/$SUBJECT/$SUBJECT"

