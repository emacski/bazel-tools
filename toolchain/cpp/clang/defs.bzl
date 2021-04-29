# Copyright 2021 Erik Maciejewski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# map bazel cpu names to common cpu names
BAZEL_CPU_MAP = {"k8": "x86_64", "aarch64": "aarch64", "armhf": "arm"}

def register_clang_cross_toolchains(clang_version = None):
    """Register the cross-compile toolchains of the supplied `clang_version`

    Args:
        clang_version: clang major version
    """
    toolchain_prefix = "@com_github_emacski_bazeltools//toolchain/cpp/clang"
    toolchain_targets = [
        "{prefix}:clang{version}-toolchain-x86_64-to-{cpu}".format(
            prefix = toolchain_prefix,
            version = clang_version,
            cpu = cpu,
        )
        for cpu in BAZEL_CPU_MAP.values()
    ]
    native.register_toolchains(*toolchain_targets)
