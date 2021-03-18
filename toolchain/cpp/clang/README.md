# LLVM / Clang Cross-Compile Toolchain

A cross compile toolchain targeting `linux_arm` and `linux_arm64` building from
a `linux_amd64` host. This toolchain requires a Debian like linux host (based on
Debian 10) to use.

By default, the toolchain is configured to statically link against LLVM's libc++.

`install_clang_config.sh` installs the clang toolchain binaries for a `linux_amd64`
host and the necessary cross compile components extracted from the clang toolchain
binaries for the `linux_arm` and `linux_arm64` architectures / platforms

**This bazel toolchain expects tools and additional components to be laid out**
**in the exact manner as represented by the next example**

### Example Dockerfile w/ Toolchain Installation

```dockerfile
FROM debian:buster
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc g++ \
        gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf \
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
        libtinfo5 \
        curl xz-utils ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ENV INSTALL_LLVM_VERSION=10.0.0
ADD https://raw.githubusercontent.com/emacski/bazel-tools/master/toolchain/cpp/clang/install_clang_cross.sh /
RUN  sh /install_clang_cross.sh
```

 * **gcc, g++, gcc-arm-linux-gnueabihf, g++-arm-linux-gnueabihf,**
   **gcc-aarch64-linux-gnu, g++-aarch64-linux-gnu** required for architecture
   specific system dependencies such as system and gnu includes
 * **libtinfo5** is a required dependency for the clang toolchain
 * **curl, xz-utils** are required by the `install_clang_cross.sh` install script

## Bazel Usage

`WORKSPACE`
```
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-0.0.1",
    urls = ["https://github.com/emacski/bazel-tools/archive/bazel-tools-0.0.1.tar.gz"],
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
```
register_toolchains("@com_github_emacski_bazeltools//toolchain/cpp/clang:all")
```

Specify the following on the command line or in a `.bazelrc` file when building:
```
--incompatible_enable_cc_toolchain_resolution
```

### Legacy Toolchain Resolution (CROSSTOOL)

Specify the following on the command line or in a `.bazelrc` file when building:
```sh
# linux_arm64
--crosstool_top=@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:toolchain
--cpu=aarch64
# linux_arm
--crosstool_top=@com_gitlab_emacski_bazeltools//toolchain/cpp/clang:toolchain
--cpu=arm
```

### Genrule Make Variables

This toolchain provides a make var target for genrules to help facilitate
genrule cross-building when required.

**Target:** `//tools/cpp/clang:current_cc_toolchain`

Example
```
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
      "@com_gitlab_emacski_bazeltools//tools/cpp/clang:current_cc_toolchain"
    ],
)
```
