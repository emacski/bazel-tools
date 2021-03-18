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

"""cc proto rules"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load("@rules_cc//cc:defs.bzl", "cc_library")
load(":protoc.bzl", "protoc_gen_sources")

def cc_proto_library(
        name,
        deps = [],
        plugin = None,
        plugin_name = None,
        plugin_flags = None,
        **kwargs):
    """Macro to generate c++ source code from protobufs.

    Args:
      name: unique name for this rule
      deps: a single element list containing a `proto_library`
      plugin: an optional custom protoc plugin to execute together with
        generating the gRPC code
      plugin_name: the name used to invoke the plugin (might be different from
        the label used to identify the executable, see `plugin`)
      plugin_flags: list of string flags to pass to the plugin
      **kwargs: additional arguments to be supplied to the invocation of
        `cc_library`
    """
    codegen_name = "_{}_codegen".format(name)
    codegen_target = ":{}".format(codegen_name)

    if len(deps) != 1:
        fail("deps cannot be empty")

    _generate_pb_src(
        name = codegen_name,
        deps = deps,
        plugin = plugin,
        plugin_name = plugin_name,
        plugin_flags = plugin_flags,
    )

    cc_library(
        name = name,
        srcs = [codegen_target],
        hdrs = [codegen_target],
        deps = [
            codegen_target,
            "@com_google_protobuf//:protobuf",
        ],
        **kwargs
    )

def cc_grpc_library(
        name,
        srcs = [],
        deps = [],
        plugin = None,
        plugin_name = None,
        plugin_flags = None,
        **kwargs):
    """Macro to generate c++ source code from protobuf defined gRPC services.

    Args:
      name: unique name for this rule
      srcs: a single element list containing the `proto_library` target that
        declares the grpc service sources
      deps: a single element list containing a `cc_proto_library` target
        representing the protobuf dependencies of the grpc service
      plugin: an optional custom protoc plugin to execute together with
        generating the gRPC code
      plugin_name: the name used to invoke the plugin (might be different from
        the label used to identify the executable, see `plugin`)
      plugin_flags: list of string flags to pass to the plugin
      **kwargs: additional arguments to be supplied to the invocation of
        `cc_library`
    """
    codegen_grpc_name = "_{}_grpc_codegen".format(name)
    codegen_grpc_target = ":{}".format(codegen_grpc_name)

    if len(srcs) != 1:
        fail("Can only compile a single proto at a time.")

    if len(deps) != 1:
        fail("deps cannot be empty")

    _generate_pb_grpc_src(
        name = codegen_grpc_name,
        deps = srcs,
        plugin = plugin,
        plugin_name = plugin_name,
        plugin_flags = plugin_flags,
    )

    cc_library(
        name = name,
        srcs = [codegen_grpc_target],
        hdrs = [codegen_grpc_target],
        deps = deps + [
            "@com_github_grpc_grpc//:grpc++",
            "@com_github_grpc_grpc//:grpc++_codegen_proto",
        ],
        **kwargs
    )

def _protoc_gen_cc_sources(ctx, fmts, grpc = False):
    generated_srcs = protoc_gen_sources(
        ctx,
        fmts,
        declare_trans = (not grpc),
    )

    workspace_package = ctx.label.package
    if ctx.label.workspace_root:
        # external repo include
        workspace_package = "{}/{}".format(
            ctx.label.workspace_root,
            ctx.label.package,
        )

    # compile-time include dirs
    include_dirs = ["{}/{}".format(
        ctx.bin_dir.path,
        workspace_package,
    )]

    return [
        DefaultInfo(files = depset(
            direct = generated_srcs,
            transitive = [depset(ctx.attr.deps[0][DefaultInfo].files)],
        )),
        CcInfo(compilation_context = cc_common.create_compilation_context(
            headers = depset(generated_srcs),
            includes = depset(include_dirs),
        )),
    ]

_PROTO_HDR_FMT = "{}.pb.h"
_PROTO_SRC_FMT = "{}.pb.cc"
_GRPC_PROTO_HDR_FMT = "{}.grpc.pb.h"
_GRPC_PROTO_SRC_FMT = "{}.grpc.pb.cc"

def _generate_pb_src_impl(ctx):
    return _protoc_gen_cc_sources(ctx, [
        _PROTO_HDR_FMT,
        _PROTO_SRC_FMT,
    ])

_generate_pb_src = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "plugin": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "plugin_name": attr.string(
            default = "cpp",
        ),
        "plugin_flags": attr.string_list(default = []),
        "plugin_opts": attr.string_list(default = []),
        "_protoc": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
    },
    implementation = _generate_pb_src_impl,
)

def _generate_pb_grpc_src_impl(ctx):
    return _protoc_gen_cc_sources(ctx, [
        _GRPC_PROTO_HDR_FMT,
        _GRPC_PROTO_SRC_FMT,
    ], grpc = True)

_generate_pb_grpc_src = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "plugin": attr.label(
            default = Label("@com_github_grpc_grpc//src/compiler:grpc_cpp_plugin"),
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "plugin_name": attr.string(
            default = "grpc",
        ),
        "plugin_flags": attr.string_list(default = []),
        "plugin_opts": attr.string_list(default = []),
        "_protoc": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
    },
    implementation = _generate_pb_grpc_src_impl,
)
