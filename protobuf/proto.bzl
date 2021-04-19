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

"""enhanced proto_library"""

load(
    "@rules_proto//proto:defs.bzl",
    "ProtoInfo",
    real_proto_library = "proto_library",
)

WELL_KNOWN_PROTOS = {
    "@com_google_protobuf//:any_proto": "google/protobuf/any.proto",
    "@com_google_protobuf//:api_proto": "google/protobuf/api.proto",
    "@com_google_protobuf//:compiler_plugin_proto": "google/protobuf/compiler/plugin.proto",
    "@com_google_protobuf//:descriptor_proto": "google/protobuf/descriptor.proto",
    "@com_google_protobuf//:duration_proto": "google/protobuf/duration.proto",
    "@com_google_protobuf//:empty_proto": "google/protobuf/empty.proto",
    "@com_google_protobuf//:field_mask_proto": "google/protobuf/field_mask.proto",
    "@com_google_protobuf//:source_context_proto": "google/protobuf/source_context.proto",
    "@com_google_protobuf//:struct_proto": "google/protobuf/struct.proto",
    "@com_google_protobuf//:timestamp_proto": "google/protobuf/timestamp.proto",
    "@com_google_protobuf//:type_proto": "google/protobuf/type.proto",
    "@com_google_protobuf//:wrappers_proto": "google/protobuf/wrappers.proto",
}

ProtoMetaInfo = provider("Protobuf Metadata", fields = ["go_package_map"])

def _go_package_map(ctx):
    src_files = ctx.attr.proto_library[ProtoInfo].check_deps_sources.to_list()
    package_map = {src.short_path: ctx.attr.go_package for src in src_files}

    for dep in ctx.attr.deps:
        if ProtoMetaInfo not in dep:
            continue
        for short_path, go_pkg in dep[ProtoMetaInfo].go_package_map.items():
            if short_path not in package_map:
                package_map[short_path] = go_pkg

    return package_map

def _meta_proto_library_impl(ctx):
    go_package_map = _go_package_map(ctx)
    return [
        ctx.attr.proto_library[ProtoInfo],
        ProtoMetaInfo(
            go_package_map = go_package_map,
        ),
    ]

_meta_proto_library = rule(
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
        ),
        "deps": attr.label_list(),
        "proto_library": attr.label(
            mandatory = True,
            providers = [ProtoInfo],
        ),
        "go_package": attr.string(),
    },
    implementation = _meta_proto_library_impl,
)

def proto_library(
        name,
        srcs = [],
        deps = [],
        go_package = None,
        **kwargs):
    """Macro to generate a `proto_library` enhanced with additional metadata.

    For now, it's assumed that if this macro is used in a project, all other
    uses of `proto_library` in the same project must be of this macro.

    Args:
      name: the name of the target
      srcs: a list of proto file sources
      deps: a list of proto_library dependencies
      go_package: override any `go_package` directives specified in proto files
      **kwargs: additional arguments to be supplied to the invocation of the
        native `proto_library`
    """
    real_proto_name = "_real_{}".format(name)
    real_proto_target = ":{}".format(real_proto_name)

    real_deps = [
        dep if dep.startswith("@") else "{}:_real_{}".format(*dep.split(":"))
        for dep in deps
    ]

    # add implicit proto deps for non-proxy
    if srcs:
        real_deps += WELL_KNOWN_PROTOS.keys()

    real_proto_library(
        name = real_proto_name,
        srcs = srcs,
        deps = real_deps,
        **kwargs
    )

    _meta_proto_library(
        name = name,
        deps = deps,
        proto_library = real_proto_target,
        go_package = go_package,
    )
