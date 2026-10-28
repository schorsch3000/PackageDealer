# shellcheck shell=bash
set -eu

PD_ROOT=$(cd "${SHELLSPEC_PROJECT_ROOT:-.}" && pwd)
export PD_ROOT

# Fresh sandbox per example: stub bin dir on PATH, call log, fixtures.
pd_sandbox() {
  PD_SANDBOX=$(mktemp -d)
  mkdir -p "$PD_SANDBOX/bin"
  local n
  for n in dpkg-query apt-get npm pipx composer sudo; do
    ln -s "$PD_ROOT/spec/support/stub" "$PD_SANDBOX/bin/$n"
  done
  export PD_CALLS="$PD_SANDBOX/calls"
  export PD_STUB_DIR="$PD_SANDBOX"
  export PATH="$PD_SANDBOX/bin:$PATH"
  export NPM_CONFIG_PREFIX="$PD_SANDBOX/npm"
  export PD_EUID=0
  : >"$PD_CALLS"
}

pd_sandbox_cleanup() { rm -rf "$PD_SANDBOX"; }

# pd_fixture NAME  (content on stdin) -> what the stubbed list command prints
pd_fixture() { cat >"$PD_SANDBOX/$1.list"; }

pd_calls_of() { grep -c "^$1 " "$PD_CALLS" || true; }
