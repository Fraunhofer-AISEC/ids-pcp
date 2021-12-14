// Copyright(c) 2021 Fraunhofer AISEC
// Fraunhofer-Gesellschaft zur Foerderung der angewandten Forschung e.V.
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the License); you may
// not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an AS IS BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"fmt"
	"io/ioutil"
	"os"

	"gopkg.in/square/go-jose.v2"
	//	"strings"
	//	"encoding/hex"
)

func CheckError(err error) {
	if err != nil {
		fmt.Println(err)
		os.Exit(-1)
	}
}

// loadCert loads a cert from PEM file
func loadCert(file string) *x509.Certificate {

	data, err := ioutil.ReadFile(file)
	CheckError(err)

	input := data

	block, _ := pem.Decode(data)
	if block != nil {
		input = block.Bytes
	}

	cert, err := x509.ParseCertificate(input)
	if err != nil {
		panic(err)
	}
	return cert
}

// loadPrivateKey loads a private key from PEM file
func loadPrivateKey(file string) interface{} {

	data, err := ioutil.ReadFile(file)
	CheckError(err)

	input := data
	block, _ := pem.Decode(data)
	if block != nil {
		input = block.Bytes
	}

	priv, err := x509.ParseECPrivateKey(input)
	CheckError(err)

	return priv
}

func signSoftwareManifestOrCompanyDescription(data []byte, pkiFolder string, devOrOpName string, evalName string, certName string) string {

	devOrOpKey := loadPrivateKey(pkiFolder + "/" + devOrOpName + "/" + devOrOpName + "-key.pem")
	evalKey := loadPrivateKey(pkiFolder + "/" + evalName + "/" + evalName + "-key.pem")
	certKey := loadPrivateKey(pkiFolder + "/" + certName + "/" + certName + "-key.pem")

	devOrOpCert := loadCert(pkiFolder + "/users/" + devOrOpName + ".pem")
	evalCert := loadCert(pkiFolder + "/users/" + evalName + ".pem")
	certCert := loadCert(pkiFolder + "/users/" + certName + ".pem")

	userCert := loadCert(pkiFolder + "/ca/user_sub_ca.pem")
	caCert := loadCert(pkiFolder + "/ca/ca.pem")

	alg := jose.SignatureAlgorithm("ES256")
	var opt0 jose.SignerOptions
	var opt1 jose.SignerOptions
	var opt2 jose.SignerOptions
	signer0, err := jose.NewSigner(jose.SigningKey{Algorithm: alg, Key: devOrOpKey}, opt0.WithHeader("x5c", []string{base64.StdEncoding.EncodeToString(devOrOpCert.Raw), base64.StdEncoding.EncodeToString(userCert.Raw), base64.StdEncoding.EncodeToString(caCert.Raw)}))
	signer1, err := jose.NewSigner(jose.SigningKey{Algorithm: alg, Key: evalKey}, opt1.WithHeader("x5c", []string{base64.StdEncoding.EncodeToString(evalCert.Raw), base64.StdEncoding.EncodeToString(userCert.Raw), base64.StdEncoding.EncodeToString(caCert.Raw)}))
	signer2, err := jose.NewSigner(jose.SigningKey{Algorithm: alg, Key: certKey}, opt2.WithHeader("x5c", []string{base64.StdEncoding.EncodeToString(certCert.Raw), base64.StdEncoding.EncodeToString(userCert.Raw), base64.StdEncoding.EncodeToString(caCert.Raw)}))
	CheckError(err)

	obj, err := signer0.Sign(data)
	CheckError(err)
	obj1, err := signer1.Sign(data)
	CheckError(err)
	obj2, err := signer2.Sign(data)
	CheckError(err)

	obj.Signatures = append(obj.Signatures, obj1.Signatures[0])
	obj.Signatures = append(obj.Signatures, obj2.Signatures[0])

	var output string
	output = obj.FullSerialize()
	return output
}

