# LLVM / Clang Cross-Compile Toolchain

A cross-compile toolchain targeting `linux_arm` and `linux_arm64` building from
a `linux_amd64` host. This toolchain is intended for use on Debian 10 (buster) Linux.

By default, the toolchain is configured to statically link against LLVM's libc++.

## Toolchain Installation

| Install Script | Clang Version |
|----------------|---------------|
| `install_clang10_debian10.sh` | `10.0.0` |
| `install_clang11_debian10.sh` | `11.0.1` |

These scripts install the respective clang toolchain binaries for a `linux_amd64`
host and the necessary cross-compile components extracted from the clang toolchain
binaries for the `linux_arm` and `linux_arm64` architectures

Additionally, the bazel toolchain expects tools and additional components to be
aid out in the exact manner as represented by the next example

### Example Dockerfile w/ Toolchain Installation

```dockerfile
FROM debian:buster
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc g++ \
        gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf \
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# install clang 10
RUN curl -L https://raw.githubusercontent.com/emacski/bazel-tools/master/toolchain/cpp/clang/install_clang10_debian10.sh \
        -o install_clang10_debian10.sh && \
    sh install_clang10_debian10.sh && rm -f install_clang10_debian10.sh
# install clang 11
RUN curl -L https://raw.githubusercontent.com/emacski/bazel-tools/master/toolchain/cpp/clang/install_clang11_debian10.sh \
        -o install_clang11_debian10.sh && \
    sh install_clang11_debian10.sh && rm -f install_clang11_debian10.sh
```
**`gcc`, `g++`, `gcc-arm-linux-gnueabihf`, `g++-arm-linux-gnueabihf`,**
**`gcc-aarch64-linux-gnu`, `g++-aarch64-linux-gnu`** required for architecture
specific system dependencies such as system and gnu includes

## Bazel Usage

`WORKSPACE`
```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-<GIT_COMMIT_SHA>",
    urls = ["https://github.com/emacski/bazel-tools/archive/<GIT_COMMIT_SHA>.tar.gz"],
)

http_archive(
    name = "bazel_skylib",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
    ],
    sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()
```

### Constrained Toolchain Resolution

Add to `WORKSPACE` after initialized toolchain repo
```python
load(
    "@com_github_emacski_bazeltools//toolchain/cpp/clang:defs.bzl",
    "register_clang_cross_toolchains",
)

register_clang_cross_toolchains(clang_version = "11")
```

Specify the following on the command line or in a `.bazelrc` file when building:
```
--incompatible_enable_cc_toolchain_resolution
```

### Legacy Toolchain Resolution (CROSSTOOL)

Specify the following on the command line or in a `.bazelrc` file when building:
```sh
# clang 10 linux_arm64
--crosstool_top=@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:clang10_crosstool
--cpu=aarch64
# clang 10 linux_arm
--crosstool_top=@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:clang10_crosstool
--cpu=arm
# clang 11 linux_arm64
--crosstool_top=@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:clang11_crosstool
--cpu=aarch64
# clang 11 linux_arm
--crosstool_top=@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:clang11_crosstool
--cpu=arm
```

### Genrule Make Variables

This toolchain provides a make var target for genrules to help facilitate
genrule cross-building when required.

**Target:** `//toolchain/cpp/clang:current_cc_toolchain`

Example
```python
genrule(
    name = "example",
    outs = "makevars.txt"
    cmd = "\n".join([
        "echo 'CC=$(CC)' > $(OUTS)",
        "echo 'CC_FLAGS=$(CC_FLAGS)' >> $(OUTS)",
        "echo 'SYSROOT=$(SYSROOT)' >> $(OUTS)",
        "echo 'TARGET_GNU_SYSTEM_NAME=$(TARGET_GNU_SYSTEM_NAME)' >> $(OUTS)",
    ]),
    toolchains = [
      "@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:current_cc_toolchain"
    ],
)
```
