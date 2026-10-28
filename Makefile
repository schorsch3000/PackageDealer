SHELLSPEC ?= vendor/shellspec/shellspec
SHELLCHECK ?= shellcheck
LINT_FILES = PackageDealer spec/spec_helper.sh spec/support/stub

.PHONY: all test lint spec image

all: test

# test = shellcheck + shellspec
test: lint spec

lint:
	$(SHELLCHECK) -x $(LINT_FILES)

spec: $(SHELLSPEC)
	$(SHELLSPEC)

$(SHELLSPEC):
	git clone --depth 1 https://github.com/shellspec/shellspec.git vendor/shellspec

image:
	docker build -t packagedealer .
