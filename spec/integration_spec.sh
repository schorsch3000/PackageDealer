# shellcheck shell=bash
Describe 'PackageDealer CLI'
  pd() { "$PD_ROOT/PackageDealer" "$@" </dev/null; }
  pd_stdin() { "$PD_ROOT/PackageDealer" "$@"; }
  calls() { cat "$PD_CALLS"; }
  BeforeEach pd_sandbox
  AfterEach pd_sandbox_cleanup

  Describe 'installing only what is missing, in one batch'
    It 'installs missing apt packages in a single call, without upgrade'
      pd_fixture apt <<<'ii  curl:amd64'
      printf '%s\n' curl git vim >"$PD_SANDBOX/apt.txt"
      When run pd --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should include 'apt: 2 to install, 1 already present'
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 git vim'
      The contents of file "$PD_CALLS" should not include 'curl'"$(printf '\n')"'apt-get'
    End

    It 'queries the apt list exactly once, not per package'
      printf '%s\n' a b c d e >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of dpkg-query
      The output should eq 1
    End

    It 'does not call install when everything is present'
      pd_fixture apt <<<'ii  curl:amd64'
      echo curl >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of apt-get
      The output should eq 0
    End

    It 'recognises arch-qualified apt packages'
      pd_fixture apt <<<'ii  libc6:i386'
      echo libc6:i386 >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of apt-get
      The output should eq 0
    End

    It 'installs missing npm packages globally in one call'
      pd_fixture node <<<'/usr/lib
