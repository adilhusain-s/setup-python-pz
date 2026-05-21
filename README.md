# setup-python (IBM architectures fork)

This repository is a fork of [actions/setup-python](https://github.com/actions/setup-python), maintained by IBM to provide support for architectures not officially covered upstream. It enables GitHub Actions workflows on IBM Power (**ppc64le**) and IBM Z (**s390x**), while remaining functionally compatible with upstream for all other platforms.

## How this fork delivers Python runtimes

- For **ppc64le** and **s390x** runners, we publish CPython tarballs in the [IBM/python-versions-pz](https://github.com/IBM/python-versions-pz) repository, and this action downloads them directly from those releases.
- For **x64** and **arm64** runners, we fall back to the upstream [actions/python-versions](https://github.com/actions/python-versions) data, so you receive the same artifacts as `actions/setup-python`.
- PyPy and GraalPy builds are handled exactly as upstream. If a version is not available for Power or Z, the action will report it just like the original project.

> ℹ️ If you only require the standard Microsoft-hosted architectures, continue using [actions/setup-python](https://github.com/actions/setup-python). Use this fork if you rely on IBM Power or IBM Z runners.

## Why IBM maintains this fork

1. Both upstream repositories (`actions/setup-python` and `actions/python-versions`) are owned by Microsoft. Supporting Power and Z requires changes to both code and release infrastructure.
2. Microsoft has not accepted our pull requests to add **ppc64le** and **s390x** support, which blocks official distribution of these Python builds.
3. Hosting the artifacts ourselves requires installing the GitHub App described in the blog post ["GitHub Actions for IBM architectures v1.1"](https://community.ibm.com/community/user/blogs/mick-tarsel/2025/10/01/gha-v1-1). Until the upstream projects adopt that app (or similar infrastructure), we must maintain this fork to keep Power and Z runners unblocked.

Our goal is to stay close to upstream so that pipelines can switch between the two actions with minimal friction, while IBM works with Microsoft on a long-term solution.

## Feature parity with upstream

All features available in `actions/setup-python`, including pinning versions, installing PyPy or GraalPy, enabling dependency caching, using `python-version-file`, and registering matchers, work the same here. The only intentional difference is the source of CPython artifacts:

| Architecture | Runtime source |
|--------------|----------------|
| ppc64le      | [IBM/python-versions-pz](https://github.com/IBM/python-versions-pz) releases |
| s390x        | [IBM/python-versions-pz](https://github.com/IBM/python-versions-pz) releases |
| x64          | [actions/python-versions](https://github.com/actions/python-versions) (upstream) |
| arm64        | [actions/python-versions](https://github.com/actions/python-versions) (upstream) |

## Quick start

```yaml
steps:
  - uses: actions/checkout@v5
  - uses: adilhusain-s/setup-python-pz@v6
    with:
      python-version: "3.12"
      architecture: "ppc64le"
  - run: python my-script.py
```

Key inputs (same as upstream):

- `python-version` or `python-version-file`: Specify the CPython, PyPy, or GraalPy release you need.
- `architecture`: Set to `ppc64le` or `s390x` when running on IBM hardware. Omit this field (or use `x64`/`arm64`) to fall back to upstream artifacts.
- `cache`, `cache-dependency-path`: Enable dependency caching for pip, pipenv, or poetry.

See [action.yml](action.yml) for the full list of inputs.

## Working with IBM Python builds

When targeting Power or Z architectures, the action resolves versions from [IBM/python-versions-pz](https://github.com/IBM/python-versions-pz):

- Releases mirror upstream tags (e.g., `3.12.6`, `3.13.0`) and include free-threaded variants when available.
- The repository contains build scripts and Dockerfiles, allowing you to reproduce or audit the binaries.
- Issues regarding missing versions or defects in the binaries should be filed directly in that repository.

For x64/arm64, no configuration change is required—this fork simply calls upstream APIs and mirrors the behavior of `actions/setup-python`.

## Keeping up to date

- We periodically rebase on upstream to incorporate new features, security fixes, and Node.js runner updates.
- Release tags follow upstream numbering (v6.x, etc.), so workflows do not need to change their `uses:` syntax when switching between forks.
- When the upstream project adopts IBM Power and IBM Z support—or when the GitHub App mentioned above is installed in those repositories—we plan to retire this fork and direct users back to the canonical action.

## Support & contributions

- **IBM Power or IBM Z issues**: Open an issue or pull request in this repository.
- **Python tarball problems** (missing versions, checksum questions): Use [IBM/python-versions-pz](https://github.com/IBM/python-versions-pz/issues).
- **General `setup-python` behavior**: Consult the upstream [actions/setup-python documentation](https://github.com/actions/setup-python#readme) to stay aligned with standard usage.

We welcome fixes that keep this fork healthy and close to upstream. For broader changes or new features unrelated to IBM architectures, please contribute upstream first so we can stay in sync.

## License

This fork retains the [MIT License](LICENSE) of the original project.
- Optionally caching dependencies for pip, pipenv and poetry
- Registering problem matchers for error output

## Breaking changes in V6

- Upgraded action from node20 to node24
  > Make sure your runner is on version v2.327.1 or later to ensure compatibility with this release. See [Release Notes](https://github.com/actions/runner/releases/tag/v2.327.1)

For more details,  see the full release notes on the [releases page](https://github.com/actions/setup-python/releases/tag/v6.0.0)

## Basic usage

See [action.yml](action.yml)

**Python**
```yaml
steps:
- uses: actions/checkout@v6
- uses: actions/setup-python@v6
  with:
    python-version: '3.13' 
- run: python my_script.py
```

**PyPy**
```yaml
steps:
- uses: actions/checkout@v6
- uses: actions/setup-python@v6 
  with:
    python-version: 'pypy3.10' 
- run: python my_script.py
```

**GraalPy**
```yaml
steps:
- uses: actions/checkout@v6
- uses: actions/setup-python@v6 
  with:
    python-version: 'graalpy-24.0' 
- run: python my_script.py
```

**Free threaded Python**
```yaml
steps:
- uses: actions/checkout@v6
- uses: actions/setup-python@v6
  with:
    python-version: '3.13t'
- run: python my_script.py
```

The `python-version` input is optional. If not supplied, the action will try to resolve the version from the default `.python-version` file. If the `.python-version` file doesn't exist Python or PyPy version from the PATH will be used. The default version of Python or PyPy in PATH varies between runners and can be changed unexpectedly so we recommend always setting Python version explicitly using the `python-version` or `python-version-file` inputs.

The action will first check the local [tool cache](docs/advanced-usage.md#hosted-tool-cache) for a [semver](https://github.com/npm/node-semver#versions) match. If unable to find a specific version in the tool cache, the action will attempt to download a version of Python from [GitHub Releases](https://github.com/actions/python-versions/releases) and for PyPy from the official [PyPy's dist](https://downloads.python.org/pypy/).

For information regarding locally cached versions of Python or PyPy on GitHub hosted runners, check out [GitHub Actions Runner Images](https://github.com/actions/runner-images).

## Supported version syntax

The `python-version` input supports the [Semantic Versioning Specification](https://semver.org/) and some special version notations (e.g. `semver ranges`, `x.y-dev syntax`, etc.), for detailed examples please refer to the section: [Using python-version input](docs/advanced-usage.md#using-the-python-version-input) of the [Advanced usage](docs/advanced-usage.md) guide.

## Supported architectures

Using the `architecture` input, it is possible to specify the required Python or PyPy interpreter architecture: `x86`, `x64`, or `arm64`. If the input is not specified, the architecture defaults to the host OS architecture.

## Caching packages dependencies

The action has built-in functionality for caching and restoring dependencies. It uses [toolkit/cache](https://github.com/actions/toolkit/tree/main/packages/cache) under the hood for caching dependencies but requires less configuration settings. Supported package managers are `pip`, `pipenv` and `poetry`. The `cache` input is optional, and caching is turned off by default.

The action defaults to searching for a dependency file (`requirements.txt` or `pyproject.toml` for pip, `Pipfile.lock` for pipenv or `poetry.lock` for poetry) in the repository, and uses its hash as a part of the cache key. Input `cache-dependency-path` is used for cases when multiple dependency files are used, they are located in different subdirectories or different files for the hash that want to be used.

 - For `pip`, the action will cache the global cache directory
 - For `pipenv`, the action will cache virtualenv directory
 - For `poetry`, the action will cache virtualenv directories -- one for each poetry project found

**Caching pip dependencies:**

```yaml
steps:
- uses: actions/checkout@v6
- uses: actions/setup-python@v6
  with:
    python-version: '3.13'
    cache: 'pip' # caching pip dependencies
- run: pip install -r requirements.txt
```
>**Note:** Restored cache will not be used if the requirements.txt file is not updated for a long time and a newer version of the dependency is available which can lead to an increase in total build time.

>The requirements file format allows for specifying dependency versions using logical operators (for example chardet>=3.0.4) or specifying dependencies without any versions. In this case the pip install -r requirements.txt command will always try to install the latest available package version. To be sure that the cache will be used, please stick to a specific dependency version and update it manually if necessary.

>The `setup-python` action does not handle authentication for pip when installing packages from private repositories. For help, refer [pip’s VCS support documentation](https://pip.pypa.io/en/stable/topics/vcs-support/) or visit the [pip repository](https://github.com/pypa/pip).

See examples of using `cache` and `cache-dependency-path` for `pipenv` and `poetry` in the section: [Caching packages](docs/advanced-usage.md#caching-packages) of the [Advanced usage](docs/advanced-usage.md) guide.

## Advanced usage

- [Using the python-version input](docs/advanced-usage.md#using-the-python-version-input)
- [Using the python-version-file input](docs/advanced-usage.md#using-the-python-version-file-input)
- [Check latest version](docs/advanced-usage.md#check-latest-version)
- [Caching packages](docs/advanced-usage.md#caching-packages)
- [Outputs and environment variables](docs/advanced-usage.md#outputs-and-environment-variables)
- [Available versions of Python, PyPy and GraalPy](docs/advanced-usage.md#available-versions-of-python-pypy-and-graalpy)
- [Hosted tool cache](docs/advanced-usage.md#hosted-tool-cache) 
- [Using `setup-python` with a self-hosted runner](docs/advanced-usage.md#using-setup-python-with-a-self-hosted-runner)
- [Using `setup-python` on GHES](docs/advanced-usage.md#using-setup-python-on-ghes)
- [Allow pre-releases](docs/advanced-usage.md#allow-pre-releases)
- [Using the pip-version input](docs/advanced-usage.md#using-the-pip-version-input)
- [Using the pip-install input](docs/advanced-usage.md#using-the-pip-install-input)

## Recommended permissions

When using the `setup-python` action in your GitHub Actions workflow, it is recommended to set the following permissions to ensure proper functionality:

```yaml
permissions:
  contents: read # access to check out code and install dependencies
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).

## Contributions

Contributions are welcome! See our [Contributor's Guide](docs/contributors.md).
