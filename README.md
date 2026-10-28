# PackageDealer

One shell script that installs packages with several package managers, and does it fast. Built for (multi-level) dev-container images: a base image may already contain some of your packages, PackageDealer installs only what is missing.

Supported managers:

| Manager  | Prefix | Long prefix | Installs with                | Installed list from                 |
|----------|--------|-------------|------------------------------|-------------------------------------|
| apt      | `a:`   | `apt:`      | `apt-get install`            | `dpkg-query -W`                     |
| node     | `n:`   | `node:`     | `npm install -g`             | `npm ls -g --parseable`             |
| pipx     | `p:`   | `pipx:`     | `pipx install`               | `pipx list --short`                 |
| composer | `c:`   | `composer:` | `composer global require`    | `composer global show --direct`     |
| cargo    | `r:`   | `cargo:`    | `cargo install`              | `cargo install --list`              |
| gem      | `e:`   | `gem:`      | `gem install`                | `gem list --local`                  |
| go       | `g:`   | `go:`       | `go install`                 | `go version -m` on the bin dir      |

## Why it is fast

PackageDealer never asks a package manager "is X installed?" once per package. For each manager it:

1. fetches the list of installed packages **once** (all managers in parallel),
2. removes the already installed packages from your wishlist in memory,
3. installs everything that is still missing in **one call per manager** (go: one call per package, see below).

Packages that are already installed are never touched and never upgraded (apt runs with `--no-upgrade`).

## Requirements

- bash 4.4 or newer
- the package managers you actually use (a manager without packages in your files is not needed)
- for apt as non-root: `sudo`

## Usage

```
pd [options]
```

`pd` is a symlink to `PackageDealer`. Put either on your `PATH`.

### Manager specific files

One package per line:

```
pd --apt packages.apt --node packages.node --pipx packages.pipx --composer packages.composer \
   --cargo packages.cargo --gem packages.gem --go packages.go
```

### One file with prefixes

Every line starts with the manager's prefix:

```
# packages.txt
a:git
a:curl
n:typescript
n:@angular/cli
p:black
c:phpunit/phpunit
r:ripgrep
e:rubocop
g:golang.org/x/tools/cmd/goimports
```

```
pd --file packages.txt
```

### A directory of files (layered images)

`--dir DIR` reads every file in `DIR` by extension: `*.apt`, `*.node`, `*.pipx`, `*.composer`, `*.cargo`, `*.gem`, `*.go` (one package per line) and `*.txt` (prefixed lines), in name order. Other files are ignored.

Each image layer drops its own file into a shared directory and runs `pd --dir`; whatever a lower layer already installed is skipped.

### Options

| Option                  | Meaning                                                              |
|-------------------------|----------------------------------------------------------------------|
| `-a`, `--apt FILE`      | apt packages, one per line                                           |
| `-n`, `--node FILE`     | npm packages                                                         |
| `-p`, `--pipx FILE`     | pipx packages                                                        |
| `-c`, `--composer FILE` | composer packages                                                    |
| `-r`, `--cargo FILE`    | cargo crates                                                         |
| `-e`, `--gem FILE`      | ruby gems                                                            |
| `-g`, `--go FILE`       | go packages (`@latest` is added when no version is given)            |
| `-f`, `--file FILE`     | prefixed lines                                                       |
| `-D`, `--dir DIR`       | all recognised files in a directory                                  |
| `-U`, `--upgrade`       | also upgrade the listed packages that are already installed (implies `--update`) |
| `-u`, `--update`        | run `apt-get update` first (only if apt has something to install)    |
| `-R`, `--no-recommends` | apt: `--no-install-recommends`                                       |
| `--clean`               | remove package caches of the managers that installed something       |
| `-d`, `--dry-run`       | print what would be installed, install nothing                       |
| `--check`               | like `--dry-run`, but exit 1 if anything is missing                  |
| `-q`, `--quiet`         | only errors; managers get their quiet flags                          |
| `-v`, `--verbose`       | print every command that is run                                      |
| `-h`, `--help`          | usage                                                                |
| `-V`, `--version`       | version                                                              |

- Every file option can be repeated: `pd -n a.txt -n b.txt`.
- `-` as file name reads stdin (only once per run).
- If you do not pass `-` anywhere and stdin is not a terminal, `-f -` is assumed, so `echo n:typescript | pd` works.
  Be aware that a stdin that never closes (for example `docker run -i`, cron or some CI setups) makes `pd` wait; redirect from `/dev/null` there.

### File format

- Blank and whitespace-only lines are ignored.
- Whitespace around a package name is ignored.
- Everything after a `#` in a line is ignored.

### Version pins

Pins are allowed (except for gems) and are stripped when checking whether a package is installed. A pinned package that is installed in any version counts as present and is not upgraded.

