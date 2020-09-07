# Protocol Buffer Tools

`WORKSPACE`
```
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
    sha256 = "ba74b97a2f1b4e22ec5fb69d639d849d2069fb58ea7d6579a31f800af6fe3b6c",
    strip_prefix = "grpc-1.30.2",
    urls = ["https://github.com/grpc/grpc/archive/v1.30.2.tar.gz"]
)
load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")
grpc_deps()
load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")
grpc_extra_deps()

http_archive(
    name = "com_github_emacski_bazeltools",
    #sha256 = "",
    strip_prefix = "bazel-tools-0.0.1",
    urls = ["https://github.com/emacski/bazel-tools/archive/0.0.1.tar.gz"],
)
```

## Python

**`@com_github_emacski_bazeltools//protobuf:python_rules.bzl`**

The following python rules are modified versions from the https://github.com/grpc/grpc
project that allow for generating python source from `proto_library` proxies.
The rules' signatures remain the same as their upstream counterparts.

### py_proto_library
```
py_proto_library(name, deps, plugin)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.` Unique name for this rule. |
| `deps` | `proto_library, required.` A list containing a single `proto_library` target (can be a proxy) |
| `plugin` | `string, optional.` An optional custom protoc plugin to execute together with generating the protobuf code. |

### py_grpc_library
```
py_grpc_library(name, srcs, deps, plugin, strip_prefixes)
```

| Attribute | Description |
|-----------|-------------|
| `name` | `Name, required.` Unique name for this rule. |
| `srcs` | `Label List, required` a single proto_library target containing the schema of the service. |
| `deps` | `Label List, required` a single py_proto_library target for the proto_library in `srcs`. |
| `plugin` | `String, optional` An optional custom protoc plugin to execute together with generating the gRPC code. |
| `strip_prefixes` | `string List, optional` If provided, this prefix will be stripped from the beginning of foo_pb2 modules imported by the generated stubs. This is useful in combination with the `imports` attribute of the `py_library` rule. |
