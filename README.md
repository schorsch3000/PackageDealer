# PackageDealer

One shell script that installs packages with several package managers, and does it fast.

Supported managers:

| Manager  | Prefix | Installs with                    | Installed list from                   |
|----------|--------|----------------------------------|---------------------------------------|
| apt      | `a:`   | `apt-get install` (via sudo)     | `dpkg-query -W`                       |
| node     | `n:`   | `npm install -g`                 | `npm ls -g --parseable`               |
| pipx     | `p:`   | `pipx install`                   | `pipx list --short`                   |
| composer | `c:`   | `composer global require`        | `composer global show --direct`       |

## Why it is fast

PackageDealer never asks a package manager "is X installed?" once per package. For each manager it:

1. fetches the list of installed packages **once** (all managers in parallel),
2. removes the already installed packages from your wishlist in memory,
3. installs everything that is still missing in **one call per manager**.

Packages that are already installed are never touched and never upgraded (apt runs with `--no-upgrade`).

## Requirements

- bash 4.4 or newer
- the package managers you actually use (a manager without packages in your files is not needed)
- for apt: root, or `sudo`

## Usage

```
pd [options]
```

`pd` is a symlink to `PackageDealer`. Put either on your `PATH`.

### Manager specific files

One package per line:

```
pd --apt packages.apt --node packages.node --pipx packages.pipx --composer packages.composer
```

### One file with prefixes

Every line starts with the manager's prefix `a:`, `n:`, `p:` or `c:`:

```
# packages.txt
a:git
a:curl
n:typescript
n:@angular/cli
p:black
p:yt-dlp
c:phpunit/phpunit
```

```
pd --file packages.txt
```

### Options

| Option                | Meaning                                                               |
|-----------------------|-----------------------------------------------------------------------|
| `-a`, `--apt FILE`      | apt packages, one per line                                          |
| `-n`, `--node FILE`     | npm packages, one per line                                          |
| `-p`, `--pipx FILE`     | pipx packages, one per line                                         |
| `-c`, `--composer FILE` | composer packages, one per line                                     |
| `-f`, `--file FILE`     | prefixed lines (`a:foo`, `n:bar`, `p:baz`, `c:vendor/pkg`)          |
| `-u`, `--update`        | run `apt-get update` first (only if apt has something to install)   |
| `-d`, `--dry-run`       | print what would be installed, install nothing                      |
| `-h`, `--help`          | usage                                                               |
| `-V`, `--version`       | version                                                             |

- Every file option can be repeated: `pd -n a.txt -n b.txt`.
- `-` as file name reads stdin (only once per run).
- If you do not pass `-` anywhere and stdin is not a terminal, `-f -` is assumed, so `echo n:typescript | pd` works.
  Be aware that a stdin that never closes (for example in cron or some CI setups) makes `pd` wait; redirect from `/dev/null` there.

### File format

- Blank and whitespace-only lines are ignored.
- Whitespace around a package name is ignored.
- Everything after a `#` in a line is ignored.

### Version pins

Pins are allowed and are stripped when checking whether a package is installed. A pinned package that is installed in any version counts as present and is not upgraded.

| Manager  | Examples                              |
|----------|---------------------------------------|
| apt      | `curl=8.0-1`, `libc6:i386`            |
| node     | `typescript@5`, `@angular/cli@17`     |
| pipx     | `black==24.1`, `httpie[socks]`        |
| composer | `phpunit/phpunit:^11`                 |

## Behaviour details

- **Order:** apt first, then node, pipx, composer, because apt often provides node, python or php for the others.
- **Failures:** a missing tool aborts before anything is installed. If one manager's install fails, the others still run and the exit code is 1.
- **Privileges:** apt uses `sudo` when you are not root. npm, pipx and composer run as your user. If npm's default global prefix is not writable, `~/.local` is used instead (override with `PD_NPM_PREFIX`; an already set `NPM_CONFIG_PREFIX` wins). In that case system-wide npm packages do not count as installed.
- **apt virtual packages:** a package counts as installed if an installed package `Provides` it.
- **pipx URL and path specs** (anything containing `/` or `:`) have no knowable name. They are matched against the specs pipx recorded, using one extra `pipx list --json` call, made only when such a spec is requested. Note that `#` starts a comment, so URL fragments like `#egg=name` cannot be used.
- **apt index:** `apt-get update` is not run by default, for speed. Use `--update` when the index may be stale.

## Development

```
make test      # shellcheck + shellspec
make lint      # shellcheck only
make spec      # shellspec only
```

Tests use [shellspec](https://github.com/shellspec/shellspec), cloned into `vendor/shellspec` on first run (needs `git` and network access). The specs run against stub package managers (`spec/support/stub`), so no real packages are installed.

## CI and releases

- GitHub Actions runs `make test` on every push to `main` and on every pull request.
- Pushing a tag like `v1.2.3` runs the tests and creates a GitHub release with generated notes and the `PackageDealer` script attached.

The version printed by `pd --version` is the `PD_VERSION` variable at the top of the script. Update it before tagging.
