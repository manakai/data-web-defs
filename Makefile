all: all-langtags all-urls all-http all-mime all-dom all-css \
    all-encodings all-meta all-microdata all-js

clean: clean-langtags clean-urls clean-http clean-mime clean-dom clean-css \
    clean-encodings clean-meta clean-microdata clean-js \
    clean-json-ps

WGET = wget
CURL = curl
GIT = git
PERL = ./perl
PROVE = ./prove

updatenightly: update-submodules dataautoupdate

update-submodules:
	$(CURL) https://gist.githubusercontent.com/motemen/667573/raw/git-submodule-track | sh
	$(GIT) add bin/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config

dataautoupdate: clean deps all
	$(GIT) add data/*.json

## ------ Setup ------

deps: git-submodules pmbp-install json-ps

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
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

json-ps: local/perl-latest/pm/lib/perl5/JSON/PS.pm
clean-json-ps:
	rm -fr local/perl-latest/pm/lib/perl5/JSON/PS.pm
local/perl-latest/pm/lib/perl5/JSON/PS.pm:
	mkdir -p local/perl-latest/pm/lib/perl5/JSON
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

local/bin/jq:
	mkdir -p local/bin
	$(WGET) -O $@ http://stedolan.github.io/jq/download/linux64/jq
	chmod u+x $@

## ------ Metadata ------

all-meta: data/specs.json
clean-meta:

data/specs.json: bin/specs.pl src/specs.txt src/spec-*.txt
	$(PERL) bin/specs.pl > $@

## ------ MIME types ------

all-mime: data/mime-types.json
clean-mime: 
	rm -fr local/sw-mime-types-xml*
	rm -fr local/iana-mime-type* local/apache-mime-types

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
	$(WGET) -O $@ "http://suika.suikawiki.org/~wakaba/wiki/sw/n/List%20of%20URL%20schemes?format=xml"
local/sw-url-schemes.txt: local/sw-url-schemes.xml \
    bin/extract-sw-url-schemes.pl
	$(PERL) bin/extract-sw-url-schemes.pl < $< > $@

local/iana-url-schemes.xml:
	$(WGET) -O $@ http://www.iana.org/assignments/uri-schemes/uri-schemes.xml
local/iana-url-schemes.txt: local/iana-url-schemes.xml \
    bin/extract-iana-url-schemes.pl
	$(PERL) bin/extract-iana-url-schemes.pl < $< > $@

data/url-schemes.json: bin/url-schemes.pl \
    src/url-schemes.txt local/sw-url-schemes.txt local/iana-url-schemes.txt \
    src/url-schemes-iphone.txt src/url-schemes-iphone-args.txt \
    src/url-schemes-windowsphone.txt
	$(PERL) bin/url-schemes.pl

## ------ Language tags ------

all-langtags: data/langtags.json
clean-langtags:
	rm -f local/langtags/subtag-registry local/langtags/ext-registry
	rm -f local/langtags/cldr-bcp47/update
	rm -fr local/chars-*.json

local/langtags/subtag-registry:
	mkdir -p local/langtags
	$(WGET) http://www.iana.org/assignments/language-subtag-registry -O $@
local/langtags/ext-registry:
	mkdir -p local/langtags
	$(WGET) http://www.iana.org/assignments/language-tag-extensions-registry -O $@
local/langtags/cldr-bcp47:
	mkdir -p local/langtags/cldr-bcp47
	touch $@/update
local/langtags/cldr-bcp47/update: local/langtags/cldr-bcp47
	cd local/langtags/cldr-bcp47 && \
	$(CURL) http://www.unicode.org/repos/cldr/trunk/common/bcp47/ | \
	perl -n -e 'print "$$1\n" if /([A-Za-z0-9_.-]+\.xml)/' | \
	xargs -i% -- $(WGET) -O % http://www.unicode.org/repos/cldr/trunk/common/bcp47/%
	touch $@

local/chars-scripts.json:
	$(WGET) -O $@ https://raw.github.com/manakai/data-chars/master/data/scripts.json

data/langtags.json: bin/langtags.pl \
  local/langtags/subtag-registry local/langtags/ext-registry \
  local/langtags/cldr-bcp47/update \
  local/chars-scripts.json
	$(PERL) bin/langtags.pl \
	  local/langtags/subtag-registry local/langtags/ext-registry \
	  local/langtags/cldr-bcp47/*.xml > $@

## ------ HTTP ------

all-http: data/http-status-codes.json data/http-methods.json \
    data/headers.json

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
    bin/http-methods.pl src/http-methods.txt
	$(PERL) bin/http-methods.pl > $@
data/headers.json: bin/headers.pl src/http-headers.txt src/http-protocols.txt \
    src/http-content-codings.txt src/http-transfer-codings.txt
	$(PERL) bin/headers.pl > $@

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

## ------ JavaScript ------

all-js: data/js-lexical.json
clean-js:

data/js-lexical.json: bin/js-lexical.pl
	$(PERL) bin/js-lexical.pl > $@

## ------ DOM/HTML ------

all-dom: data/dom.json data/elements.json data/aria.json data/dom-perl.json \
    data/html-syntax.json data/xhtml-charrefs.dtd data/xml-syntax.json \
    data/html-tokenizer-expanded.json \
    data/html-charrefs.json data/browsers.json data/rdf.json \
    data/xml-datatypes.json data/xpath.json data/webidl.json \
    data/html-tree-constructor-expanded.json
clean-dom:
	rm -fr local/html local/html-extracted.json local/html-status.xml
	rm -fr local/obsvocab.html local/aria.rdf
	rm -fr data/xhtml-charrefs.dtd data/html-charrefs.json
	rm -fr local/xml5-spec.html local/schemaorg*
	rm -fr local/dom.html local/domparsing.html
	rm -fr local/www.whatwg.org

data/dom.json: bin/dom.pl src/dom-nodes.txt local/html-extracted.json \
  local/idl-extracted.json \
  src/idl/*.idl
	$(PERL) bin/dom.pl > $@

data/elements.json: bin/elements.pl src/element-interfaces.txt \
    local/html-extracted.json src/elements.txt local/html-status.xml \
    src/attr-types.txt local/obsvocab.html data/aria.json \
    local/element-aria.json src/html-obsolete.txt
	$(PERL) bin/elements.pl > $@

## Not invoked by all and all-dom
data/isindex-prompt.json: bin/isindex-prompt.pl
	$(PERL) bin/isindex-prompt.pl > $@

local/html:
	cd local && ($(WGET) -m -np http://www.whatwg.org/specs/web-apps/current-work/multipage/ || true)
	touch $@
local/html-extracted.json: local/html bin/extract-html-standard.pl
	$(PERL) bin/extract-html-standard.pl > $@
local/html-status.xml:
	$(WGET) -O $@ http://www.whatwg.org/specs/web-apps/current-work/status.cgi?action=get-all-annotations
local/obsvocab.html:
	$(WGET) -O $@ http://suika.suikawiki.org/www/markup/html/exts/manakai-obsvocab

local/aria.rdf:
	$(WGET) -O $@ http://www.w3.org/WAI/ARIA/schemata/aria-1.rdf

data/aria.json: local/aria.rdf bin/ariardf.pl
	$(PERL) bin/ariardf.pl > $@

local/element-aria.json: src/element-aria.txt bin/ariaelements.pl \
    data/aria.json
	$(PERL) bin/ariaelements.pl > $@

data/dom-perl.json: src/dom-perl-methods.txt bin/dom-perl.pl
	$(PERL) bin/dom-perl.pl > $@

data/html-charrefs.json:
	$(WGET) -O $@ http://www.whatwg.org/specs/web-apps/current-work/entities.json

data/xhtml-charrefs.dtd: local/html-extracted.json

data/html-syntax.json: bin/html-syntax.pl local/html-tokenizer.json \
    local/html-tokenizer-charrefs.json \
    local/html-tokenizer-charrefs-jump.json \
    local/html-tree.json
	$(PERL) bin/html-syntax.pl > $@
data/xml-syntax.json: bin/xml-syntax.pl local/xml-tokenizer.json
	$(PERL) bin/xml-syntax.pl > $@
data/html-tokenizer-expanded.json: data/html-syntax.json \
    bin/tokenizer-variants.pl
	$(PERL) bin/tokenizer-variants.pl < data/html-syntax.json > $@
	!(grep reconsume $@ > /dev/null)
data/html-tree-constructor-expanded.json: data/html-syntax.json \
    bin/expand-tree-constructor.pl
	$(PERL) bin/expand-tree-constructor.pl < data/html-syntax.json > $@
	!(grep '"tree_steps"' $@ > /dev/null)
	!(grep '"CHAR" :' $@ > /dev/null)
	!(grep '"insert a character"' $@ > /dev/null)

local/html-tokenizer.json: bin/extract-html-tokenizer.pl local/html
	$(PERL) bin/extract-html-tokenizer.pl local/www.whatwg.org/specs/web-apps/current-work/multipage/syntax.html > $@
local/html-tokenizer-charrefs.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/charrefs.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/charrefs.html > $@
local/html-tokenizer-charrefs-jump.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/charrefs-jump.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/charrefs-jump.html > $@

local/xml5-spec.html:
	$(WGET) -O $@ https://dvcs.w3.org/hg/xml-er/raw-file/3fb2e443ca50/Overview.src.html

local/xml-tokenizer.json: bin/extract-html-tokenizer.pl local/xml5-spec.html
	$(PERL) bin/extract-html-tokenizer.pl local/xml5-spec.html > $@

local/html-tree.json: bin/extract-html-tree.pl local/html
	$(PERL) bin/extract-html-tree.pl local/www.whatwg.org/specs/web-apps/current-work/multipage/syntax.html > $@
	!(grep '"DESC"' $@ > /dev/null)
	!(grep '"COND"' $@ > /dev/null)
	!(grep '"misc"' $@ > /dev/null)
	!(grep '"IF"' $@ > /dev/null)
	!(grep '"TARGET"' $@ > /dev/null)
	!(grep '"PROCESS"' $@ > /dev/null)
	!(grep '"SAME-AS"' $@ > /dev/null)
	!(grep '"LABEL"' $@ > /dev/null)
	!(grep '"LOOP"' $@ > /dev/null)
	!(grep '"USING-THE-RULES-FOR"' $@ > /dev/null)

data/browsers.json: bin/browsers.pl src/task-sources.txt
	$(PERL) bin/browsers.pl > $@

data/rdf.json: bin/rdf.pl
	$(PERL) bin/rdf.pl > $@

data/xml-datatypes.json: bin/xml-datatypes.pl
	$(PERL) bin/xml-datatypes.pl > $@

data/xpath.json: bin/xpath.pl src/xpath-functions.txt
	$(PERL) bin/xpath.pl > $@

data/webidl.json: bin/webidl.pl
	$(PERL) bin/webidl.pl > $@

local/dom.html:
	$(WGET) -O $@ http://dom.spec.whatwg.org/
local/domparsing.html:
	$(WGET) -O $@ http://domparsing.spec.whatwg.org/
local/xhr.html:
	$(WGET) -O $@ http://xhr.spec.whatwg.org/
local/idl-extracted.json: local/dom.html local/domparsing.html \
    local/xhr.html \
    bin/extract-idls.pl
	$(PERL) bin/extract-idls.pl > $@

## ------ Microdata ------

all-microdata: data/microdata.json data/ogp.json
clean-microdata:
	#rm -fr local/data-vocabulary/files
	rm -fr local/schemaorg.html

src/microdata-dv.json: bin/microdata-dv.pl local/data-vocabulary/files
	$(PERL) bin/microdata-dv.pl > $@

data/microdata.json: bin/microdata.pl src/microdata-*.txt \
    local/schemaorg.json local/schemaorg-wsa.json
	# and src/microdata-dv.json intermediate/rec20-common-codes.txt
	$(PERL) bin/microdata.pl > $@

local/data-vocabulary/files:
	mkdir -p local/data-vocabulary
	for x in itemtype itemprop Event Geo Address Organization Person \
	         Product Review Review-aggregate Breadcrumb \
	         Offer Offer-aggregate Recipe; do \
	  $(WGET) -O local/data-vocabulary/$$x.html http://www.data-vocabulary.org/$$x/; \
	done
	touch $@

local/schemaorg.html:
	$(WGET) -O $@ http://schema.org/docs/full_md.html
local/schemaorg.rdfa:
	$(WGET) -O $@ http://schema.org/docs/schema_org_rdfa.html
local/schemaorg.json: local/schemaorg.rdfa bin/microdata-schemaorg.pl
	$(PERL) bin/microdata-schemaorg.pl > $@

local/schemaorg-wsa.html:
	$(WGET) -O $@ http://www.w3.org/wiki/WebSchemas/Accessibility
local/schemaorg-wsa.json: local/schemaorg-wsa.html bin/extract-schemaorg-wsa.pl
	$(PERL) bin/extract-schemaorg-wsa.pl > $@

local/xls2txt:
	$(GIT) clone https://github.com/hroptatyr/xls2txt.git $@
	cd $@ && $(MAKE)
local/xls2txt/xls2txt: local/xls2txt

local/rec20.xls:
	$(WGET) -O $@ http://www.unece.org/fileadmin/DAM/cefact/recommendations/rec20/rec20_Rev9e_2014.xls
local/rec20-1.tsv: local/xls2txt/xls2txt local/rec20.xls
	local/xls2txt/xls2txt -n 1 local/rec20.xls > $@
local/rec20-common-codes.json: local/rec20-1.tsv bin/extract-rec20.pl
	$(PERL) bin/extract-rec20.pl < local/rec20-1.tsv > $@
intermediate/rec20-common-codes.txt: local/rec20-common-codes.json \
    bin/common-codes.pl
	$(PERL) bin/common-codes.pl < $< > $@

data/ogp.json: bin/ogp.pl src/ogp.txt
	$(PERL) bin/ogp.pl > $@

## ------ CSS ------

all-css: data/css.json data/css-colors.json data/css-fonts.json
clean-css:

data/css.json: bin/css.pl src/css-at-rules.txt
	$(PERL) bin/css.pl > $@

data/css-colors.json: bin/css-colors.pl
	$(PERL) bin/css-colors.pl > $@

data/css-fonts.json: bin/css-fonts.pl
	$(PERL) bin/css-fonts.pl > $@

## ------ Validation ------

test: test-deps test-main

test-deps: deps local/bin/jq

test-main:
	$(PROVE) t/*.t
	!(grep '"_errors"' data/elements.json > /dev/null)
