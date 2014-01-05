# -*- Makefile -*-

all: all-langtags all-urls all-http all-mime all-dom all-css \
    all-encodings all-meta all-microdata

clean: clean-langtags clean-urls clean-http clean-mime clean-dom clean-css \
    clean-encodings clean-meta clean-microdata

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

## ------ Metadata ------

all-meta: data/specs.json
clean-meta:

data/specs.json: bin/specs.pl src/specs.txt src/spec-*.txt
	$(PERL) bin/specs.pl > $@

## ------ MIME types ------

all-mime: data/mime-types.json
clean-mime: 
	rm -fr local/sw-mime-types-xml* local/iana-mime-types.xml
	rm -fr local/iana-mime-type-suffixes.xml local/apache-mime-types

local/sw-mime-types-xml:
	$(WGET) -O $@-top "http://suika.suikawiki.org/~wakaba/wiki/sw/n/List%20of%20MIME%20types?format=xml"
	$(WGET) -O $@-suffix "http://suika.suikawiki.org/~wakaba/wiki/sw/n/structured%20syntax%20suffix?format=xml"
	$(WGET) -O $@-xapplication "http://suika.suikawiki.org/~wakaba/wiki/sw/n/x-application+%2A?format=xml"
	$(WGET) -O $@-application "http://suika.suikawiki.org/~wakaba/wiki/sw/n/application+%2A?format=xml"
	$(WGET) -O $@-audio "http://suika.suikawiki.org/~wakaba/wiki/sw/n/audio+%2A?format=xml"
	$(WGET) -O $@-chemical "http://suika.suikawiki.org/~wakaba/wiki/sw/n/chemical+%2A?format=xml"
	$(WGET) -O $@-xferrumhead "http://suika.suikawiki.org/~wakaba/wiki/sw/n/x-ferrum-head+%2A?format=xml"
	$(WGET) -O $@-xferrummenu "http://suika.suikawiki.org/~wakaba/wiki/sw/n/x-ferrum-menu+%2A?format=xml"
	$(WGET) -O $@-font "http://suika.suikawiki.org/~wakaba/wiki/sw/n/font+%2A?format=xml"
	$(WGET) -O $@-image "http://suika.suikawiki.org/~wakaba/wiki/sw/n/image+%2A?format=xml"
	$(WGET) -O $@-inode "http://suika.suikawiki.org/~wakaba/wiki/sw/n/inode+%2A?format=xml"
	$(WGET) -O $@-math "http://suika.suikawiki.org/~wakaba/wiki/sw/n/math+%2A?format=xml"
	$(WGET) -O $@-message "http://suika.suikawiki.org/~wakaba/wiki/sw/n/message+%2A?format=xml"
	$(WGET) -O $@-model "http://suika.suikawiki.org/~wakaba/wiki/sw/n/model+%2A?format=xml"
	$(WGET) -O $@-multipart "http://suika.suikawiki.org/~wakaba/wiki/sw/n/multipart+%2A?format=xml"
	$(WGET) -O $@-plugin "http://suika.suikawiki.org/~wakaba/wiki/sw/n/plugin+%2A?format=xml"
	$(WGET) -O $@-xpostpet "http://suika.suikawiki.org/~wakaba/wiki/sw/n/x-postpet+%2A?format=xml"
	$(WGET) -O $@-text "http://suika.suikawiki.org/~wakaba/wiki/sw/n/text+%2A?format=xml"
	$(WGET) -O $@-vector "http://suika.suikawiki.org/~wakaba/wiki/sw/n/vector+%2A?format=xml"
	$(WGET) -O $@-video "http://suika.suikawiki.org/~wakaba/wiki/sw/n/video+%2A?format=xml"
	$(WGET) -O $@-windows "http://suika.suikawiki.org/~wakaba/wiki/sw/n/windows+%2A?format=xml"
	$(WGET) -O $@-xworld "http://suika.suikawiki.org/~wakaba/wiki/sw/n/x-world+%2A?format=xml"
	$(WGET) -O $@-xgi "http://suika.suikawiki.org/~wakaba/wiki/sw/n/xgi+%2A?format=xml"
	touch $@

local/iana-mime-types.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/media-types/media-types.xml
local/iana-mime-type-suffixes.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/media-type-structured-suffix/media-type-structured-suffix.xml
local/iana-mime-type-provisional.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/provisional-standard-media-types/provisional-standard-media-types.xml

local/apache-mime-types:
	$(WGET) -O $@ http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types

