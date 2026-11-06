# pulumi-mws

A [Pulumi](https://www.pulumi.com/) provider for **MWS Cloud Platform** (МТС Web Services),
bridged from MWS's official Terraform provider
[`mws-cloud-platform/terraform-provider-mws`](https://github.com/mws-cloud-platform/terraform-provider-mws)
(Apache-2.0).

It exists to back [`sc-plugin-mws`](https://github.com/simple-container-com/sc-plugin-mws),
the Simple Container plugin for MWS. It is a sibling of
[`pulumi-yandex`](https://github.com/simple-container-com/pulumi-yandex) and
[`pulumi-sbercloud`](https://github.com/simple-container-com/pulumi-sbercloud) and follows
the same static-bridge pattern.

## What's bridged

**41 resources / 53 functions / 1496 inputs** across 15 service modules, generated from
upstream tag `0.0.38` (commit `b4f05674`):

| Module | Resources |
|---|---|
| `compute` | `virtualMachine`, `disk`, `diskBackup`, `image`, `snapshot` |
| `vpc` | `network`, `subnet`, `address`, `addressGroup`, `externalAddress`, `firewallRule`, `oneToOneNat`, `egressNat`, `route` |
| `mk8s` | `cluster`, `nodeGroup` |
| `iam` | `serviceAccount`, `authorizedKey`, `apiKey`, `hmacKey` |
| `secretmanager` | `secret`, `secretVersion` |
| `kms` | `cryptoKey` |
| `nlb` | `nlb` |
| `mpostgres` | `cluster`, `clusterUser`, `clusterDatabase`, `backup` |
| `mkafka` | `cluster`, `clusterUser`, `topic` |
| `mclickhouse` | `cluster`, `backup` |
| `metastore` | `iceberg`, `icebergRoleBinding` |
| `certmanager` | `certificate` |
| `queue` | `topic`, `topicRoleBinding` |
| `resmanager` | `enabledService`, `projectRoleBinding` |
| `gpt` | `deployment` |

Token shape is `mws:<service>/<resource>:<Resource>` — e.g.
`mws:compute/virtualMachine:VirtualMachine`. **These strings are a frozen public contract**:
stack state and URNs embed them. See the comment on `knownModules` in
`provider/resources.go` before changing the token strategy.

Notably **absent** upstream, and therefore here: any object-storage/bucket resource and any
container-registry resource. `iam/hmacKey` implies an S3-compatible API exists but it is not
modelled, so SC cannot use MWS for a state-storage bucket or an image registry via IaC.

## Why a static bridge and not the parameterized one

SC proved Pulumi's parameterized bridge (`pulumi package add terraform-provider …`) on
Cloud.ru Evolution on 2026-10-22. It was rejected for MWS on two measurements — see the
package doc in `provider/resources.go` for the full reasoning:

1. **Both provider registries are geoblocked from RU networks** (measured 2026-11-05:
   `registry.terraform.io` → "Content not available in your region",
   `registry.opentofu.org` → 403), as is `get.pulumi.com` where the `terraform-provider`
   bridge plugin itself lives. A static bridge moves that to build time on a runner we control.
2. **MWS models resources Kubernetes-style** (`kind`/`metadata`/`spec`/`ref`/`usages`), four
   to five levels deep — 158 generated nested types for `VirtualMachine` alone. A generated
   SDK turns a misspelled nested field into a compile error instead of a deploy-time one.

## Upstream pinning — read before bumping

Upstream tags releases **without** the `v` prefix Go modules require (`0.0.38`, not
`v0.0.38`), so there is no fetchable tagged version and `provider/go.mod` pins the **commit**.
To bump:

```bash
SHA=$(gh api repos/mws-cloud-platform/terraform-provider-mws/git/ref/tags/<tag> --jq .object.sha)
cd provider && go get go.mws.cloud/terraform-provider-mws@$SHA
```

The module path is the vanity `go.mws.cloud/terraform-provider-mws`, which serves `go-import`
meta pointing back at GitHub.

Upstream also requires **Go 1.27**, which is inherited by `provider/go.mod` — so a box with
`GOTOOLCHAIN=local` on an older Go cannot build the **provider** module (the tfgen and
`pulumi-resource-mws` binaries) at all.

**`sdk/go.mod` deliberately declares `go 1.26.10`, not 1.27.** The generator emits its own
current toolchain version into both modules, but the SDK needs nothing from 1.27 — its only
direct dependency, `pulumi/pulumi/sdk/v3 v3.274.1`, declares `go 1.26.6`. The gratuitous 1.27
made the SDK unconsumable by every SC repo (the fleet pins `GOTOOLCHAIN` via `setup-go`, and
`sc-plugin-mws` is on `go 1.26.10`): `go build` fails with
`go.mod requires go >= 1.27 (running go 1.26.10; GOTOOLCHAIN=local)` before it compiles a line.
**After every `tfgen go` regeneration, re-lower `sdk/go.mod`** — do not propagate the
provider's constraint into the SDK, and do not raise it to match a newly-released toolchain
unless the SDK genuinely needs it.

## Build

```bash
cd provider && go build ./cmd/pulumi-tfgen-mws          # codegen binary
./pulumi-tfgen-mws schema --out ./cmd/pulumi-resource-mws # regenerate schema.json
cd .. && ./provider/pulumi-tfgen-mws go --out sdk/go      # regenerate the Go SDK
cd provider && go build ./...                             # provider binary (embeds schema.json)
cd ../sdk && go build ./...                               # SDK compiles
```

`provider/go.mod` carries an `exclude` for `github.com/pulumi/pulumi-java/pkg v0.17.0`:
two module paths both serve `pulumi-java/pkg/codegen/java` and `pkg/tfgen` imports it, so
without the exclude the build fails with `ambiguous import`.

## Licence

This bridge: Apache-2.0. Upstream `terraform-provider-mws`: Apache-2.0,
© MTS Web Services, LLC.
