# shellcheck shell=bash
set -eu

PD_ROOT=$(cd "${SHELLSPEC_PROJECT_ROOT:-.}" && pwd)
export PD_ROOT

# Fresh sandbox per example: stub bin dir on PATH, call log, fixtures.
pd_sandbox() {
  PD_SANDBOX=$(mktemp -d)
  mkdir -p "$PD_SANDBOX/bin"
  local n
  for n in dpkg-query apt-get npm pipx composer cargo gem go sudo; do
    ln -s "$PD_ROOT/spec/support/stub" "$PD_SANDBOX/bin/$n"
  done
  # Minimal system tools for runs where PATH must hold nothing but stubs, so
  # a real pipx/composer/... on the host can never leak into a test.
  mkdir -p "$PD_SANDBOX/sysbin"
  for n in bash mktemp rm head awk sed cat env grep ln; do
    ln -s "$(command -v "$n")" "$PD_SANDBOX/sysbin/$n"
  done
  export PD_CALLS="$PD_SANDBOX/calls"
  export PD_STUB_DIR="$PD_SANDBOX"
  export PATH="$PD_SANDBOX/bin:$PATH"
  export NPM_CONFIG_PREFIX="$PD_SANDBOX/npm"
  export PD_EUID=0
  # apt index present by default, so no automatic update
  mkdir -p "$PD_SANDBOX/lists"
  : >"$PD_SANDBOX/lists/fake_Packages"
  export PD_APT_LISTS="$PD_SANDBOX/lists"
  export GOBIN="$PD_SANDBOX/gobin"
  mkdir -p "$GOBIN"
  : >"$PD_CALLS"
}

pd_sandbox_cleanup() { rm -rf "$PD_SANDBOX"; }

# pd_fixture NAME  (content on stdin) -> what the stubbed list command prints
pd_fixture() { cat >"$PD_SANDBOX/$1.list"; }

pd_calls_of() { grep -c "^$1 " "$PD_CALLS" || true; }

# Run PackageDealer with a PATH of only stubs + minimal system tools.
pd_isolated() {
  env PATH="$PD_SANDBOX/bin:$PD_SANDBOX/sysbin" "$BASH" "$PD_ROOT/PackageDealer" "$@" </dev/null
}
