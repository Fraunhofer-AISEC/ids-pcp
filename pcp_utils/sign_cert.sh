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

# This script triggers the signing of device or user certificates. It expects the directory used for the pki, the intended profile and the subject name for the intended certificate (without whitespaces)
if [ "$#" != "3" ] ; then
	echo "Usage: ./sign_device_csr.sh <pki_dir> [developer|evaluator|certifier|operator|device] <common name>"
	exit 1
fi

if [ "$2" != "developer" ] && [ "$2" != "evaluator" ] && [ "$2" = "certifier" ] && [ "$2" = "operator" ] && [ "$2" = "device" ]; then
	echo "Usage: ./sign_device_csr.sh <pki_dir>  [developer|evaluator|certifier|operator|device] <common name>"
	exit 1
fi

PKIDIR=$1
SUBJECT=$3

case "$2" in
  device)
    cfssl sign -ca "$PKIDIR/ca/device_sub_ca.pem" -ca-key "$PKIDIR/ca/device_sub_ca-key.pem" -db-config "$PKIDIR/ocsp/sqlite_db_devices.json" "$PKIDIR/$SUBJECT/$SUBJECT.csr" | cfssljson -bare "$PKIDIR/devices/$SUBJECT"
    ;;
  *)
    cfssl sign -ca "$PKIDIR/ca/user_sub_ca.pem" -ca-key "$PKIDIR/ca/user_sub_ca-key.pem" -db-config "$PKIDIR/ocsp/sqlite_db_users.json" "$PKIDIR/$SUBJECT/$SUBJECT.csr" | cfssljson -bare "$PKIDIR/users/$SUBJECT"
    ;;
esac
