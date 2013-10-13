# -*- Makefile -*-

all: all-langtags

clean: clean-langtags

WGET = wget
GIT = git
SVN = svn
PERL = ./perl

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl

## ------ Language tags ------

all-langtags: data/langtags.json
clean-langtags:
	rm -f local/langtags/subtag-registry local/langtags/ext-registry
	rm -f local/langtags/cldr-bcp47/update

local/langtags/subtag-registry:
	mkdir -p local/langtags
	$(WGET) http://www.iana.org/assignments/language-subtag-registry -O $@
local/langtags/ext-registry:
	mkdir -p local/langtags
	$(WGET) http://www.iana.org/assignments/language-tag-extensions-registry -O $@
local/langtags/cldr-bcp47:
	mkdir -p local/langtags
	ls $@ || $(SVN) co http://www.unicode.org/repos/cldr/trunk/common/bcp47 $@
	touch $@/update
local/langtags/cldr-bcp47/update:
	cd local/langtags/cldr-bcp47 && $(SVN) update
	touch $@

data/langtags.json: bin/langtags.pl \
  local/langtags/subtag-registry local/langtags/ext-registry \
  local/langtags/cldr-bcp47/update \
  local/langtags/cldr-bcp47/calendar.xml \
  local/langtags/cldr-bcp47/collation.xml \
  local/langtags/cldr-bcp47/currency.xml \
  local/langtags/cldr-bcp47/number.xml \
  local/langtags/cldr-bcp47/timezone.xml \
  local/langtags/cldr-bcp47/variant.xml \
  local/langtags/cldr-bcp47/transform.xml
	$(PERL) bin/langtags.pl \
	  local/langtags/subtag-registry local/langtags/ext-registry \
	  local/langtags/cldr-bcp47/*.xml > $@
