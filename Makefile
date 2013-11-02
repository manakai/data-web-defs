# -*- Makefile -*-

all: all-langtags all-urls all-http

clean: clean-langtags clean-urls clean-http

WGET = wget
GIT = git
SVN = svn
PERL = ./perl

dataautoupdate: clean deps all
	$(GIT) add data/*.json

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

## ------ URLs ------

all-urls: data/url-schemes.json
clean-urls:
	rm -fr local/sw-url-schemes.*
	rm -fr local/iana-url-schemes.*

local/sw-url-schemes.xml:
	$(WGET) -O $@ "http://suika.suikawiki.org/~wakaba/wiki/sw/n/List%20of%20URL%20schemes?mode=xml"
local/sw-url-schemes.txt: local/sw-url-schemes.xml \
    bin/extract-sw-url-schemes.pl
	$(PERL) bin/extract-sw-url-schemes.pl < $< > $@

local/iana-url-schemes.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/uri-schemes/uri-schemes.xml
local/iana-url-schemes.txt: local/iana-url-schemes.xml
	$(PERL) bin/extract-iana-url-schemes.pl < $< > $@

data/url-schemes.json: bin/url-schemes.pl \
    src/url-schemes.txt local/sw-url-schemes.txt local/iana-url-schemes.txt
	$(PERL) bin/url-schemes.pl

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
local/langtags/cldr-bcp47/update: local/langtags/cldr-bcp47
	cd local/langtags/cldr-bcp47 && $(SVN) update
	touch $@

data/langtags.json: bin/langtags.pl \
  local/langtags/subtag-registry local/langtags/ext-registry \
  local/langtags/cldr-bcp47/update \
  local/langtags/cldr-bcp47/*.xml
	$(PERL) bin/langtags.pl \
	  local/langtags/subtag-registry local/langtags/ext-registry \
	  local/langtags/cldr-bcp47/*.xml > $@

## ------ HTTP ------

all-http: data/http-status-codes.json

clean-http:
	rm -fr local/sw-http-statuses.xml local/iana-http-statuses.xml
	rm -fr local/iana-rtsp-statuses.xml local/iana-sip-statuses.xml

local/sw-http-statuses.xml:
	$(WGET) -O $@ "http://suika.suikawiki.org/~wakaba/wiki/sw/n/List%20of%20HTTP%20status%20codes?format=xml"
local/iana-http-statuses.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/http-status-codes/http-status-codes.xml
local/iana-rtsp-statuses.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/rtsp-parameters/rtsp-parameters.xml
local/iana-sip-statuses.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/sip-parameters/sip-parameters.xml

data/http-status-codes.json: \
    local/sw-http-statuses.xml local/iana-http-statuses.xml \
    local/iana-rtsp-statuses.xml local/iana-sip-statuses.xml \
    bin/http-status-codes.pl
	$(PERL) bin/http-status-codes.pl > $@

## ------ Validation ------

test:
	# (placeholder)