| Manager  | Examples                              |
|----------|---------------------------------------|
| apt      | `curl=8.0-1`, `libc6:i386`            |
| node     | `typescript@5`, `@angular/cli@17`     |
| pipx     | `black==24.1`, `httpie[socks]`        |
| composer | `phpunit/phpunit:^11`                 |
| cargo    | `ripgrep@14.1.0`                      |
| go       | `golang.org/x/tools/cmd/goimports@v0.20.0` |

## Behaviour details

- **Order:** apt, node, pipx, composer, cargo, gem, go. apt comes first because it often provides node, python, php, ruby, rust or go for the others.
- **Failures:** a missing tool aborts before anything is installed. If one manager's install fails, the others still run and the exit code is 1.
- **`--upgrade`:** only the packages named in your files are upgraded, never everything that is installed. Without the flag nothing is ever upgraded. Per manager:
  - apt: one `apt-get install` for all listed packages, without `--no-upgrade`.
  - node: `npm install -g name@latest`; pinned specs (`name@5`) install exactly that.
  - cargo: one `cargo install` for all listed crates.
  - go: `go install pkg@latest` for each.
  - pipx: `pipx upgrade` for installed, unpinned packages; missing ones are installed. URL/path specs cannot be upgraded (a warning is printed).
  - composer: `composer global update` for installed, unpinned packages (within their constraints); missing ones are required.
  - gem: `gem update` for installed gems; missing ones are installed.
  - Pinned specs (`black==24`, `vendor/pkg:^1`) are left alone for pipx and composer.
- **apt index:** base images usually have no apt index. If it is empty, `apt-get update` runs automatically before the install (and only if there is something to install). `--update` forces it. Downloads are retried 3 times.
- **Root or not:**
  - As **root** everything is installed system-wide: `pipx --global`, composer with `COMPOSER_HOME=/usr/local/composer` and `COMPOSER_BIN_DIR=/usr/local/bin`, cargo with `CARGO_INSTALL_ROOT=/usr/local`, go with `GOBIN=/usr/local/bin`, gems into the system gem dir. Variables you already set win.
  - As a **normal user**: apt uses `sudo`; npm falls back to `~/.local` (or `PD_NPM_PREFIX`) if its prefix is not writable, in that case system-wide npm packages do not count as installed; gems use `--user-install`; the rest installs to the manager's per-user default.
- **apt virtual packages:** a package counts as installed if an installed package `Provides` it.
- **pipx URL and path specs** (anything containing `/` or `:`) have no knowable name. They are matched against the specs pipx recorded, using one extra `pipx list --json` call, made only when such a spec is requested. Note that `#` starts a comment, so URL fragments like `#egg=name` cannot be used.
- **go:** there is no registry of installed go tools, so the main package path is read from the binaries in the bin dir (`GOBIN`, else `$GOPATH/bin`) with one `go version -m` call. Packages are installed one `go install` call at a time. Tools installed in a different directory than `GOBIN` are not recognised.
- **`--clean`:** apt lists and `apt-get clean`; `npm cache clean`; pip/pipx caches; `composer clear-cache`; cargo registry and git caches; gem cache; `go clean -cache -modcache`. Only for managers that installed something in this run. Removing the apt lists means the next `pd` run in a later layer refreshes the index again, which is automatic.

## Docker

Every release publishes an image that contains nothing but the script, so no `curl` or `apt install` is needed in your image:

```dockerfile
FROM debian:stable-slim
COPY --from=ghcr.io/schorsch3000/packagedealer:1 /usr/local/bin/pd /usr/local/bin/pd
COPY packages.txt /tmp/packages.txt
RUN pd --clean --no-recommends -f /tmp/packages.txt
```

Tags: `1.2.3`, `1.2`, `1` and `latest`. Layering:

```dockerfile
FROM my-base                      # may already contain some of the packages
COPY --from=ghcr.io/schorsch3000/packagedealer:1 /usr/local/bin/pd /usr/local/bin/pd
COPY team.apt team.node /etc/packagedealer.d/
RUN pd --clean --dir /etc/packagedealer.d
```

To verify an image contains everything (for example in a test stage): `pd --check --dir /etc/packagedealer.d`.

## Development

```
make test      # shellcheck + shellspec
make lint      # shellcheck only
make spec      # shellspec only
make image     # docker build
```

Tests use [shellspec](https://github.com/shellspec/shellspec), cloned into `vendor/shellspec` on first run (needs `git` and network access). The specs run against stub package managers (`spec/support/stub`), so no real packages are installed.

## CI and releases

- GitHub Actions runs `make test` and a test build of the image on every push to `main` and on every pull request.
- Pushing a tag like `v1.2.3` runs the tests, stamps `1.2.3` into the script (`pd --version`), creates a GitHub release with generated notes and the `PackageDealer` script attached, and pushes the image to `ghcr.io/schorsch3000/packagedealer`.
