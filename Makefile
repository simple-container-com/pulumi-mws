# Lean on purpose. pulumi-sbercloud carries the full ci-mgmt-generated Makefile
# (dotnet/java/nodejs/python codegen, an upstream submodule + patch stack, an
# examples/ test suite, `pulumi plugin install converter terraform`); none of it
# applies here and two parts actively do not work from an RU network:
#
#   - scripts/plugins.mk pulls the CLI from get.pulumi.com, which is geoblocked
#     (the same block list that made the parameterized bridge a non-starter — see
#     the package doc in provider/resources.go);
#   - scripts/upstream.sh manages a git submodule + patches; MWS is consumed as a
#     plain Go module pinned in provider/go.mod, with no patches.
#
# So this file is only the four steps that are actually run, in the order they
# must run in. Each has been executed end-to-end (2026-11-06).

PACK    := mws
ORG     := simple-container-com
PROJECT := github.com/$(ORG)/pulumi-$(PACK)
CODEGEN := pulumi-tfgen-$(PACK)
PROVIDER := pulumi-resource-$(PACK)

# Override with `make PROVIDER_VERSION=0.1.0 …`. It is stamped into the binary
# through -ldflags and must match the release tag minus the leading `v`
# (RespectSchemaVersion is on, so the generated SDK pins to it).
PROVIDER_VERSION ?= 0.1.0
ifeq ($(shell echo $(PROVIDER_VERSION) | cut -c1),v)
$(error PROVIDER_VERSION should not start with a "v")
endif

LDFLAGS := -s -w -X $(PROJECT)/provider/pkg/version.Version=$(PROVIDER_VERSION)

# Upstream requires go 1.27; a box with GOTOOLCHAIN=local on anything older
# cannot build this repo at all, so ask for the toolchain explicitly.
export GOTOOLCHAIN ?= auto

.PHONY: all tfgen schema sdk provider clean lint

all: schema sdk provider

# 1. The codegen binary. Built ALONE, not with `./...`: cmd/$(PROVIDER)/main.go
#    `//go:embed schema.json`, and that file does not exist until step 2 — so
#    `go build ./...` on a clean tree fails with "pattern schema.json: no
#    matching files found" before tfgen ever gets a chance to produce it.
tfgen:
	cd provider && go build -o $(CURDIR)/provider/$(CODEGEN) ./cmd/$(CODEGEN)

# 2. The Pulumi schema, committed (1.8 MB). Must run from the repo root: tfgen
#    writes relative to the working directory.
schema: tfgen
	./provider/$(CODEGEN) schema --out ./provider/cmd/$(PROVIDER)

# 3. The Go SDK, committed. Regenerated wholesale — stale files from a removed
#    upstream resource would otherwise linger and still compile.
sdk: schema
	rm -rf sdk/go
	./provider/$(CODEGEN) go --out sdk/go
	cd sdk && go build ./...

# 4. The resource plugin the Pulumi engine downloads at deploy time.
provider: schema
	cd provider && CGO_ENABLED=0 go build -o $(CURDIR)/provider/$(PROVIDER) \
		-ldflags "$(LDFLAGS)" ./cmd/$(PROVIDER)

# Advisory — see the header of .golangci.yml for why this cannot run with a
# golangci-lint built against go < 1.27, and what to run by hand instead.
lint:
	cd provider && golangci-lint run --path-prefix provider -c ../.golangci.yml

clean:
	rm -f provider/$(CODEGEN) provider/$(PROVIDER)
