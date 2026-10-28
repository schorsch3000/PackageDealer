# shellcheck shell=bash
Describe 'PackageDealer container features'
  pd() { "$PD_ROOT/PackageDealer" "$@" </dev/null; }
  BeforeEach pd_sandbox
  AfterEach pd_sandbox_cleanup

  Describe 'keys for cargo, gem, go'
    Include ./PackageDealer
    key() { pd_key "$1" "$2"; echo "$REPLY"; }
    It 'normalises cargo names and strips @version'
      When call key cargo Ripgrep_Fast@14.1.0
      The output should eq 'ripgrep-fast'
    End
    It 'keeps gem names'
      When call key gem rubocop
      The output should eq 'rubocop'
    End
    It 'strips go version'
      When call key go golang.org/x/tools/cmd/goimports@v0.20.0
      The output should eq 'golang.org/x/tools/cmd/goimports'
    End
    It 'accepts long and short prefixes'
      lp() { for p in a apt n node npm p pipx c composer r cargo e gem g go; do pd_prefix_to_manager "$p"; printf '%s ' "$REPLY"; done; }
      When call lp
      The output should eq 'apt apt node node node pipx pipx composer composer cargo cargo gem gem go go '
    End
  End

  Describe 'cargo, gem, go'
    It 'installs missing crates in one call'
      pd_fixture cargo <<'LIST'
ripgrep v14.1.0:
    rg
fd-find v10.0.0:
    fd
LIST
      printf '%s\n' ripgrep fd_find@10 bat eza >"$PD_SANDBOX/c.txt"
      When run pd --cargo "$PD_SANDBOX/c.txt"
      The status should be success
      The stderr should include 'cargo: 2 to install, 2 already present'
      The contents of file "$PD_CALLS" should include 'cargo install bat eza'
    End

    It 'installs missing gems in one call, skipping header lines'
      pd_fixture gem <<'LIST'
*** LOCAL GEMS ***

