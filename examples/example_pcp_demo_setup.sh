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

PCP="../pcp.sh"
PKI_DIR="./demo_setup/pki"
INPUT_DIR="./demo_setup/input"
OUTPUT_DIR="./demo_setup/signed"

printf "Using PCP=%s, PKI_DIR=%s, INPUT_DIR=%s, and OUTPUT_DIR=%s\n" "$PCP" "$PKI_DIR" "$INPUT_DIR" "$OUTPUT_DIR"

ca  () {
  "$PCP" "$PKI_DIR" ca  "$@"
}

gen () {
  "$PCP" "$PKI_DIR" gen "$@"
}

eva () {
  "$PCP" "$PKI_DIR" "$INPUT_DIR" "$OUTPUT_DIR" eva "$@"
}

sig () {
  "$PCP" "$PKI_DIR" "$INPUT_DIR" "$OUTPUT_DIR"  sig "$@"
}

clean_pki () {
  "$PCP" "$PKI_DIR" clean-pki "$@"
}

clean_signed () {
  "$PCP" "$OUTPUT_DIR" clean-signed "$@"
}


# Remove the previous PKI and signed files to ensure a clean start
clean_pki
clean_signed

# Setup PKI with root CA and two SubCAs (one for users, one for devices)
ca

# Generate user certificates as required
gen developer developer_A
gen developer developer_B
gen developer developer_C

gen operator operator_A

gen evaluator evaluator_A
gen evaluator evaluator_B
gen evaluator evaluator_C

gen certifier certifier_A
gen certifier certifier_B

# Generate device keys and certificates
# Alternatively it is possible to generate keys on the device itself (e.g. inside a TPM) and sign the public keys with the Device SubCA key
gen device provider-connector.test.aisec.fraunhofer.de
gen device consumer-connector.test.aisec.fraunhofer.de

# Simulate component certification represented by signed software manifests
eva dsc.manifest.json				developer_A evaluator_A certifier_A
mkdir -p "$OUTPUT_DIR/srtm-connector/"
mkdir -p "$OUTPUT_DIR/drtm-connector/"
cp "$OUTPUT_DIR/dsc.manifest.json" "$OUTPUT_DIR/srtm-connector/dsc.manifest.json" 
mv "$OUTPUT_DIR/dsc.manifest.json" "$OUTPUT_DIR/drtm-connector/dsc.manifest.json" 
eva drtm-connector/drtm-os.manifest.json		developer_B evaluator_B certifier_A
eva srtm-connector/srtm-os.manifest.json		developer_B evaluator_B certifier_A
eva drtm-connector/drtm-rtm.manifest.json		developer_C evaluator_B certifier_A
eva srtm-connector/srtm-rtm.manifest.json		developer_C evaluator_B certifier_A

# Simulate operational environment certification represented by signed company descriptions
eva company.description.json				operator_A  evaluator_C certifier_B
cp "$OUTPUT_DIR/company.description.json" "$OUTPUT_DIR/srtm-connector/company.description.json" 
mv "$OUTPUT_DIR/company.description.json" "$OUTPUT_DIR/drtm-connector/company.description.json" 

# Provide signed descriptions of the connector setup
sig operator drtm-connector/drtm-connector.description.json	operator_A
sig operator srtm-connector/srtm-connector.description.json	operator_A

# Sign certificate parameters which can be used to generating device certificates for TPM keys
sig operator drtm-connector/drtm-ak.certparams.json		operator_A
sig operator drtm-connector/drtm-tlskey.certparams.json		operator_A
sig operator srtm-connector/srtm-ak.certparams.json		operator_A
sig operator srtm-connector/srtm-tlskey.certparams.json		operator_A
