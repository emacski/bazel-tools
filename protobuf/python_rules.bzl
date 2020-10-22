# Copyright 2020 gRPC authors
#
# Modifications Copyright 2020 Erik Maciejewski
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
load(
    ":protobuf.bzl",
    "protos_from_context",
    "declare_out_files",
    "get_protoc_out_dir",
    "get_protoc_proto_paths",
    "get_protoc_compile_targets",
    "get_protoc_plugin_args",
)


_GENERATED_PROTO_FORMAT = "{}_pb2.py"
_GENERATED_GRPC_PROTO_FORMAT = "{}_pb2_grpc.py"


def _generate_py_impl(ctx):
    protos, includes = protos_from_context(ctx)

    out_dir = get_protoc_out_dir(ctx)
    out_files = declare_out_files(ctx, protos, _GENERATED_PROTO_FORMAT)
    tools = [ctx.executable._protoc]

    exec_args = []
    if ctx.attr.plugin:
        exec_args += get_protoc_plugin_args(
            ctx.executable.plugin,
            [],
            out_dir,
            False,
            ctx.attr.plugin.label.name,
        )
        tools.append(ctx.executable.plugin)
    exec_args += [
        "--python_out={}".format(out_dir),
    ] + get_protoc_proto_paths(includes) + [
        "--proto_path={}".format(ctx.genfiles_dir.path),
    ] + get_protoc_compile_targets(protos, ctx.genfiles_dir.path)

    imports = ["{}/{}".format(ctx.workspace_name, ctx.label.package)]
    ctx.actions.run(
        inputs = protos + includes,
        tools = tools,
        outputs = out_files,
        executable = ctx.executable._protoc,
        arguments = exec_args,
        mnemonic = "ProtocInvocation",
    )

    return [
        DefaultInfo(files = depset(direct = out_files)),
        PyInfo(
            transitive_sources = depset(),
            imports = depset(direct = imports),
        ),
    ]


def _generate_pb2_grpc_src_impl(ctx):
    protos, includes = protos_from_context(ctx)

    out_dir = get_protoc_out_dir(ctx)
    out_files = declare_out_files(ctx, protos, _GENERATED_GRPC_PROTO_FORMAT)
    tools = [ctx.executable._protoc, ctx.executable._grpc_plugin]
    plugin_flags = ["grpc_2_0"] + ctx.attr.strip_prefixes

    exec_args = get_protoc_plugin_args(
        ctx.executable._grpc_plugin,
        plugin_flags,
        out_dir,
        False,
        "grpc_python",
    )

    if ctx.attr.plugin:
        exec_args += get_protoc_plugin_args(
            ctx.executable.plugin,
            [],
            out_dir,
            False,
            ctx.attr.plugin.label.name,
        )
        tools.append(ctx.executable.plugin)

    exec_args += get_protoc_proto_paths(includes) + [
        "--proto_path={}".format(ctx.genfiles_dir.path)
    ] + get_protoc_compile_targets(protos, ctx.genfiles_dir.path)

    ctx.actions.run(
        inputs = protos + includes,
        tools = tools,
        outputs = out_files,
        executable = ctx.executable._protoc,
        arguments = exec_args,
        mnemonic = "ProtocInvocation",
    )

    return [
        DefaultInfo(files = depset(direct = out_files)),
        PyInfo(
            transitive_sources = depset(),
            # Imports are already configured by the generated py impl
            imports = depset(),
        ),
    ]


_generate_pb2_src = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "plugin": attr.label(
            mandatory = False,
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "_protoc": attr.label(
            default = Label("//external:protocol_compiler"),
            providers = ["files_to_run"],
            executable = True,
            cfg = "host",
        ),
    },
    implementation = _generate_py_impl,
)


_generate_pb2_grpc_src = rule(
    attrs = {
        "deps": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [ProtoInfo],
        ),
        "strip_prefixes": attr.string_list(),
        "plugin": attr.label(
            mandatory = False,
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "_grpc_plugin": attr.label(
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
            default = Label("@com_github_grpc_grpc//src/compiler:grpc_python_plugin"),
        ),
        "_protoc": attr.label(
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
            default = Label("//external:protocol_compiler"),
        ),
    },
    implementation = _generate_pb2_grpc_src_impl,
)


def py_proto_library(
        name,
        deps,
        plugin = None,
        **kwargs):
    """Generate python code for a protobuf.

    Args:
      name: The name of the target.
      deps: A list of proto_library dependencies. Must contain a single element.
      plugin: An optional custom protoc plugin to execute together with
        generating the protobuf code.
      **kwargs: Additional arguments to be supplied to the invocation of
        py_library.
    """
    codegen_target = "_{}_codegen".format(name)
    if len(deps) != 1:
        fail("Can only compile a single proto at a time.")

    _generate_pb2_src(
        name = codegen_target,
        deps = deps,
        plugin = plugin,
    )

    py_library(
        name = name,
        srcs = [":{}".format(codegen_target)],
        deps = [
            "@com_google_protobuf//:protobuf_python",
            ":{}".format(codegen_target),
        ],
        **kwargs
    )


def py_grpc_library(
        name,
        srcs,
        deps,
        plugin = None,
        strip_prefixes = [],
        **kwargs):
    """Generate python code for gRPC services defined in a protobuf.

    Args:
      name: The name of the target.
      srcs: (List of `labels`) a single proto_library target containing the
        schema of the service.
      deps: (List of `labels`) a single py_proto_library target for the
        proto_library in `srcs`.
      strip_prefixes: (List of `strings`) If provided, this prefix will be
        stripped from the beginning of foo_pb2 modules imported by the
        generated stubs. This is useful in combination with the `imports`
        attribute of the `py_library` rule.
      plugin: An optional custom protoc plugin to execute together with
        generating the gRPC code.
      **kwargs: Additional arguments to be supplied to the invocation of
        py_library.
    """
    codegen_grpc_target = "_{}_grpc_codegen".format(name)
    if len(srcs) != 1:
        fail("Can only compile a single proto at a time.")

    if len(deps) != 1:
        fail("deps cannot be empty")

    _generate_pb2_grpc_src(
        name = codegen_grpc_target,
        deps = srcs,
        strip_prefixes = strip_prefixes,
        plugin = plugin,
    )

    py_library(
        name = name,
        srcs = [":{}".format(codegen_grpc_target)],
        deps = [
            Label("@com_github_grpc_grpc//src/python/grpcio/grpc:grpcio"),
        ] + deps + [
            ":{}".format(codegen_grpc_target),
        ],
        **kwargs
    )
