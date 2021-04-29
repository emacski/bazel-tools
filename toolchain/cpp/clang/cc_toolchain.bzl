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

"""Clang cross-compile toolchain rules."""

load("@rules_cc//cc:defs.bzl", "cc_toolchain", "cc_toolchain_suite")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(":cc_toolchain_config.bzl", "cc_toolchain_config")
load(":defs.bzl", "BAZEL_CPU_MAP")

def _cross_build_cc_flags(ctx, cc_toolchain):
    """Returns a string of cross-build compiler flags."""
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    flags_from_features = [
        flag
        for sublist in [cc_common.get_memory_inefficient_command_line(
            feature_configuration = feature_configuration,
            action_name = action_name,
            variables = cc_common.create_compile_variables(
                feature_configuration = feature_configuration,
                cc_toolchain = cc_toolchain,
            ),
        ) for action_name in (
            ACTION_NAMES.cpp_compile,
            ACTION_NAMES.cpp_link_executable,
        )]
        for flag in sublist
    ]
    filter_flag_prefixes = ["--target", "--sysroot", "-O", "-march", "-mfpu",
                            "-mcpu", "-mavx", "-msse", "-fuse-ld", "-rtlib"]
    # add --copts and --linkopts from commandline
    cli_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.linkopts
    all_flags = flags_from_features + cli_flags
    filtered_flags = []
    for prefix in filter_flag_prefixes:
        filtered_flag = None
        for flag in all_flags:
            if flag.startswith(prefix):
                filtered_flag = flag
        if filtered_flag:
            filtered_flags.append(filtered_flag)
            filtered_flag = None

    return " ".join(filtered_flags)

def _cc_current_toolchain(ctx):
    """Provide just enough information so a genrule can cross build"""
    cc_toolchain = find_cpp_toolchain(ctx)
    cc_flags = _cross_build_cc_flags(ctx, cc_toolchain)

    return [cc_toolchain, platform_common.TemplateVariableInfo({
        "CC": cc_toolchain.compiler_executable,
        "CC_FLAGS": cc_flags,
        "TARGET_GNU_SYSTEM_NAME": cc_toolchain.target_gnu_system_name,
        "SYSROOT": cc_toolchain.sysroot,
    })]

cc_current_toolchain = rule(
    implementation = _cc_current_toolchain,
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    fragments = ["cpp"],
)

def cc_cross_toolchain(
        name,
        clang_version,
        target_cpu,
        target_libcpp):
    """Macro for defining cross compile toolchains

    Args:
        name: cc_toolchain rule name
        clang_version: llvm / clang version
        target_cpu: target cpu ("arm", "aarch64", "x86_64")
        target_libcpp: target libc++ ("libc++" or "libstdc++")
    """
    empty = name + "_empty"

    native.filegroup(
        name = empty,
        srcs = [],
    )

    cc_toolchain_config(
        name = name + "_config",
        clang_version = clang_version,
        target_cpu = target_cpu,
        target_libcpp = target_libcpp,
        visibility = None,
    )

    cc_toolchain(
        name = name,
        all_files = empty,
        compiler_files = empty,
        dwp_files = empty,
        linker_files = empty,
        objcopy_files = empty,
        strip_files = empty,
        supports_param_files = 1,
        toolchain_config = name + "_config",
    )

def cc_cross_toolchain_bundle(
        name,
        clang_version,
        target_libcpp):
    """Macro for defining all toolchain rules required for a given `clang_version`

    Args:
        name: used as a prefix for all generated rules
        clang_version: llvm / clang version
        target_libcpp: target libc++ ("libc++" or "libstdc++")
    """
    legacy_toolchain_map = {}

    for bzl_cpu, cpu in BAZEL_CPU_MAP.items():
        compiler_name = name + "-compiler-x86_64-to-" + cpu
        toolchain_name = name + "-toolchain-x86_64-to-" + cpu

        cc_cross_toolchain(
            name = compiler_name,
            clang_version = clang_version,
            target_cpu = bzl_cpu,
            target_libcpp = target_libcpp,
        )

        native.toolchain(
            name = toolchain_name,
            exec_compatible_with = [
                "@platforms//os:linux",
                "@platforms//cpu:x86_64",
            ],
            target_compatible_with = [
                "@platforms//os:linux",
                "@platforms//cpu:" + cpu,
            ],
            toolchain = compiler_name,
            toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        )

        legacy_toolchain_map[bzl_cpu] = compiler_name
        legacy_toolchain_map[bzl_cpu + "|clang"] = compiler_name

    # legacy toolchain resolution support
    cc_toolchain_suite(
        name = name + "_crosstool",
        toolchains = legacy_toolchain_map,
    )
