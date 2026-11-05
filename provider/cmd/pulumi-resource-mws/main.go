// SPDX-License-Identifier: Apache-2.0
// Copyright (c) Simple Container

package main

import (
	"context"

	_ "embed"

	pfbridge "github.com/pulumi/pulumi-terraform-bridge/v3/pkg/pf/tfbridge"

	mws "github.com/simple-container-com/pulumi-mws/provider"
)

//go:embed schema.json
var pulumiSchema []byte

func main() {
	// pf/tfbridge.Main, pairing with the pf/tfgen.Main in cmd/pulumi-tfgen-mws.
	// See the long comment there for why this repo uses the pf entrypoints and
	// not the plain ones, and why the pairing is not something the compiler
	// checks for you at runtime.
	pfbridge.Main(context.Background(), "mws", mws.Provider(), pfbridge.ProviderMetadata{
		PackageSchema: pulumiSchema,
	})
}
