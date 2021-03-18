# Protocol Buffer Tools

* [Protobuf](#Protobuf)
    * [ProtoMetaInfo](#ProtoMetaInfo)
    * [proto_library](#proto_library)
* [C++](#C++)
    * [cc_proto_library](#cc_proto_library)
    * [cc_grpc_library](#cc_grpc_library)
* [Python](#Python)
    * [py_proto_library](#py_proto_library)
    * [py_grpc_library](#py_grpc_library)
* [Go](#Go)
    * [go_proto_library](#go_proto_library)
    * [go_grpc_library](#go_grpc_library)

## Protobuf

`WORKSPACE` example
```
http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-0.0.1",
    urls = ["https://github.com/emacski/bazel-tools/archive/0.0.1.tar.gz"],
)
```

**`@com_github_emacski_bazeltools//protobuf:proto.bzl`**

### `ProtoMetaInfo`
A Provider for encapsulating protobuf metadata

| Attribute | Description |
|-----------|-------------|
| `go_package_map` | `dict`<br/> mapping of proto file to go package |

### `proto_library`
An enhanced `proto_library` rule extended to model protobuf compiler plugin
directives. Can still be used with rules depending on the `ProtoInfo` provider.

**NOTE:** For now, if this macro is used in a project, all other uses of
`proto_library` in the same project must be of this macro.
```
proto_library(name, srcs, deps, go_package)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>Unique name for this rule. |
| `srcs` | `Label List, required`<br/>a single proto_library target containing the schema of the service. |
| `deps` | `Label List, required`<br/>a single py_proto_library target for the proto_library in `srcs`. |
| `go_package` | `string, optional`<br/>specify the go package, overriding any go_package defined in the proto file |

## C++

`WORKSPACE` example
```
http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-0.0.1",
    urls = ["https://github.com/emacski/bazel-tools/archive/0.0.1.tar.gz"],
)

http_archive(
    name = "com_github_grpc_grpc",
    sha256 = "bb6de0544adddd54662ba1c314eff974e84c955c39204a4a2b733ccd990354b7",
    strip_prefix = "grpc-1.36.3",
    urls = ["https://github.com/grpc/grpc/archive/v1.36.3.tar.gz"],
)

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()
```

**`@com_github_emacski_bazeltools//protobuf:cc.bzl`**

### `cc_proto_library`
C++ protobuf library rule that can handle `proto_library` "proxy" type definitions
```
cc_proto_library(name, deps, plugin, plugin_name, plugin_flags, plugin_opts)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>Unique name for this rule. |
| `deps` | `Label List, required`<br/>A list containing a single `proto_library` target (can be a proxy) |
| `plugin` | `string, optional.`<br/>An optional custom protoc plugin to execute together with generating the protobuf code. |
| `plugin_name` | `string, optional.`<br/>the name used to invoke the plugin from the compiler |
| `plugin_flags` | `string List, optional.`<br/>list of string flags to pass to the plugin |


### `cc_grpc_library`
C++ grpc library rule that can handle `proto_library` "proxy" type definitions
```
cc_grpc_library(name, srcs, deps, plugin, plugin_name, plugin_flags, plugin_opts)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>unique name for this rule |
| `srcs` | `Label List, required`<br/>a single element list containing the `proto_library` target that declares the grpc service sources |
| `deps` | `Label List, required`<br/>a single element list containing a `cc_proto_library` target representing the protobuf dependencies of the grpc service |
| `plugin` | `string, optional.`<br/>an optional custom protoc plugin to execute together with generating the protobuf code |
| `plugin_name` | `string, optional.`<br/>the name used to invoke the plugin from the compiler |
| `plugin_flags` | `string List, optional.`<br/>list of string flags to pass to the plugin |

## Python

`WORKSPACE` example
```
http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-0.0.1",
    urls = ["https://github.com/emacski/bazel-tools/archive/0.0.1.tar.gz"],
)

http_archive(
    name = "rules_python",
    sha256 = "afe33d4a8091452cb785108f237c7f3dcef56345952aad124954a96d89c4aab6",
    strip_prefix = "rules_python-0d23d579fd93b72fe94b27b0077fbf3dc8680724",
    urls = ["https://github.com/bazelbuild/rules_python/archive/0d23d579fd93b72fe94b27b0077fbf3dc8680724.tar.gz"],
)

load("@rules_python//python:repositories.bzl", "py_repositories")

py_repositories()

load("@rules_python//python:pip.bzl", "pip_repositories")

pip_repositories()

http_archive(
    name = "com_github_grpc_grpc",
    sha256 = "bb6de0544adddd54662ba1c314eff974e84c955c39204a4a2b733ccd990354b7",
    strip_prefix = "grpc-1.36.3",
    urls = ["https://github.com/grpc/grpc/archive/v1.36.3.tar.gz"],
)

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()
```

**`@com_github_emacski_bazeltools//protobuf:py.bzl`**

### `py_proto_library`
Python protobuf library rule that can handle `proto_library` "proxy" type definitions
```
py_proto_library(name, deps, plugin, plugin_name, plugin_flags, plugin_opts)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>unique name for this rule |
| `deps` | `proto_library, required.`<br/>a single element list containing a `proto_library` |
| `plugin` | `string, optional.`<br/>an optional custom protoc plugin to execute together with generating the protobuf code |
| `plugin_name` | `string, optional.`<br/>the name used to invoke the plugin from the compiler |
| `plugin_flags` | `string List, optional.`<br/>list of string flags to pass to the plugin |

### `py_grpc_library`
Python grpc library rule that can handle `proto_library` "proxy" type definitions
```
py_grpc_library(name, srcs, deps, plugin, plugin, plugin_name, plugin_flags, strip_prefixes)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>unique name for this rule |
| `srcs` | `Label List, required`<br/>a single element list containing the `proto_library` target that declares the grpc service sources |
| `deps` | `Label List, required`<br/>a single element list containing a `py_proto_library` target representing the protobuf dependencies of the grpc service |
| `plugin` | `String, optional`<br/>An optional custom protoc plugin to execute together with generating the gRPC code. |
| `plugin_name` | `string, optional.`<br/>the name used to invoke the plugin from the compiler |
| `plugin_flags` | `string List, optional.`<br/>list of string flags to pass to the plugin |
| `strip_prefixes` | `string List, optional`<br/>if provided, this prefix will be stripped from the beginning of foo_pb2 modules imported by the generated stubs. This is useful in combination with the `imports` attribute of the `py_library` rule |

## Go

`WORKSPACE` example
```
http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-0.0.1",
    urls = ["https://github.com/emacski/bazel-tools/archive/0.0.1.tar.gz"],
)

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "7904dbecbaffd068651916dce77ff3437679f9d20e1a7956bff43826e7645fcc",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.25.1/rules_go-v0.25.1.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.25.1/rules_go-v0.25.1.tar.gz",
    ],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "222e49f034ca7a1d1231422cdb67066b885819885c356673cb1f72f748a3c9d4",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.3/bazel-gazelle-v0.22.3.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.22.3/bazel-gazelle-v0.22.3.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.16")

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

gazelle_dependencies()

go_repository(
    name = "org_golang_google_grpc",
    build_file_proto_mode = "disable",
    importpath = "google.golang.org/grpc",
    commit = "577eb696279ea85069a02c9a4c2defafdab858c5"
    #sum = "h1:J0UbZOIrCAl+fpTOf8YLs4dJo8L/owV4LYVtAXQoPkw=",
    #version = "v1.33.2",
)

go_repository(
    name = "org_golang_x_net",
    importpath = "golang.org/x/net",
    sum = "h1:oWX7TPOiFAMXLq8o0ikBYfCJVlRHBcsciT5bXOrH628=",
    version = "v0.0.0-20190311183353-d8887717615a",
)

go_repository(
    name = "org_golang_x_text",
    importpath = "golang.org/x/text",
    sum = "h1:g61tztE5qeGQ89tm6NTjjM9VPIm088od1l6aSorWRWg=",
    version = "v0.3.0",
)

http_archive(
    name = "com_github_grpc_grpc",
    sha256 = "bb6de0544adddd54662ba1c314eff974e84c955c39204a4a2b733ccd990354b7",
    strip_prefix = "grpc-1.36.3",
    urls = ["https://github.com/grpc/grpc/archive/v1.36.3.tar.gz"],
)

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()
```

**`@com_github_emacski_bazeltools//protobuf:go.bzl`**

### `go_proto_library`
Go protobuf library rule that can handle `proto_library` "proxy" type definitions
```
go_proto_library(name, proto, deps, plugin, plugin_name, plugin_flags, plugin_opts)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>unique name for this rule |
| `proto` | `Label List, required`<br/>A single element list containing the `proto_library` target |
| `deps` | `Label List, required`<br/>A list of `go_library` or `go_proto_library` dependencies |
| `importpath` | `string, required`<br/>go package import path |
| `plugin` | `string, optional.`<br/>An optional custom protoc plugin to execute together with generating the protobuf code. |
| `plugin_name` | `string, optional.`<br/>the name used to invoke the plugin from the compiler |
| `plugin_flags` | `string List, optional.`<br/>list of string flags to pass to the plugin |
| `plugin_opts` | `string List, optional.`<br/>list of string opts to pass to the plugin |

### `go_grpc_library`
Go grpc library rule that can handle `proto_library` "proxy" type definitions
```
go_grpc_library(name, srcs, deps, plugin, plugin_name, plugin_flags, plugin_opts)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.`<br/>unique name for this rule |
| `srcs` | `Label List, required`<br/>a single element list containing the `proto_library` target that declares the grpc service sources |
| `deps` | `Label List, required`<br/>a list of `go_library` or `go_proto_library` targets. Should contain the `go_proto_library` that generates protobuf dependency sources |
| `importpath` | `string, required`<br/>go package import path |
| `plugin` | `string, optional.`<br/>An optional custom protoc plugin to execute together with generating the protobuf code. |
| `plugin_name` | `string, optional.`<br/>the name used to invoke the plugin from the compiler |
| `plugin_flags` | `string List, optional.`<br/>list of string flags to pass to the plugin |
| `plugin_opts` | `string List, optional.`<br/>list of string opts to pass to the plugin |
