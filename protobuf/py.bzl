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

"""python proto rules"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load("@rules_python//python:defs.bzl", "PyInfo", "py_library")
load(":protoc.bzl", "protoc_gen_sources")

def py_proto_library(
        name,
        deps,
        plugin = None,
        plugin_name = None,
        plugin_flags = [],
        **kwargs):
    """Macro to generate python source code from protobufs.

    Args:
      name: unique name for this rule
      deps: a single element list containing a `proto_library`
      plugin: an optional custom protoc plugin to execute together with
        generating the protobuf code
      plugin_name: the name used to invoke the plugin (might be different from
        the label used to identify the executable, see `plugin`)
      plugin_flags: list of string flags to pass to the plugin
      **kwargs: additional arguments to be supplied to the invocation of
        `py_library`
    """
    codegen_name = "_{}_codegen".format(name)
    codegen_target = ":{}".format(codegen_name)

    if len(deps) != 1:
        fail("can only compile a single proto at a time.")

    _generate_pb2_src(
        name = codegen_name,
        deps = deps,
        plugin = plugin,
        plugin_name = plugin_name,
        plugin_flags = plugin_flags,
    )

    py_library(
        name = name,
        srcs = [codegen_target],
        deps = [
            codegen_target,
            "@com_google_protobuf//:protobuf_python",
        ],
        **kwargs
    )

def py_grpc_library(
        name,
        srcs = [],
        deps = [],
        plugin = None,
        plugin_name = None,
        plugin_flags = [],
        **kwargs):
    """Macro to generate python source code from protobuf defined gRPC services.

    Args:
      name: unique name for this rule
      srcs: a single element list containing the `proto_library` target that
        declares the grpc service sources
      deps: a single element list containing a `py_proto_library` target
        representing the protobuf dependencies of the grpc service
      plugin: an optional custom protoc plugin to execute together with
        generating the gRPC code
      plugin_name: the name used to invoke the plugin (might be different from
        the label used to identify the executable, see `plugin`)
      plugin_flags: list of string flags to pass to the plugin
      **kwargs: additional arguments to be supplied to the invocation of
        `py_library`
    """
    codegen_grpc_name = "_{}_grpc_codegen".format(name)
    codegen_grpc_target = ":{}".format(codegen_grpc_name)

    if len(srcs) != 1:
        fail("can only compile a single proto at a time.")

    if len(deps) != 1:
        fail("deps cannot be empty")

    _generate_pb2_grpc_src(
        name = codegen_grpc_name,
        deps = srcs,
        plugin = plugin,
        plugin_name = plugin_name,
        plugin_flags = plugin_flags,
    )

    py_library(
        name = name,
        srcs = [codegen_grpc_target],
        deps = deps + [
            codegen_grpc_target,
            "@com_github_grpc_grpc//src/python/grpcio/grpc:grpcio",
        ],
        **kwargs
    )

def _protoc_gen_py_sources(ctx, fmts, grpc = False):
    generated_srcs = protoc_gen_sources(
        ctx,
        fmts,
        declare_trans = (not grpc),
    )

    workspace_name = ctx.label.workspace_name
    if not workspace_name:
        workspace_name = ctx.workspace_name

    # run-time import paths
    import_paths = ["{}/{}".format(
        workspace_name,
        ctx.label.package,
    )]

    return [
        DefaultInfo(files = depset(
            direct = generated_srcs,
            transitive = [depset(ctx.attr.deps[0][DefaultInfo].files)],
        )),
        PyInfo(
            transitive_sources = depset(generated_srcs),
            imports = depset(direct = import_paths),
        ),
    ]

_GENERATED_PROTO_PY_FMT = "{}_pb2.py"
_GENERATED_GRPC_PROTO_PY_FMT = "{}_pb2_grpc.py"

def _generate_pb2_src_impl(ctx):
    return _protoc_gen_py_sources(ctx, [_GENERATED_PROTO_PY_FMT])

_generate_pb2_src = rule(
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
            default = "python",
        ),
        "plugin_flags": attr.string_list(default = []),
        "plugin_opts": attr.string_list(default = []),
        "_protoc": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            providers = ["files_to_run"],
            executable = True,
            cfg = "host",
        ),
    },
    implementation = _generate_pb2_src_impl,
)

def _generate_pb2_grpc_src_impl(ctx):
    return _protoc_gen_py_sources(
        ctx,
        [_GENERATED_GRPC_PROTO_PY_FMT],
        grpc = True,
    )

_generate_pb2_grpc_src = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "plugin": attr.label(
            default = Label("@com_github_grpc_grpc//src/compiler:grpc_python_plugin"),
            mandatory = False,
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "plugin_name": attr.string(
            default = "grpc_python",
        ),
        "plugin_flags": attr.string_list(default = []),
        "plugin_opts": attr.string_list(default = []),
        "_protoc": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            providers = ["files_to_run"],
            executable = True,
            cfg = "host",
        ),
    },
    implementation = _generate_pb2_grpc_src_impl,
)