/usr/lib/node_modules/typescript
/usr/lib/node_modules/@angular/cli'
      printf '%s\n' typescript@5 @angular/cli eslint prettier >"$PD_SANDBOX/node.txt"
      When run pd --node "$PD_SANDBOX/node.txt"
      The status should be success
      The stderr should include 'node: 2 to install'
      The contents of file "$PD_CALLS" should include 'npm install -g eslint prettier'
    End

    It 'installs missing pipx packages in one call and matches normalised names'
      pd_fixture pipx <<<'yt-dlp 2024.1.1'
      printf '%s\n' yt_dlp black >"$PD_SANDBOX/pipx.txt"
      When run pd --pipx "$PD_SANDBOX/pipx.txt"
      The status should be success
      The stderr should include 'pipx: 1 to install'
      The contents of file "$PD_CALLS" should include 'pipx install --global black'
    End

    It 'installs missing composer packages with global require in one call'
      pd_fixture composer <<<'phpunit/phpunit'
      printf '%s\n' phpunit/phpunit squizlabs/php_codesniffer friendsofphp/php-cs-fixer >"$PD_SANDBOX/c.txt"
      When run pd --composer "$PD_SANDBOX/c.txt"
      The status should be success
      The stderr should include 'composer: 2 to install'
      The contents of file "$PD_CALLS" should include 'composer global require --no-interaction squizlabs/php_codesniffer friendsofphp/php-cs-fixer'
    End
  End

  Describe 'prefixed file'
    It 'dispatches each line to its manager'
      printf '%s\n' a:foo n:bar p:baz c:vendor/phar >"$PD_SANDBOX/all.txt"
      When run pd --file "$PD_SANDBOX/all.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 foo'
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
      The contents of file "$PD_CALLS" should include 'pipx install --global baz'
      The contents of file "$PD_CALLS" should include 'composer global require --no-interaction vendor/phar'
    End

    It 'combines with manager files'
      echo a:foo >"$PD_SANDBOX/all.txt"; echo bar >"$PD_SANDBOX/node.txt"
      When run pd --file "$PD_SANDBOX/all.txt" --node "$PD_SANDBOX/node.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get install'
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
    End

    It 'reads stdin with -'
      Data 'a:foo'
      When run pd_stdin --file -
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 foo'
    End

    It 'assumes -f - when stdin is not a tty and no - was given'
      Data 'n:bar'
      When run pd_stdin
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
    End

    It 'assumes -f - even when other files are given'
      echo foo >"$PD_SANDBOX/a.txt"
      Data 'n:bar'
      When run pd_stdin --apt "$PD_SANDBOX/a.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 foo'
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
    End

    It 'does not add implicit stdin when - was given explicitly'
      Data 'foo'
      When run pd_stdin --apt -
      The status should be success
      The stderr should include 'apt: 1 to install'
      The contents of file "$PD_CALLS" should not include 'npm'
    End

    It 'rejects stdin used twice'
      When run pd_stdin --apt - --node -
      The status should be failure
      The stderr should include "can only be used once"
    End

    It 'reads -n - as node list'
      Data
        #|bar
      End
      When run pd_stdin -n -
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
    End

    It 'reads -c - as composer list'
      Data 'vendor/pkg'
      When run pd_stdin -c -
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'composer global require --no-interaction vendor/pkg'
    End

    It 'reads -p - as pipx list'
      Data 'black'
      When run pd_stdin -p -
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'pipx install --global black'
    End

    It 'accepts repeated options of the same kind'
      echo foo >"$PD_SANDBOX/1.txt"; echo bar >"$PD_SANDBOX/2.txt"
      When run pd -n "$PD_SANDBOX/1.txt" -n "$PD_SANDBOX/2.txt"
      The status should be success
      The stderr should include 'node: 2 to install'
      The contents of file "$PD_CALLS" should include 'npm install -g foo bar'
    End

    It 'accepts repeated -f files'
      echo a:foo >"$PD_SANDBOX/1.txt"; echo n:bar >"$PD_SANDBOX/2.txt"
      When run pd -f "$PD_SANDBOX/1.txt" --file "$PD_SANDBOX/2.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 foo'
    End

    It 'ignores whitespace-only lines, comments, and whitespace around names'
      printf '   \n\t\n  # only comment\n\t a:foo\t  # trailing\r\n  n:  bar  \r\n' >"$PD_SANDBOX/all.txt"
      When run pd -f "$PD_SANDBOX/all.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 foo'
      The contents of file "$PD_CALLS" should include 'npm install -g bar'
    End

    It 'rejects unknown prefix'
      echo x:foo >"$PD_SANDBOX/all.txt"
      When run pd --file "$PD_SANDBOX/all.txt"
      The status should be failure
      The stderr should include 'expected a manager prefix'
    End

    It 'rejects missing prefix'
      echo foo >"$PD_SANDBOX/all.txt"
      When run pd --file "$PD_SANDBOX/all.txt"
      The status should be failure
      The stderr should include 'expected a manager prefix'
    End
  End

  Describe 'virtual apt packages'
    It 'treats a package as present when an installed package provides it'
      pd_fixture apt <<<'ii  postfix:amd64 mail-transport-agent, foo (= 1.0), bar'
      printf '%s\n' mail-transport-agent foo bar baz >"$PD_SANDBOX/apt.txt"
      When run pd --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should include 'apt: 1 to install, 3 already present'
      The contents of file "$PD_CALLS" should include 'apt-get install -y --no-upgrade -o Acquire::Retries=3 baz'
    End
  End

  Describe 'pipx url specs'
    It 'skips a url spec that pipx already recorded'
      printf '%s\n' 'git+https://example.com/x.git' black >"$PD_SANDBOX/pipx.txt"
      pd_fixture pipx <<<'x 1.0'
      cat >"$PD_SANDBOX/pipx.json" <<'JSON'
{
  "venvs": {
    "x": { "metadata": { "main_package": {
      "package": "x",
      "package_or_url": "git+https://example.com/x.git",
      "pip_args": []
    } } }
  }
}
JSON
      When run pd --pipx "$PD_SANDBOX/pipx.txt"
      The status should be success
      The stderr should include 'pipx: 1 to install, 1 already present'
      The contents of file "$PD_CALLS" should include 'pipx install --global black'
    End

    It 'does not make the extra json call without url specs'
      echo black >"$PD_SANDBOX/pipx.txt"
      pd --pipx "$PD_SANDBOX/pipx.txt" 2>/dev/null
      When call pd_calls_of 'pipx list --json'
      The output should eq 0
    End
  End

  Describe 'apt update flag'
    It 'runs apt-get update before install when asked'
      echo foo >"$PD_SANDBOX/apt.txt"
      When run pd --update --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'apt-get update'
    End

    It 'does not update by default'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of 'apt-get update'
      The output should eq 0
    End

    It 'does not update when nothing is missing'
      pd_fixture apt <<<'ii  foo:amd64'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --update --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of 'apt-get update'
      The output should eq 0
    End

    It 'does not update on dry run'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --dry-run --update --apt "$PD_SANDBOX/apt.txt" >/dev/null 2>&1
      When call pd_calls_of 'apt-get update'
      The output should eq 0
    End
  End

  Describe 'only touches requested managers'
    It 'does not query other managers'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of npm
      The output should eq 0
    End
  End

  Describe 'privileges'
    It 'uses sudo for apt when not root'
      echo foo >"$PD_SANDBOX/apt.txt"
      export PD_EUID=1000
      When run pd --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'sudo env DEBIAN_FRONTEND=noninteractive apt-get install'
    End

    It 'does not use sudo for apt when root'
      echo foo >"$PD_SANDBOX/apt.txt"
      pd --apt "$PD_SANDBOX/apt.txt" 2>/dev/null
      When call pd_calls_of sudo
      The output should eq 0
    End

    It 'never uses sudo for npm'
      echo foo >"$PD_SANDBOX/n.txt"
      export PD_EUID=1000
      pd --node "$PD_SANDBOX/n.txt" 2>/dev/null
      When call pd_calls_of sudo
      The output should eq 0
    End

    It 'falls back to a user npm prefix when the default is not writable'
      unset NPM_CONFIG_PREFIX
      export PD_EUID=1000 HOME=$PD_SANDBOX
      echo foo >"$PD_SANDBOX/n.txt"
      When run pd --node "$PD_SANDBOX/n.txt"
      The status should be success
      The stderr should be present
      The contents of file "$PD_CALLS" should include 'npm install -g foo'
    End
  End

  Describe 'dry run'
    It 'lists missing packages but installs nothing'
      pd_fixture apt <<<'ii  curl:amd64'
      printf '%s\n' curl git >"$PD_SANDBOX/apt.txt"
      When run pd --dry-run --apt "$PD_SANDBOX/apt.txt"
      The status should be success
      The output should eq 'apt: git'
      The stderr should be present
      The contents of file "$PD_CALLS" should not include 'apt-get'
    End
  End

  Describe 'errors'
    It 'fails early when a manager tool is missing'
      echo foo >"$PD_SANDBOX/c.txt"
      rm "$PD_SANDBOX/bin/composer"
      When run env PATH="$PD_SANDBOX/bin:/usr/bin:/bin" "$PD_ROOT/PackageDealer" --composer "$PD_SANDBOX/c.txt"
      The status should be failure
      The stderr should include "'composer' not found"
    End

    It 'fails on missing input file'
      When run pd --apt /no/such/file
      The status should be failure
      The stderr should include 'cannot read file'
    End

    It 'fails on unknown option'
      When run pd --bogus
      The status should be failure
      The stderr should include 'unknown argument'
    End

    It 'continues with other managers and exits non-zero when one install fails'
      export PD_STUB_FAIL_FOR=npm
      echo foo >"$PD_SANDBOX/n.txt"; echo bar >"$PD_SANDBOX/p.txt"
      When run pd --node "$PD_SANDBOX/n.txt" --pipx "$PD_SANDBOX/p.txt"
      The status should be failure
      The stderr should include 'node install failed'
      The contents of file "$PD_CALLS" should include 'pipx install --global bar'
    End

    It 'does nothing with no input'
      When run pd
      The status should be success
      The stderr should include 'nothing to do'
    End
  End
End
