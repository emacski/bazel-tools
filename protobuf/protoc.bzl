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

"""protoc"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load(":proto.bzl", "ProtoMetaInfo", "WELL_KNOWN_PROTOS")

_PROTO_EXTENSION = ".proto"
_VIRTUAL_IMPORTS = "/_virtual_imports/"
_BUILTINS_PLUGIN = "protoc"

def _is_well_known_proto(proto_file):
    for wkp in WELL_KNOWN_PROTOS.values():
        if proto_file.short_path.endswith(wkp):
            return True
    return False

def _is_virtual_import(source_file, virtual_folder = _VIRTUAL_IMPORTS):
    return not source_file.is_source and virtual_folder in source_file.path

def _virtual_import_short_path(proto_file):
    """resolve `short_path` relative to the virtual prefix"""
    short_path = proto_file.short_path
    if _is_virtual_import(proto_file):
        short_path = proto_file.path[proto_file.path.index(_VIRTUAL_IMPORTS) + 1:]

        # everything after [_VIRTUAL_IMPORTS]/[proto_library_rule_name]
        short_path = short_path.split("/", 2)[2]
    return short_path

def sources_from_proto_target(proto_target):
    """get protos sources (direct, and transitive) from target

    Args:
        proto_target: the `Target` proto
    Returns:
        list of proto `File`s (direct), list of proto `File`s (transitive)
    """
    srcs = [
        proto
        for proto in proto_target[ProtoInfo].check_deps_sources.to_list()
    ]
    srcs_trans = [
        proto
        for proto in proto_target[ProtoInfo].transitive_imports.to_list()
        if proto not in srcs
    ]
    return srcs, srcs_trans

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
        if _is_well_known_proto(proto):
            continue
        path = proto.basename
        if not proto.path.endswith(_PROTO_EXTENSION):
            fail('"{}" does not end with "{}"'.format(proto.path, _PROTO_EXTENSION))
        if _is_virtual_import(proto):
            # infer desired package hierarchy from the virtual path accounting
            # for the computed path from `import_prefix` and
            # `strip_import_prefix` of proto_library
            path = _virtual_import_short_path(proto)
        elif proto.path.startswith("external"):
            # everything after external/[repository_name]
            path = proto.path.split("/", 2)[2]
        out_file = out_file_format.format(path[:-len(_PROTO_EXTENSION)])
        declared_files.append(ctx.actions.declare_file(out_file))
    return declared_files

def get_protoc_plugin_args(plugin, name, flags, opts, dir_out):
    """returns arguments configuring protoc to use a plugin for a language

    Args:
      plugin: An executable file to run as the protoc plugin.
      name: The plugin name to be use by protoc
      flags: The plugin flags to be passed to protoc.
      opts: The plugin options
      dir_out: The output directory for the plugin.
    Returns:
      list of protoc arguments configuring the plugin.
    """
    args = []

    # use specified generator (not a builtin)
    if plugin.basename != _BUILTINS_PLUGIN:
        args.append("--plugin=protoc-gen-{plugin_name}={plugin_path}".format(
            plugin_name = name,
            plugin_path = plugin.path,
        ))

    # plugin flags are prepended to the out dir
    plugin_flags = ",".join(list(flags))
    out = "{}:{}".format(plugin_flags, dir_out) if plugin_flags else dir_out

    args.append("--{plugin_name}_out={out_arg}".format(
        plugin_name = name,
        out_arg = out,
    ))

    # plugin opts
    args += [
        "--{plugin_name}_opt={opt_arg}".format(
            plugin_name = name,
            opt_arg = opt,
        )
        for opt in list(opts)
    ]

    return args

def get_protoc_out_dir(ctx):
    """compute protoc output directory

    Args:
        ctx: rule context
    Returns:
        output directory for protoc (string)
    """
    out_path_parts = [ctx.bin_dir.path]

    # handle workspace_root like 'external/[repo]'
    if ctx.label.workspace_root:
        out_path_parts.append(ctx.label.workspace_root)
    out_path_parts.append(ctx.label.package)
    return "/".join(out_path_parts)

def get_protoc_include_dir(proto_file):
    """get include directory of proto_file

    Args:
        proto_file: a proto `File`
    Returns:
        include directory path (string)
    """
    directory = proto_file.path
    prefix_len = 0

    if _is_virtual_import(proto_file):
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

def get_protoc_proto_paths(protos, arg_prefix = "--proto_path="):
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

def get_protoc_compile_targets(protos, bin_dir_path):
    """return list of protoc args specifying which protos to compile

    Args:
        protos: list of proto `File`s
        bin_dir_path: bin directory (string)
    Returns:
        list of proto file paths
    """
    args = []
    for proto in protos:
        strip_prefix_len = 0
        if not _is_virtual_import(proto) and \
           proto.path.startswith(bin_dir_path):
            strip_prefix_len = len(bin_dir_path) + 1
        args.append(proto.path[strip_prefix_len:])
    return args

def get_go_pkg_map_opts(proto_target, protos):
    """generate go plugin import options from ProtoMetaInfo.go_package_map

    Args:
        proto_target: `Target` proto
        protos: list of proto `File`s
    Returns:
        remmaped lists of direct and transitive `File`s
    """
    go_package_map = proto_target[ProtoMetaInfo].go_package_map
    go_pkg_plugin_opts = ["paths=source_relative"]

    for proto in protos:
        if proto.short_path not in go_package_map.keys():
            continue
        proto_path = _virtual_import_short_path(proto)
        go_import = go_package_map[proto.short_path]

        # pkg is the last element for the fully qualified go_package
        pkg = go_import.split("/")[-1]
        go_pkg_plugin_opts.append("M{}={};{}".format(proto_path, go_import, pkg))

    return go_pkg_plugin_opts

def remap_go_srcs_by_pkg(proto_target, protos, includes, importpath):
    """map any transitive sources in the same `importpath` as direct sources

    Args:
        proto_target: `Target` proto
        protos: list of proto `File`s
        includes: list of proto `File`s
        importpath: go package importpath string
    Returns:
        remmaped lists of direct and transitive `File`s
    """
    go_package_map = proto_target[ProtoMetaInfo].go_package_map

    importpath_src_lookup = [
        short_path
        for short_path, go_pkg in go_package_map.items()
        if go_pkg == importpath
    ]

    remapped_sources = protos
    remapped_includes = []

    for proto in includes:
        if proto.short_path in importpath_src_lookup:
            remapped_sources.append(proto)
        else:
            remapped_includes.append(proto)

    return remapped_sources, remapped_includes

def protoc_gen_sources(
        ctx,
        gen_fmts,
        proto_attr = "deps",
        declare_trans = True):
    """execute protoc compiler

    Args:
        ctx: rule context
        gen_fmts: format templates for generated files
        proto_attr: name of the ctx.attr for the protos (normally "deps")
        declare_trans: whether or not to declare transitive sources as outputs
    Returns:
        generated sources
    """
    proto_target = getattr(ctx.attr, proto_attr)[0]  # for now, there's only one

    protos, includes = sources_from_proto_target(proto_target)

    # code generator plugin
    tools = [
        plugin
        for plugin in [ctx.executable.plugin]
        if ctx.attr.plugin != ctx.attr._protoc
    ]

    plugin_opts = list(ctx.attr.plugin_opts)

    # go plugin opts
    if ctx.attr.plugin_name.startswith("go"):
        plugin_opts += get_go_pkg_map_opts(proto_target, protos + includes)

        # only remap sources for `go` not `go-grpc`
        if ctx.attr.plugin_name == "go":
            protos, includes = remap_go_srcs_by_pkg(
                proto_target,
                protos,
                includes,
                ctx.attr.importpath,
            )

    out_dir = get_protoc_out_dir(ctx)

    exec_args = get_protoc_plugin_args(
        ctx.executable.plugin,
        ctx.attr.plugin_name,
        ctx.attr.plugin_flags,
        plugin_opts,
        out_dir,
    )

    # proto include paths
    exec_args += get_protoc_proto_paths(protos + includes) + [
        "--proto_path={}".format(path)
        for path in (ctx.bin_dir.path, out_dir)
    ]

    # protos to compile
    exec_args += get_protoc_compile_targets(protos + includes, ctx.bin_dir.path)

    # outputs
    declared_outputs = []
    for fmt in gen_fmts:
        declared_outputs += declare_out_files(ctx, protos, fmt)
    if declare_trans:
        for fmt in gen_fmts:
            declared_outputs += declare_out_files(ctx, includes, fmt)

    ctx.actions.run(
        inputs = protos + includes,
        tools = tools,
        outputs = declared_outputs,
        executable = ctx.executable._protoc,
        arguments = exec_args,
        mnemonic = "ProtocInvocation",
    )

    return declared_outputs
