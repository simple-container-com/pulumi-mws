// SPDX-License-Identifier: Apache-2.0
// Copyright (c) Simple Container

package main

import (
	pftfgen "github.com/pulumi/pulumi-terraform-bridge/v3/pkg/pf/tfgen"

	mws "github.com/simple-container-com/pulumi-mws/provider"
)

func main() {
	// pf/tfgen.Main, NOT the plain pkg/tfgen.Main — and this pairs with the
	// pf/tfbridge.Main in cmd/pulumi-resource-mws. The two entrypoints MUST agree.
	//
	// terraform-provider-mws is a PURE terraform-plugin-framework provider: its
	// main.go is a single providerserver.Serve(ctx, provider.NewProvider(version)),
	// with terraform-plugin-framework v1.19.0 and no terraform-plugin-mux among its
	// dependencies (checked against tag 0.0.38). So this repo is the mirror image of
	// its sibling simple-container-com/pulumi-sbercloud, which bridges an
	// SDKv2-only provider with the plain entrypoints, and it needs neither
	// pf's MainWithMuxer nor MuxShimWithPF — there is no second half to route to.
	//
	// Note the signature difference that bit on the way in: pf/tfgen.Main takes
	// (provider, info) with NO version argument — the version rides on
	// info.Version — whereas the plain pkg/tfgen.Main takes (provider, version, info).
	// Mixing them up is a compile error here, but the runtime pairing is not: a
	// plain tfbridge.Main over a pf shim builds fine and panics on the engine's
	// first runtime call with "schemaOnlyProvider does not implement runtime
	// operation InitLogging" (pulumi-yandex paid for that one).
	pftfgen.Main("mws", mws.Provider())
}
