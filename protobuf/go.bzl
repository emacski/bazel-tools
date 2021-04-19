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

"""go proto rules"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load(
    "@io_bazel_rules_go//go:def.bzl",
    "GoArchive",
    "GoLibrary",
    "GoSource",
    "go_context",
    "go_library",
)
load(
    "@io_bazel_rules_go//proto/wkt:well_known_types.bzl",
    "PROTO_RUNTIME_DEPS",
    "WELL_KNOWN_TYPES_APIV2",
)
load(":proto.bzl", "ProtoMetaInfo")
load(":protoc.bzl", "protoc_gen_sources", "append_codegen_suffix")

_GEN_PROTO_GO_FMT = "{}.pb.go"
_GEN_GRPC_PROTO_GO_FMT = "{}_grpc.pb.go"

def _go_proto_sources_impl(ctx):
    return _protoc_gen_go_sources(ctx, [_GEN_PROTO_GO_FMT])

def _go_grpc_sources_impl(ctx):
    return _protoc_gen_go_sources(ctx, [_GEN_GRPC_PROTO_GO_FMT])

_go_proto_sources = rule(
    attrs = {
        "protos": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [[ProtoInfo], [ProtoInfo, ProtoMetaInfo]],
        ),
        "deps": attr.label_list(
            providers = [GoArchive, GoLibrary, GoSource],
        ),
        "importpath": attr.string(),
        "plugin": attr.label(
            default = Label("@org_golang_google_protobuf//cmd/protoc-gen-go"),
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "plugin_name": attr.string(
            default = "go",
        ),
        "plugin_flags": attr.string_list(default = []),
        "plugin_opts": attr.string_list(default = []),
        "_protoc": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            providers = ["files_to_run"],
            executable = True,
            cfg = "host",
        ),
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
    implementation = _go_proto_sources_impl,
)

_go_grpc_sources = rule(
    attrs = {
        "protos": attr.label_list(
            mandatory = True,
            allow_empty = False,
            providers = [[ProtoInfo], [ProtoInfo, ProtoMetaInfo]],
        ),
        "deps": attr.label_list(
            providers = [GoArchive, GoLibrary, GoSource],
        ),
        "importpath": attr.string(),
        "plugin": attr.label(
            default = Label("@org_golang_google_grpc//cmd/protoc-gen-go-grpc"),
            executable = True,
            providers = ["files_to_run"],
            cfg = "host",
        ),
        "plugin_name": attr.string(
            default = "go-grpc",
        ),
        "plugin_flags": attr.string_list(default = []),
        "plugin_opts": attr.string_list(default = []),
        "_protoc": attr.label(
            default = Label("@com_google_protobuf//:protoc"),
            providers = ["files_to_run"],
            executable = True,
            cfg = "host",
        ),
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
    implementation = _go_grpc_sources_impl,
)

def _protoc_gen_go_sources(ctx, fmts):
    generated_srcs = protoc_gen_sources(
        ctx,
        fmts,
        proto_attr = "protos",
        declare_trans = False,
    )
    go = go_context(ctx)

    # go_library providers
    library = go.new_library(
        go,
        importpath = ctx.attr.importpath,
        srcs = generated_srcs,
        deps = ctx.attr.deps,
    )
    sources = go.library_to_source(
        go,
        attr = ctx.attr,
        library = library,
        coverage_instrumented = ctx.coverage_instrumented(),
    )
    archive = go.archive(go, sources)

    return [
        DefaultInfo(files = depset(
            direct = generated_srcs,
            transitive = [depset(ctx.attr.protos[0][DefaultInfo].files)],
        )),
        library,  # GoLibrary
        sources,  # GoSource
        archive,  # GoArchive
    ]

def go_proto_sources(**kwargs):
    """Macro to generate go sources from protobufs"""
    _go_proto_sources(**kwargs)

def go_grpc_sources(**kwargs):
    """Macro to generate go sources from protobuf defined gRPC services"""
    _go_grpc_sources(**kwargs)

def go_proto_library(
        name,
        proto = [],
        deps = [],
        importpath = None,
        plugin = None,
        plugin_name = None,
        plugin_flags = [],
        plugin_opts = [],
        **kwargs):
    """Macro for generating go library from protobufs.

    Args:
      name: unique name for this rule
      proto: a single element list containing a `proto_library`
      deps: a list of `go_library` or `go_proto_library` dependencies
      importpath: the go package import path of the resulting `go_library`
      plugin: an optional custom protoc plugin to execute together with
        generating the protobuf code
      plugin_name: the name used to invoke the plugin (might be different from
        the label used to identify the executable, see `plugin`)
      plugin_flags: list of string flags to pass to the plugin
      plugin_opts: list of string options to pass to the plugin
      **kwargs: additional arguments to be supplied to the invocation of
        `go_library`
    """
    if len(proto) != 1:
        fail("can only compile a single proto at a time.")

    codegen_name = append_codegen_suffix(name)
    codegen_target = ":{}".format(codegen_name)

    code_gen_deps = []
    for dep in deps:
        code_gen_deps.append(append_codegen_suffix(dep[1:]))

    _go_proto_sources(
        name = codegen_name,
        protos = proto,
        deps = deps,
        importpath = importpath,
        plugin = plugin,
        plugin_name = plugin_name,
        plugin_flags = plugin_flags,
        plugin_opts = plugin_opts,
    )

    go_library(
        name = name,
        srcs = [codegen_target],
        importpath = importpath,
        deps = deps + PROTO_RUNTIME_DEPS + WELL_KNOWN_TYPES_APIV2,
        **kwargs
    )

def go_grpc_library(
        name,
        srcs = [],
        deps = [],
        importpath = None,
        plugin = None,
        plugin_name = None,
        plugin_flags = [],
        plugin_opts = [],
        **kwargs):
    """Macro for generating go library from protobuf defined gRPC services.

    Args:
      name: unique name for this rule
      srcs: a single element list containing the `proto_library` target that
        declares the grpc service sources
      deps: a list of `go_library` or `go_proto_library` targets. Should contain
        the `go_proto_library` that generates protobuf dependency sources
      importpath: the go package import path of the resulting `go_library`
      plugin: an optional custom protoc plugin to execute together with
        generating the gRPC code
      plugin_name: the name used to invoke the plugin (might be different from
        the label used to identify the executable, see `plugin`)
      plugin_flags: list of string flags to pass to the plugin
      plugin_opts: list of string opts to pass to the plugin
      **kwargs: additional arguments to be supplied to the invocation of
        `go_library`
    """
    if len(srcs) != 1:
        fail("can only compile a single proto at a time.")

    if len(deps) < 1:
        fail("deps cannot be empty")

    codegen_name = append_codegen_suffix(name)
    codegen_target = ":{}".format(codegen_name)

    _go_grpc_sources(
        name = codegen_name,
        protos = srcs,
        deps = deps,
        importpath = importpath,
        plugin = plugin,
        plugin_name = plugin_name,
        plugin_flags = plugin_flags,
        plugin_opts = plugin_opts,
    )

    go_library(
        name = name,
        srcs = [codegen_target],
        importpath = importpath,
        embed = deps,
        deps = [
            "@org_golang_google_grpc//:go_default_library",
            "@org_golang_google_grpc//codes:go_default_library",
            "@org_golang_google_grpc//status:go_default_library",
            "@org_golang_x_net//context:go_default_library",
        ],
        **kwargs
    )
