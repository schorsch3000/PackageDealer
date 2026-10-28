# shellcheck shell=bash
Describe 'PackageDealer --upgrade'
  pd() { "$PD_ROOT/PackageDealer" "$@" </dev/null; }
  BeforeEach pd_sandbox
  AfterEach pd_sandbox_cleanup

  It 'never upgrades without the flag'
    pd_fixture pipx <<<'black 24.1'
    echo black >"$PD_SANDBOX/p.txt"
    pd --pipx "$PD_SANDBOX/p.txt" 2>/dev/null
    When call pd_calls_of 'pipx upgrade'
    The output should eq 0
  End

  It 'apt: one install call for installed and missing, without --no-upgrade, after update'
    pd_fixture apt <<<'ii  curl:amd64'
    printf '%s\n' curl git >"$PD_SANDBOX/apt.txt"
    When run pd --upgrade --apt "$PD_SANDBOX/apt.txt"
    The status should be success
    The stderr should include 'apt: 1 to install, 1 to upgrade'
    The contents of file "$PD_CALLS" should include 'apt-get update'
    The contents of file "$PD_CALLS" should include 'apt-get install -y -o Acquire::Retries=3 curl git'
    The contents of file "$PD_CALLS" should not include '--no-upgrade'
  End

  It 'node: installs @latest for unversioned specs, keeps pins'
    pd_fixture node <<<'/usr/lib
/usr/lib/node_modules/typescript
/usr/lib/node_modules/@angular/cli'
    printf '%s\n' typescript@5 @angular/cli eslint >"$PD_SANDBOX/n.txt"
    When run pd -U --node "$PD_SANDBOX/n.txt"
    The status should be success
    The stderr should be present
    The contents of file "$PD_CALLS" should include 'npm install -g typescript@5 @angular/cli@latest eslint@latest'
  End

  It 'pipx: upgrades installed unpinned, installs missing, leaves pinned'
    pd_fixture pipx <<<'black 24.1
ruff 0.4'
    printf '%s\n' black ruff==0.4 httpie >"$PD_SANDBOX/p.txt"
    When run pd -U --pipx "$PD_SANDBOX/p.txt"
    The status should be success
    The stderr should be present
    The contents of file "$PD_CALLS" should include 'pipx install --global httpie'
    The contents of file "$PD_CALLS" should include 'pipx upgrade --global black'
    The contents of file "$PD_CALLS" should not include 'upgrade --global black ruff'
  End

  It 'pipx: warns about url specs it cannot upgrade'
    pd_fixture pipx <<<'x 1.0'
    printf '%s\n' 'git+https://example.com/x.git' >"$PD_SANDBOX/p.txt"
    cat >"$PD_SANDBOX/pipx.json" <<'JSON'
{ "venvs": { "x": { "metadata": { "main_package": {
  "package_or_url": "git+https://example.com/x.git"
} } } } }
JSON
    When run pd -U --pipx "$PD_SANDBOX/p.txt"
    The status should be success
    The stderr should include 'cannot upgrade url/path spec'
    The contents of file "$PD_CALLS" should not include 'pipx upgrade'
  End

  It 'composer: updates installed unpinned, requires missing'
    pd_fixture composer <<<'a/b
c/d'
    printf '%s\n' a/b 'c/d:^1' e/f >"$PD_SANDBOX/c.txt"
    When run pd -U --composer "$PD_SANDBOX/c.txt"
    The status should be success
    The stderr should be present
    The contents of file "$PD_CALLS" should include 'composer global require --no-interaction e/f'
    The contents of file "$PD_CALLS" should include 'composer global update --no-interaction a/b'
    The contents of file "$PD_CALLS" should not include 'c/d:'"$(printf '\n')"'composer global update'
  End

  It 'gem: updates installed, installs missing'
    pd_fixture gem <<<'rake'
    printf '%s\n' rake rubocop >"$PD_SANDBOX/g.txt"
    When run pd -U --gem "$PD_SANDBOX/g.txt"
    The status should be success
    The stderr should be present
    The contents of file "$PD_CALLS" should include 'gem install --no-document rubocop'
    The contents of file "$PD_CALLS" should include 'gem update rake'
  End

  It 'cargo: one install call with all crates'
    pd_fixture cargo <<<'ripgrep v14.1.0:'
    printf '%s\n' ripgrep bat >"$PD_SANDBOX/r.txt"
    When run pd -U --cargo "$PD_SANDBOX/r.txt"
    The status should be success
    The stderr should be present
    The contents of file "$PD_CALLS" should include 'cargo install ripgrep bat'
  End

  It 'go: reinstalls installed tools at @latest'
    printf '/b/x: go1.22\n\tpath\tgithub.com/a/b\n' | pd_fixture go
    printf '%s\n' github.com/a/b github.com/c/d >"$PD_SANDBOX/go.txt"
    When run pd -U --go "$PD_SANDBOX/go.txt"
    The status should be success
    The stderr should be present
    The contents of file "$PD_CALLS" should include 'go install github.com/a/b@latest'
    The contents of file "$PD_CALLS" should include 'go install github.com/c/d@latest'
  End

  It 'dry run shows what would be upgraded and installs nothing'
    pd_fixture gem <<<'rake'
    printf '%s\n' rake rubocop >"$PD_SANDBOX/g.txt"
    When run pd -d -U --gem "$PD_SANDBOX/g.txt"
    The status should be success
    The output should include 'gem: rubocop'
    The output should include 'gem upgrade: rake'
    The stderr should be present
    The contents of file "$PD_CALLS" should not include 'gem update'
  End

  It 'does not call upgrade when nothing is installed'
    echo rubocop >"$PD_SANDBOX/g.txt"
    pd -U --gem "$PD_SANDBOX/g.txt" 2>/dev/null
    When call pd_calls_of 'gem update'
    The output should eq 0
  End
End
