# shellcheck shell=bash disable=SC2034
Describe 'PackageDealer internals'
  Include ./PackageDealer

  Describe 'pd_key'
    key() { pd_key "$1" "$2"; echo "$REPLY"; }
    It 'keeps plain apt names and arch qualifiers'
      When call key apt libc6:i386
      The output should eq 'libc6:i386'
    End
    It 'strips apt version and release pins'
      When call key apt curl=8.0-1
      The output should eq 'curl'
    End
    It 'strips npm version pins'
      When call key node typescript@5.4.2
      The output should eq 'typescript'
    End
    It 'handles scoped npm packages'
      When call key node @angular/cli@17
      The output should eq '@angular/cli'
    End
    It 'keeps unversioned scoped npm packages'
      When call key node @angular/cli
      The output should eq '@angular/cli'
    End
    It 'normalises pipx names (case, _ . -)'
      When call key pipx Yt_DLP==2024.1
      The output should eq 'yt-dlp'
    End
    It 'strips pipx extras'
      When call key pipx 'httpie[socks]'
      The output should eq 'httpie'
    End
    It 'uses urls as-is for pipx'
      When call key pipx git+https://example.com/x.git
      The output should eq 'git+https://example.com/x.git'
    End
    It 'strips composer constraints and lowercases'
      When call key composer Phpunit/PHPUnit:^11
      The output should eq 'phpunit/phpunit'
    End
  End

  Describe 'pd_read_file'
    setup() { WANT_apt=() WANT_node=() WANT_pipx=() WANT_composer=(); PD_SEEN=(); }
    BeforeEach setup
    show() { echo "apt=${WANT_apt[*]} node=${WANT_node[*]} pipx=${WANT_pipx[*]} composer=${WANT_composer[*]}"; }

    It 'splits prefixed lines by manager, ignoring comments and blanks'
      mixed() {
        printf '%s\n' '# comment' 'a:foo' '' 'n:bar  # trailing' '  p:baz' 'c:vendor/phar' >"$SHELLSPEC_TMPBASE/m.txt"
        pd_read_file mixed "$SHELLSPEC_TMPBASE/m.txt"; show
      }
      When call mixed
      The output should eq 'apt=foo node=bar pipx=baz composer=vendor/phar'
    End

    It 'reads manager specific files without prefix'
      plain() {
        printf '%s\n' curl git >"$SHELLSPEC_TMPBASE/a.txt"
        pd_read_file apt "$SHELLSPEC_TMPBASE/a.txt"; show
      }
      When call plain
      The output should eq 'apt=curl git node= pipx= composer='
    End

    It 'keeps apt arch qualifier in manager specific files'
      arch() { echo libc6:i386 >"$SHELLSPEC_TMPBASE/a.txt"; pd_read_file apt "$SHELLSPEC_TMPBASE/a.txt"; show; }
      When call arch
      The output should eq 'apt=libc6:i386 node= pipx= composer='
    End

    It 'dedupes'
      dup() { printf 'a:foo\na:foo\n' >"$SHELLSPEC_TMPBASE/m.txt"; pd_read_file mixed "$SHELLSPEC_TMPBASE/m.txt"; show; }
      When call dup
      The output should eq 'apt=foo node= pipx= composer='
    End

    It 'reads last line without trailing newline'
      nonl() { printf 'a:foo' >"$SHELLSPEC_TMPBASE/m.txt"; pd_read_file mixed "$SHELLSPEC_TMPBASE/m.txt"; show; }
      When call nonl
      The output should eq 'apt=foo node= pipx= composer='
    End
  End
End