bundler
rake
LIST
      printf '%s\n' rake rubocop bundler >"$PD_SANDBOX/g.txt"
      When run pd -e "$PD_SANDBOX/g.txt"
      The status should be success
      The stderr should include 'gem: 1 to install'
      The contents of file "$PD_CALLS" should include 'gem install --no-document rubocop'
    End

    It 'uses --user-install for gems when not root'
      export PD_EUID=1000
      echo rubocop >"$PD_SANDBOX/g.txt"
      When run pd --gem "$PD_SANDBOX/g.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'gem install --no-document --user-install rubocop'
    End

    It 'detects installed go tools via their main package path and installs the rest one by one'
      printf '/b/goimports: go1.22\n\tpath\tgolang.org/x/tools/cmd/goimports\n\tmod\tgolang.org/x/tools\tv0.20.0\n' | pd_fixture go
      printf '%s\n' golang.org/x/tools/cmd/goimports github.com/a/b@v1.2.3 github.com/c/d >"$PD_SANDBOX/go.txt"
      When run pd --go "$PD_SANDBOX/go.txt"
      The status should be success
      The stderr should include 'go: 2 to install, 1 already present'
      The contents of file "$PD_CALLS" should include 'go install github.com/a/b@v1.2.3'
      The contents of file "$PD_CALLS" should include 'go install github.com/c/d@latest'
    End

    It 'dispatches r: e: g: and long prefixes in a prefixed file'
      printf '%s\n' r:bat e:rubocop g:github.com/c/d cargo:eza >"$PD_SANDBOX/all.txt"
      When run pd -f "$PD_SANDBOX/all.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'cargo install bat eza'
      The contents of file "$PD_CALLS" should include 'gem install'
      The contents of file "$PD_CALLS" should include 'go install github.com/c/d@latest'
    End
  End

  Describe 'system-wide install as root'
    It 'uses pipx --global'
      echo black >"$PD_SANDBOX/p.txt"
      When run pd --pipx "$PD_SANDBOX/p.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'pipx list --short --global'
      The contents of file "$PD_CALLS" should include 'pipx install --global black'
    End

    It 'does not use pipx --global as a normal user'
      export PD_EUID=1000
      echo black >"$PD_SANDBOX/p.txt"
      When run pd --pipx "$PD_SANDBOX/p.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'pipx install black'
      The contents of file "$PD_CALLS" should not include '--global'
    End

    It 'points composer at a system-wide home and bin dir'
      export PD_STUB_ENV='COMPOSER_HOME COMPOSER_BIN_DIR COMPOSER_ALLOW_SUPERUSER'
      echo vendor/pkg >"$PD_SANDBOX/c.txt"
      When run pd --composer "$PD_SANDBOX/c.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'env COMPOSER_HOME=/usr/local/composer'
      The contents of file "$PD_CALLS" should include 'env COMPOSER_BIN_DIR=/usr/local/bin'
      The contents of file "$PD_CALLS" should include 'env COMPOSER_ALLOW_SUPERUSER=1'
    End

    It 'installs cargo crates to /usr/local'
      export PD_STUB_ENV='CARGO_INSTALL_ROOT'
      echo bat >"$PD_SANDBOX/c.txt"
      When run pd --cargo "$PD_SANDBOX/c.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'env CARGO_INSTALL_ROOT=/usr/local'
    End

    It 'installs go tools to /usr/local/bin unless GOBIN is set'
      unset GOBIN
      export PD_STUB_ENV='GOBIN' HOME=$PD_SANDBOX
      echo github.com/c/d >"$PD_SANDBOX/go.txt"
      When run pd --go "$PD_SANDBOX/go.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'env GOBIN=/usr/local/bin'
    End
  End

  Describe 'apt index'
    It 'runs apt-get update before install when the index is empty'
      rm -f "$PD_SANDBOX"/lists/*
      echo foo >"$PD_SANDBOX/apt.txt"
      When run pd --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get update'
    End

    It 'treats a missing lists dir as empty'
      rm -rf "$PD_SANDBOX/lists"
      echo foo >"$PD_SANDBOX/apt.txt"
      When run pd --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get update'
    End

    It 'does not update with an index and nothing forced'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of 'sudo env DEBIAN_FRONTEND=noninteractive apt-get update'
      The output should eq 0
    End

    It 'retries downloads'
      echo foo >"$PD_SANDBOX/apt.txt"
      When run pd --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'Acquire::Retries=3'
    End

    It 'passes --no-install-recommends on request'
      echo foo >"$PD_SANDBOX/apt.txt"
      When run pd --no-recommends --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include '--no-install-recommends'
    End

    It 'does not pass --no-install-recommends by default'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call cat "$PD_CALLS"
      The output should not include '--no-install-recommends'
    End
  End

  Describe '--clean'
    It 'removes apt lists and cleans caches after installing'
      echo foo >"$PD_SANDBOX/apt.txt"; echo bar >"$PD_SANDBOX/n.txt"
      When run pd --clean --apt "$PD_SANDBOX/apt.txt" --node "$PD_SANDBOX/n.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get clean'
      The contents of file "$PD_CALLS" should include 'npm cache clean --force'
      The path "$PD_SANDBOX/lists/fake_Packages" should not be exist
    End

    It 'cleans composer and go caches'
      echo vendor/pkg >"$PD_SANDBOX/c.txt"; echo github.com/c/d >"$PD_SANDBOX/go.txt"
      When run pd --clean --composer "$PD_SANDBOX/c.txt" --go "$PD_SANDBOX/go.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'composer clear-cache'
      The contents of file "$PD_CALLS" should include 'go clean -cache -modcache'
    End

    It 'removes pip and cargo caches'
      export XDG_CACHE_HOME="$PD_SANDBOX/cache" CARGO_HOME="$PD_SANDBOX/cargo"
      mkdir -p "$XDG_CACHE_HOME/pip" "$CARGO_HOME/registry" "$CARGO_HOME/bin"
      echo black >"$PD_SANDBOX/p.txt"; echo bat >"$PD_SANDBOX/r.txt"
      When run pd --clean --pipx "$PD_SANDBOX/p.txt" --cargo "$PD_SANDBOX/r.txt"
      The status should be success
      The stderr should be present
      The path "$XDG_CACHE_HOME/pip" should not be exist
      The path "$CARGO_HOME/registry" should not be exist
      The path "$CARGO_HOME/bin" should be directory
    End

    It 'does not clean managers that installed nothing'
      pd_fixture node <<<'/usr/lib/node_modules/foo'
      echo foo >"$PD_SANDBOX/n.txt"
      pd --clean --node "$PD_SANDBOX/n.txt" 2>/dev/null
      When call pd_calls_of 'npm cache'
      The output should eq 0
    End

    It 'does not clean without the flag'
      echo bar >"$PD_SANDBOX/n.txt"
      pd --node "$PD_SANDBOX/n.txt" 2>/dev/null
      When call pd_calls_of 'npm cache'
      The output should eq 0
    End
  End

  Describe '--dir'
    mkdir_files() {
      mkdir -p "$PD_SANDBOX/d"
      printf 'git\n' >"$PD_SANDBOX/d/10-base.apt"
      printf 'typescript\n' >"$PD_SANDBOX/d/20-js.node"
      printf 'c:vendor/pkg\n# x\n' >"$PD_SANDBOX/d/30-all.txt"
      printf 'ignored\n' >"$PD_SANDBOX/d/README.md"
    }
    It 'reads every recognised file by extension'
      mkdir_files
      When run pd --dir "$PD_SANDBOX/d"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get install'
      The contents of file "$PD_CALLS" should include 'npm install -g typescript'
      The contents of file "$PD_CALLS" should include 'composer global require --no-interaction vendor/pkg'
      The contents of file "$PD_CALLS" should not include 'ignored'
    End

    It 'fails for a missing directory'
      When run pd --dir /no/such/dir
      The status should be failure
      The stderr should include 'not a directory'
    End
  End

  Describe '--check'
    It 'exits 1 and lists missing packages, installing nothing'
      pd_fixture apt <<<'ii  curl:amd64'
      printf '%s\n' curl git >"$PD_SANDBOX/apt.txt"
      When run pd --check --apt "$PD_SANDBOX/apt.txt"
      The status should be failure
      The output should eq 'apt: git'
      The stderr should be present
      The contents of file "$PD_CALLS" should not include 'apt-get install'
    End

    It 'exits 0 when everything is installed'
      pd_fixture apt <<<'ii  curl:amd64'
      echo curl >"$PD_SANDBOX/apt.txt"
      When run pd --check --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
    End
  End

  Describe 'verbosity'
    It 'prints nothing but errors with --quiet and passes quiet flags'
      echo bar >"$PD_SANDBOX/n.txt"
      When run pd -q --node "$PD_SANDBOX/n.txt"
      The status should be success
      The stderr should eq ''
      The contents of file "$PD_CALLS" should include 'npm install -g --loglevel=error bar'
    End

    It 'still prints errors with --quiet'
      When run pd -q --apt /no/such/file
      The status should be failure
      The stderr should include 'cannot read file'
    End

    It 'prints the commands with --verbose'
      echo bar >"$PD_SANDBOX/n.txt"
      When run pd -v --node "$PD_SANDBOX/n.txt"
      The status should be success
      The stderr should include '+ npm install -g bar'
    End
  End
End
