# See LICENSE for licensing information.

PROJECT = cowlib
PROJECT_DESCRIPTION = Support library for manipulating Web protocols.
PROJECT_VERSION = 2.11.0

# Options.

#ERLC_OPTS += +bin_opt_info
ifdef HIPE
	ERLC_OPTS += -smp +native
	TEST_ERLC_OPTS += -smp +native
endif

DIALYZER_OPTS = -Werror_handling -Wunmatched_returns

# Dependencies.

LOCAL_DEPS = crypto

DOC_DEPS = asciideck

TEST_DEPS = $(if $(CI_ERLANG_MK),ci.erlang.mk) base32 horse proper jsx \
	structured-header-tests uritemplate-tests
dep_base32 = git https://hub.fastgit.org/dnsimple/base32_erlang main
dep_horse = git https://hub.fastgit.org/ninenines/horse.git master
dep_jsx = git https://hub.fastgit.org/talentdeficit/jsx v2.10.0
dep_structured-header-tests = git https://hub.fastgit.org/httpwg/structured-header-tests e614583397e7f65e0082c0fff3929f32a298b9f2
dep_uritemplate-tests = git https://hub.fastgit.org/uri-templates/uritemplate-test master

# CI configuration.

dep_ci.erlang.mk = git https://hub.fastgit.org/ninenines/ci.erlang.mk master
DEP_EARLY_PLUGINS = ci.erlang.mk

AUTO_CI_OTP ?= OTP-21+
AUTO_CI_HIPE ?= OTP-LATEST
# AUTO_CI_ERLLVM ?= OTP-LATEST
AUTO_CI_WINDOWS ?= OTP-21+

# Hex configuration.

define HEX_TARBALL_EXTRA_METADATA
#{
	licenses => [<<"ISC">>],
	links => #{
		<<"Function reference">> => <<"https://ninenines.eu/docs/en/cowlib/2.11/manual/">>,
		<<"GitHub">> => <<"https://github.com/ninenines/cowlib">>,
		<<"Sponsor">> => <<"https://github.com/sponsors/essen">>
	}
}
endef

# Standard targets.

include erlang.mk

# Compile options.

TEST_ERLC_OPTS += +'{parse_transform, eunit_autoexport}' +'{parse_transform, horse_autoexport}'

# Mimetypes module generator.

GEN_URL = http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types
GEN_SRC = src/cow_mimetypes.erl.src
GEN_OUT = src/cow_mimetypes.erl

.PHONY: gen

gen:
	$(gen_verbose) cat $(GEN_SRC) \
		| head -n `grep -n "%% GENERATED" $(GEN_SRC) | cut -d : -f 1` \
		> $(GEN_OUT)
	$(gen_verbose) wget -qO - $(GEN_URL) \
		| grep -v ^# \
		| awk '{for (i=2; i<=NF; i++) if ($$i != "") { \
			split($$1, a, "/"); \
			print "all_ext(<<\"" $$i "\">>) -> {<<\"" \
				a[1] "\">>, <<\"" a[2] "\">>, []};"}}' \
		| sort \
		| uniq -w 25 \
		>> $(GEN_OUT)
	$(gen_verbose) cat $(GEN_SRC) \
		| tail -n +`grep -n "%% GENERATED" $(GEN_SRC) | cut -d : -f 1` \
		>> $(GEN_OUT)

# Performance testing.

ifeq ($(MAKECMDGOALS),perfs)
.NOTPARALLEL:
endif

.PHONY: perfs

perfs: test-build
	$(gen_verbose) erl -noshell -pa ebin -eval 'horse:app_perf($(PROJECT)), erlang:halt().'

# Prepare for the release.

prepare_tag:
	$(verbose) $(warning Hex metadata: $(HEX_TARBALL_EXTRA_METADATA))
	$(verbose) echo
	$(verbose) echo -n "Most recent tag:            "
	$(verbose) git tag --sort taggerdate | tail -n1
	$(verbose) git verify-tag `git tag --sort taggerdate | tail -n1`
	$(verbose) echo -n "MAKEFILE: "
	$(verbose) grep -m1 PROJECT_VERSION Makefile
	$(verbose) echo -n "APP:                 "
	$(verbose) grep -m1 vsn ebin/$(PROJECT).app | sed 's/	//g'
	$(verbose) echo
	$(verbose) echo "Dependencies:"
	$(verbose) grep ^DEPS Makefile || echo "DEPS ="
	$(verbose) grep ^dep_ Makefile || true
