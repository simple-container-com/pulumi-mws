// SPDX-License-Identifier: Apache-2.0
// Copyright (c) Simple Container

package version

// Version is initialized by the Go linker to contain the semver of this build.
// A non-empty default matters here in a way it does not for an SDKv2 bridge:
// pf/tfbridge.Main calls pfversion.Validate(prov.Version) and exits before
// serving if the value is empty or not semver. Keeping a dev default means
// `make provider` from a clean checkout produces a binary that at least runs.
var Version = "0.0.1-dev"
