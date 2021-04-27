# Copyright 2020 Erik Maciejewski
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

load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load(":cc_toolchain.bzl", "cc_cross_toolchain_bundle", "cc_current_toolchain")

package(default_visibility = ["//visibility:public"])

# build setting flag for statically linking against llvm's "libc++" or
# dynamically linking against gnu's "libstdc++"
string_flag(
    name = "use_libcpp",
    build_setting_default = "libc++",
    values = [
        "libc++",
        "libstdc++",
    ],
)

# clang 10
# generates `clang10_crosstool` label for use with legacy `--crosstool_top`
cc_cross_toolchain_bundle(
    name = "clang10",
    clang_version = "10.0.0",
    target_libcpp = ":use_libcpp",
)

# clang 11
# generates `clang11_crosstool` label for use with legacy `--crosstool_top`
cc_cross_toolchain_bundle(
    name = "clang11",
    clang_version = "11.0.1",
    target_libcpp = ":use_libcpp",
)

# toolchain target to provide make variables for genrules for cross-compilation
# with values from the current cc cross toolchain
cc_current_toolchain(name = "current_cc_toolchain")