func signConnectorDescription(data []byte, pkiFolder string, opName string) string {

	opKey := loadPrivateKey(pkiFolder + "/" + opName + "/" + opName + "-key.pem")
	opCert := loadCert(pkiFolder + "/users/" + opName + ".pem")
	userCert := loadCert(pkiFolder + "/ca/user_sub_ca.pem")
	caCert := loadCert(pkiFolder + "/ca/ca.pem")

	alg := jose.SignatureAlgorithm("ES256")
	var opt jose.SignerOptions
	signer, err := jose.NewSigner(jose.SigningKey{Algorithm: alg, Key: opKey}, opt.WithHeader("x5c", []string{base64.StdEncoding.EncodeToString(opCert.Raw), base64.StdEncoding.EncodeToString(userCert.Raw), base64.StdEncoding.EncodeToString(caCert.Raw)}))
	CheckError(err)

	obj, err := signer.Sign(data)
	CheckError(err)

	var output string
	output = obj.FullSerialize()
	return output
}

func signAttestationReport(data []byte, pkiFolder string, connName string) string {

	connKey := loadPrivateKey(pkiFolder + "/" + connName + "/" + connName + "-key.pem")
	connCert := loadCert(pkiFolder + "/devices/" + connName + ".pem")
	deviceCACert := loadCert(pkiFolder + "/ca/device_sub_ca.pem")
	caCert := loadCert(pkiFolder + "/ca/ca.pem")

	alg := jose.SignatureAlgorithm("ES256")
	var opt jose.SignerOptions
	signer, err := jose.NewSigner(jose.SigningKey{Algorithm: alg, Key: connKey}, opt.WithHeader("x5c", []string{base64.StdEncoding.EncodeToString(connCert.Raw), base64.StdEncoding.EncodeToString(deviceCACert.Raw), base64.StdEncoding.EncodeToString(caCert.Raw)}))
	CheckError(err)

	obj, err := signer.Sign(data)
	CheckError(err)

	var output string
	output = obj.FullSerialize()
	return output
}

func main() {
	if len(os.Args) != 6 && len(os.Args) != 7 {
		fmt.Println("Usage:")
		fmt.Println("./sign_manifest <manifest file> <pki folder> <developer or operator name> <evaluator name> <certifier name> <output file>")
		fmt.Println("or\n ./sign_manifest <manifest file> <pki folder> [operator|device] <operator or device name> <output file>")
		fmt.Println("The first 2 parameters shall be paths to a file with unsigned artefact content and the folder containing the generated PKI." +
			"The names for developer/operator/device/evaluator/certifier must match the respective private key file name (in PEM format)." +
			"The final parameter provides the intended filename for the result (a signed manifest).")
		os.Exit(-1)
	}
	inFile := os.Args[1]
	pkiFolder := os.Args[2]

	data, err := ioutil.ReadFile(inFile)
	CheckError(err)

	var output string
	var outFile string
	if len(os.Args) == 6 {
		role := os.Args[3]
		outFile = os.Args[5]
		if role == "operator" {
			opName := os.Args[4]
			output = signConnectorDescription(data, pkiFolder, opName)
		} else if role == "connector" {
			connName := os.Args[4]
			output = signAttestationReport(data, pkiFolder, connName)
		} else {
			fmt.Println("Usage:")
			fmt.Println("./sign_manifest <manifest file> <pki folder> <developer or operator name> <evaluator name> <certifier name> <output file>")
			fmt.Println("or\n ./sign_manifest <manifest file> <pki folder> [operator|connector] <operator or connector name> <output file>")
			fmt.Println("The first 2 parameters shall be paths to a file with unsigned artefact content and the folder containing the generated PKI." +
				"The names for developer/operator/device/evaluator/certifier must match the respective private key file name (in PEM format)." +
				"The final parameter provides the intended filename for the result (a signed manifest).")
			os.Exit(-1)
		}
	} else {
		devOrOpName := os.Args[3]
		evalName := os.Args[4]
		certName := os.Args[5]
		outFile = os.Args[6]
		output = signSoftwareManifestOrCompanyDescription(data, pkiFolder, devOrOpName, evalName, certName)
	}

	err = ioutil.WriteFile(outFile, []byte(output), 0644)
	CheckError(err)
}
