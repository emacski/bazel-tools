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

"""protobuf proto rule helpers"""
load("@rules_proto//proto:defs.bzl", "ProtoInfo")

_PROTO_EXTENSION = ".proto"
_VIRTUAL_IMPORTS = "/_virtual_imports/"


def _is_in_virtual_imports(source_file, virtual_folder = _VIRTUAL_IMPORTS):
    return not source_file.is_source and virtual_folder in source_file.path


def _staged_proto(ctx, proto):
    if proto.dirname == ctx.label.package or _is_in_virtual_imports(proto) \
        or proto.dirname.startswith("external"):
        return proto
    # copy proto source to package of the lang_proto_library rule if source is
    # in another project package
    copied_proto = ctx.actions.declare_file(proto.basename)
    ctx.actions.run_shell(
        inputs = [proto],
        outputs = [copied_proto],
        command = "cp {} {}".format(proto.path, copied_proto.path),
        mnemonic = "CopySourceProto",
    )
    return copied_proto


def protos_from_context(ctx):
    """get protos, including dependency protos, from context

    Args:
        ctx: rule context
    Returns:
        list of proto `File`s (sources), list of proto `File`s (dependencies)
    """
    dep = ctx.attr.deps[0]  # currently, only one "dep" is ever allowed here
    protos = [_staged_proto(ctx, proto) for proto
                in dep[ProtoInfo].check_deps_sources.to_list()]
    includes = dep[ProtoInfo].transitive_imports.to_list()
    return protos, includes


def declare_out_files(ctx, protos, out_file_format):
    """derive and declare output files from protos

    Args:
        ctx: rule context
        protos: list of proto `File`s
        out_file_format: starlark format string
    Returns:
        list of declared files
    """
    declared_files = []
    for proto in protos:
        path = proto.basename
        if not proto.path.endswith(_PROTO_EXTENSION):
             fail('"{}" does not end with "{}"'.format(proto.path, _PROTO_EXTENSION))
        if _is_in_virtual_imports(proto):
            # infer desired package hierarchy from the virtual path accounting
            # for the computed path from `import_prefix` and
            # `strip_import_prefix` of proto_library
            path = proto.path[proto.path.index(_VIRTUAL_IMPORTS) + 1:]
            # everything after _virtual_imports/[proto_library_rule_name]
            path = path.split("/", 2)[2]
        elif proto.path.startswith("external"):
            # everything after external/[repository_name]
            path = proto.path.split("/", 2)[2]
        out_file = out_file_format.format(path[:-len(_PROTO_EXTENSION)])
        declared_files.append(ctx.actions.declare_file(out_file))
    return declared_files


def get_protoc_plugin_args(plugin, flags, dir_out, gen_mocks, plugin_name):
    """returns arguments configuring protoc to use a plugin for a language

    Args:
      plugin: An executable file to run as the protoc plugin.
      flags: The plugin flags to be passed to protoc.
      dir_out: The output directory for the plugin.
      gen_mocks: A bool indicating whether to generate mocks.
      plugin_name: A name of the plugin, it is required to be unique when there
      are more than one plugin used in a single protoc command.
    Returns:
      list of protoc arguments configuring the plugin.
    """
    augmented_flags = list(flags)
    if gen_mocks:
        augmented_flags.append("generate_mock_code=true")

    augmented_dir_out = dir_out
    if augmented_flags:
        augmented_dir_out = ",".join(augmented_flags) + ":" + dir_out

    return [
        "--plugin=protoc-gen-{plugin_name}={plugin_path}".format(
            plugin_name=plugin_name,
            plugin_path=plugin.path,
        ),
        "--{plugin_name}_out={dir_out}".format(
            plugin_name=plugin_name,
            dir_out=augmented_dir_out,
        ),
    ]


def get_protoc_out_dir(ctx):
    """compute value for --python_out= protoc argument

    Args:
        ctx: rule context
    Returns:
        output directory for protoc (string)
    """
    out_path_parts = [ctx.genfiles_dir.path]
    # handle workspace_root like 'external/[repo]'
    if ctx.label.workspace_root:
        out_path_parts.append(ctx.label.workspace_root)
    out_path_parts.append(ctx.label.package)
    return "/".join(out_path_parts)


def get_protoc_include_dir(proto_file):
    """get include directory of protofile

    Args:
        proto_file: a proto `File`
    Returns:
        include directory path (string)
    """
    directory = proto_file.path
    prefix_len = 0

    if _is_in_virtual_imports(proto_file):
        root, relative = proto_file.path.split(_VIRTUAL_IMPORTS, 2)
        # strip package path off the end since this is an "include" path
        result = root + _VIRTUAL_IMPORTS + relative.split("/", 1)[0]
        return result

    if not proto_file.is_source and directory.startswith(proto_file.root.path):
        prefix_len = len(proto_file.root.path) + 1

    if directory.startswith("external", prefix_len):
        external_separator = directory.find("/", prefix_len)
        repository_separator = directory.find("/", external_separator + 1)
        return directory[:repository_separator]
    else:
        return proto_file.root.path if proto_file.root.path else "."


def get_protoc_proto_paths(protos, arg_prefix="--proto_path="):
    """get `proto_path` arguments for protoc

    Args:
        protos: `File`s representing included protos
        arg_prefix: the protoc argument prefix for proto_path
    Returns:
        List of string proto_path arguments for protoc
    """
    proto_path_args = {}
    for proto in protos:
        proto_path_args[arg_prefix + get_protoc_include_dir(proto)] = None
    return list(proto_path_args.keys())


def get_protoc_compile_targets(protos, genfiles_dir_path):
    """return list of protoc args specifying which protos to compile

    Args:
        protos: list of proto `File`s
        genfiles_dir_path: genfiles directory (string)
    Returns:
        list of proto file paths
    """
    args = []
    for proto in protos:
        strip_prefix_len = 0
        if not _is_in_virtual_imports(proto) and \
            proto.path.startswith(genfiles_dir_path):
            strip_prefix_len = len(genfiles_dir_path) + 1
        args.append(proto.path[strip_prefix_len:])
    return args