data/mime-types.json: bin/mime-types.pl \
    local/sw-mime-types-xml local/iana-mime-types.xml \
    local/iana-mime-type-suffixes.xml local/apache-mime-types \
    src/mime-types.txt local/iana-mime-type-provisional.xml src/mime.types
	$(PERL) bin/mime-types.pl > $@

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

all-http: data/http-status-codes.json data/http-methods.json

clean-http:
	rm -fr local/sw-http-statuses.xml local/sw-http-methods.xml
	rm -fr local/iana-http-statuses.xml
	rm -fr local/iana-rtsp.xml local/iana-sip.xml

local/sw-http-statuses.xml:
	$(WGET) -O $@ "http://suika.suikawiki.org/~wakaba/wiki/sw/n/List%20of%20HTTP%20status%20codes?format=xml"
local/sw-http-methods.xml:
	$(WGET) -O $@ "http://suika.suikawiki.org/~wakaba/wiki/sw/n/List%20of%20HTTP%20methods?format=xml"
local/iana-http-statuses.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/http-status-codes/http-status-codes.xml
local/iana-rtsp.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/rtsp-parameters/rtsp-parameters.xml
local/iana-sip.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/sip-parameters/sip-parameters.xml

data/http-status-codes.json: \
    local/sw-http-statuses.xml local/iana-http-statuses.xml \
    local/iana-rtsp.xml local/iana-sip.xml \
    bin/http-status-codes.pl
	$(PERL) bin/http-status-codes.pl > $@
data/http-methods.json: \
    local/sw-http-methods.xml \
    local/iana-rtsp.xml local/iana-sip.xml \
    bin/http-methods.pl
	$(PERL) bin/http-methods.pl > $@

## ------ Encodings ------

all-encodings: data/encodings.json data/encoding-indexes.json
clean-encodings:
	rm -fr local/encodings.json local/indexes.json

data/encodings.json: bin/encodings.pl src/locale-default-encodings.txt \
    local/encodings.json
	$(PERL) bin/encodings.pl > $@
data/encoding-indexes.json: local/indexes.json
	cp $< $@

local/encodings.json:
	$(WGET) -O $@ http://encoding.spec.whatwg.org/encodings.json
local/indexes.json:	
	$(WGET) -O $@ http://encoding.spec.whatwg.org/indexes.json

## ------ DOM/HTML ------

all-dom: data/dom.json data/elements.json
clean-dom:
	rm -fr local/html local/html-extracted.json local/html-status.xml
	rm -fr local/obsvocab.html

data/dom.json: bin/dom.pl src/dom-nodes.txt
	$(PERL) bin/dom.pl > $@

data/elements.json: bin/elements.pl src/element-interfaces.txt \
    local/html-extracted.json src/elements.txt local/html-status.xml \
    src/attr-types.txt local/obsvocab.html
	$(PERL) bin/elements.pl > $@

## Not invoked by all and all-dom
data/isindex-prompt.json: bin/isindex-prompt.pl
	$(PERL) bin/isindex-prompt.pl > $@

local/html:
	cd local && $(WGET) -m -np http://www.whatwg.org/specs/web-apps/current-work/multipage/
	touch $@
local/html-extracted.json: local/html bin/extract-html-standard.pl
	$(PERL) bin/extract-html-standard.pl > $@
local/html-status.xml:
	$(WGET) -O $@ http://www.whatwg.org/specs/web-apps/current-work/status.cgi?action=get-all-annotations
local/obsvocab.html:
	$(WGET) -O $@ http://suika.suikawiki.org/www/markup/html/exts/manakai-obsvocab

## ------ Microdata ------

all-microdata: data/microdata.json
clean-microdata:
	#rm -fr local/data-vocabulary/files

src/microdata-dv.json: bin/microdata-dv.pl local/data-vocabulary/files
	$(PERL) bin/microdata-dv.pl > $@

data/microdata.json: bin/microdata.pl src/microdata-*.txt # and src/microdata-dv.json
	$(PERL) bin/microdata.pl > $@

local/data-vocabulary/files:
	mkdir -p local/data-vocabulary
	for x in itemtype itemprop Event Geo Address Organization Person \
	         Product Review Review-aggregate Breadcrumb \
	         Offer Offer-aggregate; do \
	  $(WGET) -O local/data-vocabulary/$$x.html http://www.data-vocabulary.org/$$x/; \
	done
	touch $@

## ------ CSS ------

all-css: data/css.json
clean-css:

data/css.json: bin/css.pl src/css-at-rules.txt
	$(PERL) bin/css.pl > $@

## ------ Validation ------

test:
	# (placeholder)
