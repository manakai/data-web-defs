all: data

data: all-langtags all-urls all-http all-mime all-dom all-css \
    all-encodings all-meta all-microdata all-js

clean: clean-langtags clean-urls clean-http clean-mime clean-dom clean-css \
    clean-encodings clean-meta clean-microdata clean-js \
    clean-json-ps

WGET = wget
CURL = curl
SAVEURL = $(CURL) -s -S -L -o
SAVETREE = $(WGET) --no-check-certificate -m -np
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
	$(GIT) add data intermediate

## ------ Setup ------

deps: git-submodules pmbp-install json-ps

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(SAVEURL) $@ https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl
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
	$(SAVEURL) $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

local/bin/jq:
	mkdir -p local/bin
	$(SAVEURL) $@ https://stedolan.github.io/jq/download/linux64/jq
	chmod u+x $@

## ------ Metadata ------

all-meta: data/specs.json
clean-meta:

data/specs.json: bin/specs.pl src/specs.txt src/spec-*.txt
	$(PERL) bin/specs.pl > $@

## ------ MIME types ------

all-mime: data/mime-types.json data/file-name-extensions.json \
    data/mime-sniffing.json
clean-mime: 
	rm -fr local/sw-mime-types-xml*
	rm -fr local/intermediate-mime-type-provisional
	rm -fr local/iana-mime-type* local/apache-mime-types

local/sw-mime-types-xml:
	$(SAVEURL) $@-top "https://wiki.suikawiki.org/n/List%20of%20MIME%20types?format=xml"
	$(SAVEURL) $@-suffix "https://wiki.suikawiki.org/n/structured%20syntax%20suffix?format=xml"
	$(SAVEURL) $@-xapplication "https://wiki.suikawiki.org/n/x-application%2F%2A?format=xml"
	$(SAVEURL) $@-application "https://wiki.suikawiki.org/n/application%2F%2A?format=xml"
	$(SAVEURL) $@-audio "https://wiki.suikawiki.org/n/audio%2F%2A?format=xml"
	$(SAVEURL) $@-chemical "https://wiki.suikawiki.org/n/chemical%2F%2A?format=xml"
	$(SAVEURL) $@-xferrumhead "https://wiki.suikawiki.org/n/x-ferrum-head%2F%2A?format=xml"
	$(SAVEURL) $@-xferrummenu "https://wiki.suikawiki.org/n/x-ferrum-menu%2F%2A?format=xml"
	$(SAVEURL) $@-font "https://wiki.suikawiki.org/n/font%2F%2A?format=xml"
	$(SAVEURL) $@-image "https://wiki.suikawiki.org/n/image%2F%2A?format=xml"
	$(SAVEURL) $@-inode "https://wiki.suikawiki.org/n/inode%2F%2A?format=xml"
	$(SAVEURL) $@-math "https://wiki.suikawiki.org/n/math%2F%2A?format=xml"
	$(SAVEURL) $@-message "https://wiki.suikawiki.org/n/message%2F%2A?format=xml"
	$(SAVEURL) $@-model "https://wiki.suikawiki.org/n/model%2F%2A?format=xml"
	$(SAVEURL) $@-multipart "https://wiki.suikawiki.org/n/multipart%2F%2A?format=xml"
	$(SAVEURL) $@-plugin "https://wiki.suikawiki.org/n/plugin%2F%2A?format=xml"
	$(SAVEURL) $@-xpostpet "https://wiki.suikawiki.org/n/x-postpet%2F%2A?format=xml"
	$(SAVEURL) $@-text "https://wiki.suikawiki.org/n/text%2F%2A?format=xml"
	$(SAVEURL) $@-vector "https://wiki.suikawiki.org/n/vector%2F%2A?format=xml"
	$(SAVEURL) $@-video "https://wiki.suikawiki.org/n/video%2F%2A?format=xml"
	$(SAVEURL) $@-windows "https://wiki.suikawiki.org/n/windows%2F%2A?format=xml"
	$(SAVEURL) $@-xworld "https://wiki.suikawiki.org/n/x-world%2F%2A?format=xml"
	$(SAVEURL) $@-xgi "https://wiki.suikawiki.org/n/xgi%2F%2A?format=xml"
	$(SAVEURL) $@-fitness "https://wiki.suikawiki.org/n/vnd.google.fitness.data_type%2F%2A?format=xml"
	$(SAVEURL) $@-cursor "https://wiki.suikawiki.org/n/vnd.android.cursor.dir%2F%2A?format=xml"
	touch $@

local/iana/mime-types.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/media-types/media-types.xml
local/iana/mime-type-suffixes.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/media-type-structured-suffix/media-type-structured-suffix.xml
local/iana/mime-type-provisional.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/provisional-standard-media-types/provisional-standard-media-types.xml

intermediate/mime-type-provisional.json: bin/mime-type-provisional.pl \
    local/iana/mime-type-provisional.json \
    local/intermediate-mime-type-provisional
	$(PERL) bin/mime-type-provisional.pl

local/intermediate-mime-type-provisional:
	touch $@

local/apache-mime-types:
	$(SAVEURL) $@ https://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types
local/jshttp-mime-types.json:
	$(SAVEURL) $@ https://raw.githubusercontent.com/jshttp/mime-db/master/db.json
local/mime-types-data.json:
	$(SAVEURL) $@ https://raw.githubusercontent.com/mime-types/mime-types-data/master/data/mime-types.json

local/wpa-mime-types.json: intermediate/wpa-mime-types.json \
    bin/wpa-mime-types.pl src/mime-type-iana-template.txt
	$(PERL) bin/wpa-mime-types.pl $< > $@

data/mime-types.json: bin/mime-types.pl \
    local/sw-mime-types-xml local/iana/mime-types.json \
    local/iana/mime-type-suffixes.json local/apache-mime-types \
    src/mime-types.txt local/iana/mime-type-provisional.json src/mime.types \
    intermediate/mime-type-provisional.json local/jshttp-mime-types.json \
    src/mime-type-related.txt local/wpa-mime-types.json \
    local/mime-types-data.json
	$(PERL) bin/mime-types.pl

data/file-name-extensions.json: data/mime-types.json

data/mime-sniffing.json: bin/mime-sniffing.pl
	$(PERL) $< > $@

## ------ URLs ------

all-urls: data/url-schemes.json data/tlds.json data/psl-tests.json
clean-urls:
	rm -fr local/sw-url-schemes.*
	rm -fr local/iana-url-schemes.*
	rm -fr local/mozilla-prefs.js

local/sw-url-schemes.xml:
	$(SAVEURL) $@ "https://wiki.suikawiki.org/n/List%20of%20URL%20schemes?format=xml"
local/sw-url-schemes.txt: local/sw-url-schemes.xml \
    bin/extract-sw-url-schemes.pl
	$(PERL) bin/extract-sw-url-schemes.pl < $< > $@

local/iana/url-schemes.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/uri-schemes/uri-schemes.xml

src/url-schemes-ihasapp.json:
	$(SAVEURL) $@ https://raw.githubusercontent.com/danielamitay/iHasApp/master/iHasApp/schemeApps.json

data/url-schemes.json: bin/url-schemes.pl \
    src/url-schemes.txt local/sw-url-schemes.txt local/iana/url-schemes.json \
    src/url-schemes-iphone.txt src/url-schemes-iphone-args.txt \
    src/url-schemes-windowsphone.txt src/url-schemes-ihasapp.json
	$(PERL) bin/url-schemes.pl

local/iana-tlds.txt:
	$(SAVEURL) $@ https://data.iana.org/TLD/tlds-alpha-by-domain.txt
local/psl.txt:
	$(SAVEURL) $@ https://raw.githubusercontent.com/publicsuffix/list/master/public_suffix_list.dat
local/psl-test.txt:
	$(SAVEURL) $@ https://raw.githubusercontent.com/publicsuffix/list/master/tests/test_psl.txt

local/mozilla-prefs.js:
	$(SAVEURL) $@ https://raw.githubusercontent.com/mozilla/gecko-dev/master/modules/libpref/init/all.js
local/mozilla-idn-whitelist.txt: local/mozilla-prefs.js
	perl -e 'while (<>) { #\
	  if (m{pref\("network.IDN.whitelist.([0-9a-zA-Z-]+)", true\)}) { #\
	    print lc $$1, "\n"; #\
	  } #\
	}' $< > $@

data/tlds.json: local/iana-tlds.txt src/tld-additional.txt bin/tlds.pl \
    local/mozilla-idn-whitelist.txt local/psl.txt
	$(PERL) bin/tlds.pl > $@
data/psl-tests.json: bin/psl-tests.pl local/psl-test.txt
	$(PERL) $< > $@

## ------ Language tags ------

all-langtags: data/langtags.json
clean-langtags:
	rm -f local/langtags/subtag-registry local/langtags/ext-registry
	rm -f local/langtags/cldr-bcp47/update
	rm -fr local/chars-*.json

local/langtags/subtag-registry:
	mkdir -p local/langtags
	$(WGET) https://www.iana.org/assignments/language-subtag-registry -O $@
local/langtags/ext-registry:
	mkdir -p local/langtags
	$(WGET) https://www.iana.org/assignments/language-tag-extensions-registry -O $@
local/langtags/cldr-bcp47:
	mkdir -p local/langtags/cldr-bcp47
	touch $@/update
local/langtags/cldr-bcp47/update: local/langtags/cldr-bcp47
	cd local/langtags/cldr-bcp47 && \
	$(CURL) https://www.unicode.org/repos/cldr/trunk/common/bcp47/ | \
	perl -n -e 'print "$$1\n" if /([A-Za-z0-9_.-]+\.xml)/' | \
	xargs -i% -- $(SAVEURL) % https://www.unicode.org/repos/cldr/trunk/common/bcp47/%
	touch $@

local/chars-scripts.json:
	$(SAVEURL) $@ https://raw.githubusercontent.com/manakai/data-chars/master/data/scripts.json

data/langtags.json: bin/langtags.pl \
  local/langtags/subtag-registry local/langtags/ext-registry \
  local/langtags/cldr-bcp47/update \
  local/chars-scripts.json
	$(PERL) bin/langtags.pl \
	  local/langtags/subtag-registry local/langtags/ext-registry \
	  local/langtags/cldr-bcp47/*.xml > $@

## ------ HTTP ------

all-http: data/http-status-codes.json data/http-methods.json \
    data/headers.json data/digests.json data/http-frames.json \
    data/tls.json data/fetch.json

clean-http:
	rm -fr local/sw-http-statuses.xml local/sw-http-methods.xml
	rm -fr local/iana-http-statuses.xml
	rm -fr local/iana/rtsp.xml local/iana/sip.xml
	rm -fr local/iana/http*.xml local/mozilla-ciphers.html

local/sw-http-statuses.xml:
	$(SAVEURL) $@ "https://wiki.suikawiki.org/n/List%20of%20HTTP%20status%20codes?format=xml"
local/sw-http-methods.xml:
	$(SAVEURL) $@ "https://wiki.suikawiki.org/n/List%20of%20HTTP%20methods?format=xml"
local/iana-http-statuses.xml:
	$(SAVEURL) $@ https://www.iana.org/assignments/http-status-codes/http-status-codes.xml
local/iana/rtsp.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/rtsp-parameters/rtsp-parameters.xml
local/iana/sip.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/sip-parameters/sip-parameters.xml
local/iana/http-methods.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-methods/http-methods.xml
local/iana/http-methods.json: local/iana/http-methods.xml bin/ianaxml2json.pl
	$(PERL) bin/ianaxml2json.pl $< > $@

local/iana/http-protocols.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-upgrade-tokens/http-upgrade-tokens.xml
local/iana/http-protocols.json: local/iana/http-protocols.xml \
    bin/ianaxml2json.pl
	$(PERL) bin/ianaxml2json.pl $< > $@

local/iana/http-parameters.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-parameters/http-parameters.xml
local/iana/http-cache-control.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-cache-directives/http-cache-directives.xml
local/iana/http-warn-codes.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-warn-codes/http-warn-codes.xml
local/iana/http-auth-schemes.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-authschemes/http-authschemes.xml
local/iana/cont-disp.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/cont-disp/cont-disp.xml
local/iana/http-ims.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/inst-man-values/inst-man-values.xml
local/iana/http-digests.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-dig-alg/http-dig-alg.xml
local/iana/headers.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/message-headers/message-headers.xml
local/iana/fcast.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/fcast/fcast.xml
local/iana/ni.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/named-information/named-information.xml
local/iana/http2.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http2-parameters/http2-parameters.xml
local/iana/ws.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/websocket/websocket.xml
local/iana/tls.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/tls-parameters/tls-parameters.xml
local/iana/tls-exts.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xml
local/iana/alt-svc.xml:
	mkdir -p local/iana
	$(SAVEURL) $@ https://www.iana.org/assignments/http-alt-svc-parameters/http-alt-svc-parameters.xml

local/iana/%.json: local/iana/%.xml bin/ianaxml2json.pl
	$(PERL) bin/ianaxml2json.pl $< > $@

data/http-status-codes.json: \
    local/sw-http-statuses.xml local/iana-http-statuses.xml \
    local/iana/rtsp.xml local/iana/sip.xml \
    src/http-status-codes.txt src/icap-status-codes.txt \
    src/shttp-status-codes.txt src/ssdp-status-codes.txt \
    bin/http-status-codes.pl
	$(PERL) bin/http-status-codes.pl > $@
data/http-methods.json: \
    local/sw-http-methods.xml local/iana/http-methods.json \
    local/iana/rtsp.xml local/iana/sip.xml \
    bin/http-methods.pl src/http-methods.txt src/icap-methods.txt \
    src/shttp-methods.txt src/ssdp-methods.txt
	$(PERL) bin/http-methods.pl > $@
data/headers.json: bin/headers.pl src/http-headers.txt src/http-protocols.txt \
    src/http-content-codings.txt src/http-transfer-codings.txt \
    src/icap-headers.txt local/iana/http-parameters.json \
    src/http-range-units.txt src/http-cache-directives.txt \
    src/http-pragma-directives.txt src/http-warn-codes.txt \
    local/iana/http-protocols.json \
    local/iana/http-cache-control.json \
    local/iana/http-warn-codes.json local/iana/sip.json \
    local/iana/http-auth-schemes.json src/http-auth-schemes.txt \
    src/http-forwarded.txt src/http-preferences.txt \
    local/iana/cont-disp.json src/disposition-types.txt \
    src/disposition-params.txt src/http-cookie-attrs.txt \
    src/http-keep-alive.txt src/http-meter-directives.txt \
    src/http-list-directives.txt src/http-tcn-directives.txt \
    src/shttp-headers.txt src/http-ext-decls.txt \
    src/ssdp-headers.txt local/iana/rtsp.json \
    local/iana/http-ims.json src/http-ims.txt \
    src/http-p3p.txt local/iana/headers.json \
    src/fcast-headers.txt local/iana/fcast.json \
    src/http-equiv.txt src/http-pkp.txt src/http-hsts.txt \
    src/http-alt-svc.txt local/iana/alt-svc.json \
    src/sip-headers.txt
	$(PERL) bin/headers.pl > $@
data/digests.json: bin/digests.pl \
    local/iana/http-digests.json src/http-digests.txt \
    local/iana/ni.json
	$(PERL) bin/digests.pl > $@

data/http-frames.json: bin/http-frames.pl \
    local/iana/ws.json local/iana/http2.json bin/http-frames-hpack.pl
	$(PERL) bin/http-frames.pl > $@

local/mozilla-ciphers.html:
	$(SAVEURL) $@ https://wiki.mozilla.org/Security/Server_Side_TLS
local/mozilla-ciphers.json: local/mozilla-ciphers.html bin/mozilla-ciphers.pl
	$(PERL) bin/mozilla-ciphers.pl < $< > $@

data/tls.json: bin/tls.pl local/iana/tls.json local/mozilla-ciphers.json \
    local/iana/tls-exts.json
	$(PERL) bin/tls.pl > $@

data/fetch.json: bin/fetch.pl data/dom.json
	$(PERL) $< > $@

## ------ Encodings ------

all-encodings: data/encodings.json data/encoding-indexes.json
clean-encodings:
	rm -fr local/encodings.json local/indexes.json

data/encodings.json: bin/encodings.pl src/locale-default-encodings.txt \
    local/encodings.json data/encoding-indexes.json
	$(PERL) $< > $@
data/encoding-indexes.json: bin/encoding-indexes.pl local/indexes.json
	$(PERL) $< > $@

local/encodings.json:
	$(SAVEURL) $@ https://encoding.spec.whatwg.org/encodings.json
local/indexes.json:	
	$(SAVEURL) $@ https://encoding.spec.whatwg.org/indexes.json

## ------ JavaScript ------

all-js: data/js-lexical.json
clean-js:

data/js-lexical.json: bin/js-lexical.pl
	$(PERL) bin/js-lexical.pl > $@

## ------ DOM/HTML ------

all-dom: data/dom.json data/elements.json data/aria.json data/dom-perl.json \
    data/html-syntax.json data/xhtml-charrefs.dtd data/xml-syntax.json \
    data/html-tokenizer-expanded.json \
    data/xml-tokenizer-expanded.json \
    data/html-charrefs.json data/browsers.json data/rdf.json \
    data/xml-datatypes.json data/xpath.json data/webidl.json \
    data/html-tree-constructor-expanded.json \
    data/html-tree-constructor-expanded-no-isindex.json \
    data/xml-tree-constructor-expanded.json \
    intermediate/errors/parser-errors.json data/errors.json \
    data/html-metadata.json \
    data/temma-syntax.json data/temma-tokenizer-expanded.json \
    data/dom-events.json
clean-dom:
	rm -fr local/html local/html-extracted.json local/html-status.xml
	rm -fr local/obsvocab.html local/aria.rdf
	rm -fr data/xhtml-charrefs.dtd data/html-charrefs.json
	rm -fr local/xml5-spec.html local/schemaorg*
	rm -fr local/dom.html local/domparsing.html
	rm -fr local/html.spec.whatwg.org local/webidl.html
	rm -fr local/MetaExtensions.html
	rm -fr data/webidl.json

data/dom.json: bin/dom.pl src/dom-nodes.txt local/html-extracted.json \
  local/idl-extracted.json \
  src/idl/*.idl
	$(PERL) bin/dom.pl > $@

data/errors.json: bin/errors.pl local/webidl.json \
    intermediate/dom-error-types.json
	$(PERL) bin/errors.pl > $@

local/webidl.html:
	$(SAVEURL) $@ https://heycam.github.io/webidl/
local/webidl.json: local/webidl.html bin/extract-webidl.pl
	$(PERL) bin/extract-webidl.pl > $@
local/dom-extracted.json: local/dom.html bin/extract-dom-standard.pl
	$(PERL) bin/extract-dom-standard.pl > $@

data/dom-events.json: bin/dom-events.pl
	$(PERL) $< > $@

local/altmap-html-obsolete.json: src/html-obsolete.txt bin/altmap-to-json.pl
	$(PERL) bin/altmap-to-json.pl $< > $@
local/altmap-aria.json: src/altmap-aria.txt bin/altmap-to-json.pl
	$(PERL) bin/altmap-to-json.pl $< > $@

data/elements.json: bin/elements.pl src/element-interfaces.txt \
    local/html-extracted.json src/elements.txt \
    src/attr-types.txt local/obsvocab.html data/aria.json \
    local/element-aria.json local/altmap-html-obsolete.json \
    src/element-categories.txt local/html-tree.json data/fetch.json
	#local/html-status.xml
	$(PERL) bin/elements.pl > $@

## Not invoked by all and all-dom
data/isindex-prompt.json: bin/isindex-prompt.pl
	$(PERL) bin/isindex-prompt.pl > $@

local/html:
	cd local && ($(SAVETREE) https://html.spec.whatwg.org/multipage/ || true)
	touch $@
local/html-extracted.json: local/html bin/extract-html-standard.pl
	$(PERL) bin/extract-html-standard.pl > $@
#local/html-status.xml:
#	$(SAVEURL) $@ https://html.spec.whatwg.org/status.cgi?action=get-all-annotations
local/obsvocab.html:
	$(SAVEURL) $@ https://manakai.github.io/spec-obsvocab/

local/aria.rdf:
	$(SAVEURL) $@ https://www.w3.org/WAI/ARIA/schemata/aria-1.rdf
local/ariardf-parsed.json: bin/parse-ariardf.pl local/aria.rdf
	$(PERL) $< > $@
local/aria-roles.json: src/aria-roles.txt bin/aria-roles.pl
	$(PERL) bin/aria-roles.pl > $@

data/aria.json: bin/ariardf.pl local/altmap-aria.json \
    local/ariardf-parsed.json local/aria-roles.json src/aria-attrs.txt
	$(PERL) bin/ariardf.pl > $@

local/element-aria.json: src/element-aria.txt bin/ariaelements.pl \
    data/aria.json
	$(PERL) bin/ariaelements.pl > $@

data/dom-perl.json: src/dom-perl-methods.txt bin/dom-perl.pl
	$(PERL) bin/dom-perl.pl > $@

data/html-charrefs.json:
	$(SAVEURL) $@ https://html.spec.whatwg.org/entities.json

data/xhtml-charrefs.dtd: local/html-extracted.json

data/html-syntax.json: bin/html-syntax.pl local/html-tokenizer.json \
    local/html-tokenizer-charrefs.json \
    local/html-tokenizer-charrefs-jump.json \
    local/html-tree.json
	$(PERL) bin/html-syntax.pl > $@
	!(grep '"misc"' $@)
	!(grep '"UNPARSED"' $@)
	!(grep '"COND"' $@)
data/xml-syntax.json: bin/xml-syntax.pl \
    local/html-tokenizer.json \
    local/html-tokenizer-charrefs.json \
    local/xml-tokenizer-charrefs-replace.json \
    local/html-tokenizer-charrefs-jump.json \
    local/html-old-tokenizer.json \
    local/xml-tokenizer-delta.json \
    local/xml-tokenizer-replace.json \
    local/xml-tokenizer-only.json \
    local/xml-tokenizer-only2.json \
    local/tokenizer-pi.json \
    local/xml-tree.json
	$(PERL) bin/xml-syntax.pl > $@
	!(grep '"misc"' $@)
	!(grep '"UNPARSED"' $@)
	!(grep '"COND"' $@)
	!(grep '"EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR"' $@)
data/temma-syntax.json: bin/temma-syntax.pl \
    local/html-tokenizer.json \
    local/html-tokenizer-charrefs.json \
    local/html-tokenizer-charrefs-jump.json \
    local/temma-tokenizer-delta.json \
    local/temma-tokenizer-replace.json \
    local/tokenizer-pi.json
	$(PERL) bin/temma-syntax.pl > $@
	!(grep '"misc"' $@)
	!(grep '"UNPARSED"' $@)
	!(grep '"COND"' $@)
	!(grep '"EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR"' $@)

data/html-tokenizer-expanded.json: data/html-syntax.json \
    bin/tokenizer-variants.pl intermediate/errors/parser-errors.json
	$(PERL) bin/tokenizer-variants.pl < data/html-syntax.json > $@
	!(grep reconsume $@)
data/xml-tokenizer-expanded.json: data/xml-syntax.json \
    bin/tokenizer-variants.pl intermediate/errors/parser-errors.json
	$(PERL) bin/tokenizer-variants.pl < data/xml-syntax.json > $@
	!(grep reconsume $@)
data/temma-tokenizer-expanded.json: data/temma-syntax.json \
    bin/tokenizer-variants.pl intermediate/errors/parser-errors.json
	$(PERL) bin/tokenizer-variants.pl < data/temma-syntax.json > $@
	!(grep reconsume $@)

data/html-tree-constructor-expanded.json: data/html-syntax.json \
    bin/expand-tree-constructor.pl data/elements.json \
    intermediate/errors/parser-errors.json
	$(PERL) bin/expand-tree-constructor.pl < data/html-syntax.json > $@
	!(grep '"tree_steps"' $@)
	!(grep '"CHAR' $@)
	!(grep '"FIELD"' $@)
	!(grep '"USING-THE-RULES-FOR"' $@)
data/html-tree-constructor-expanded-no-isindex.json: data/html-syntax.json \
    bin/expand-tree-constructor.pl data/elements.json \
    intermediate/errors/parser-errors.json
	NO_ISINDEX=1 \
	$(PERL) bin/expand-tree-constructor.pl < data/html-syntax.json > $@
	!(grep 'isindex' $@)
data/xml-tree-constructor-expanded.json: data/xml-syntax.json \
    bin/expand-tree-constructor.pl data/elements.json \
    intermediate/errors/parser-errors.json
	PARSER_LANG=XML \
	$(PERL) bin/expand-tree-constructor.pl < data/xml-syntax.json > $@
	!(grep '"tree_steps"' $@)
	!(grep '"CHAR' $@)
	!(grep '"FIELD"' $@)
	!(grep '"USING-THE-RULES-FOR"' $@)

local/html-tokenizer.json: bin/extract-html-tokenizer.pl local/html
	$(PERL) bin/extract-html-tokenizer.pl local/html.spec.whatwg.org/multipage/parsing.html > $@
local/html-tokenizer-charrefs.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/charrefs.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/charrefs.html > $@
local/xml-tokenizer-charrefs-replace.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/charrefs-xml-replace.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/charrefs-xml-replace.html > $@
local/html-tokenizer-charrefs-jump.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/charrefs-jump.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/charrefs-jump.html > $@

local/html-old-tokenizer.json: bin/extract-html-tokenizer.pl src/tokenizer/html-syntax.html
	$(PERL) $< src/tokenizer/html-syntax.html > $@
local/xml5-spec.html:
	$(SAVEURL) $@ https://dvcs.w3.org/hg/xml-er/raw-file/3fb2e443ca50/Overview.src.html

local/xml-tokenizer.json: bin/extract-html-tokenizer.pl local/xml5-spec.html
	$(PERL) bin/extract-html-tokenizer.pl local/xml5-spec.html > $@
local/xml-tokenizer-delta.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/xml-delta.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/xml-delta.html > $@
local/xml-tokenizer-replace.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/xml-replace.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/xml-replace.html > $@
local/xml-tokenizer-only.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/xml-only.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/xml-only.html > $@
local/tokenizer-pi.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/pi.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/pi.html > $@

local/temma-tokenizer-delta.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/temma-delta.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/temma-delta.html > $@
local/temma-tokenizer-replace.json: bin/extract-html-tokenizer.pl \
    src/tokenizer/temma-replace.html
	$(PERL) bin/extract-html-tokenizer.pl src/tokenizer/temma-replace.html > $@

local/xml-tokenizer.html: src/tokenizer/*.txt \
    bin/tokenizer-text-to-html.pl
	mkdir -p local
	$(PERL) bin/tokenizer-text-to-html.pl src/tokenizer/*.txt > $@
local/xml-tokenizer-only2.json: bin/extract-html-tokenizer.pl \
    local/xml-tokenizer.html
	$(PERL) bin/extract-html-tokenizer.pl local/xml-tokenizer.html > $@

local/html-tree.json: bin/extract-html-tree.pl local/html
	$(PERL) bin/extract-html-tree.pl local/html.spec.whatwg.org/multipage/parsing.html > $@
	!(grep '"DESC"' $@)
	!(grep '"COND"' $@)
	!(grep '"misc"' $@)
	!(grep '"IF"' $@)
	!(grep '"TARGET"' $@)
	!(grep '"PROCESS"' $@)
	!(grep '"SAME-AS"' $@)
	!(grep '"LABEL"' $@)
	!(grep '"LOOP"' $@)
local/xml-tree.json: bin/extract-html-tree.pl src/xml-tree-construction.html
	$(PERL) bin/extract-html-tree.pl src/xml-tree-construction.html > $@

intermediate/errors/parser-errors.json: bin/parser-errors.pl \
    src/parser-errors.txt data/html-syntax.json data/xml-syntax.json
	$(PERL) bin/parser-errors.pl src/parser-errors.txt > $@

local/MetaExtensions.html:
	$(SAVEURL) $@ https://wiki.whatwg.org/wiki/MetaExtensions
local/MetaExtensions.json: local/MetaExtensions.html bin/parse-wiki-tables.pl
	$(PERL) bin/parse-wiki-tables.pl table.wikitable 1 $< > $@
local/RelExtensions.html:
	$(SAVEURL) $@ http://microformats.org/wiki/existing-rel-values
local/RelExtensions.json: local/RelExtensions.html bin/parse-wiki-tables.pl
	$(PERL) bin/parse-wiki-tables.pl "a[name=\"HTML5_link_type_extensions\"] ~ table" 0 $< > $@
local/iana/link-relations.xml:
	$(SAVEURL) $@ https://www.iana.org/assignments/link-relations/link-relations.xml
data/html-metadata.json: local/MetaExtensions.json bin/html-metadata.pl \
    local/RelExtensions.json src/html-meta-names.txt src/html-link-types.txt \
    local/iana/link-relations.json
	$(PERL) bin/html-metadata.pl > $@

data/browsers.json: bin/browsers.pl src/task-sources.txt data/fetch.json
	$(PERL) $< > $@

data/rdf.json: bin/rdf.pl
	$(PERL) bin/rdf.pl > $@

data/xml-datatypes.json: bin/xml-datatypes.pl
	$(PERL) bin/xml-datatypes.pl > $@

data/xpath.json: bin/xpath.pl src/xpath-functions.txt
	$(PERL) bin/xpath.pl > $@

data/webidl.json: bin/webidl.pl
	$(PERL) bin/webidl.pl > $@

local/dom.html:
	$(SAVEURL) $@ https://dom.spec.whatwg.org/
local/fetch.html:
	$(SAVEURL) $@ https://fetch.spec.whatwg.org/
local/fullscreen.html:
	$(SAVEURL) $@ https://fullscreen.spec.whatwg.org/
local/encoding.html:
	$(SAVEURL) $@ https://encoding.spec.whatwg.org/
local/notifications.html:
	$(SAVEURL) $@ https://notifications.spec.whatwg.org/
local/compat.html:
	$(SAVEURL) $@ https://compat.spec.whatwg.org/
local/url.html:
	$(SAVEURL) $@ https://url.spec.whatwg.org/
#local/domparsing.html:
#	#$(SAVEURL) $@ https://domparsing.spec.whatwg.org/
#	$(SAVEURL) $@ https://raw.githubusercontent.com/whatwg/domparsing/edc795ccfdc03e396197bf81a0f550105930e90b/domparser
local/xhr.html:
	$(SAVEURL) $@ https://xhr.spec.whatwg.org/
local/idl-extracted.json: local/dom.html \
    local/xhr.html local/fetch.html local/notifications.html \
    local/fullscreen.html local/encoding.html local/compat.html \
    bin/extract-idls.pl local/url.html
#local/domparsing.html
	$(PERL) bin/extract-idls.pl > $@

local/modules/vcutils:
	$(GIT) clone --depth 1 https://github.com/wakaba/perl-vcutils $@
data/html-spec-svn-history.html: local/modules/vcutils $(HTML_REPO_DIR) always
	HTML_REPO_DIR=$(HTML_REPO_DIR) $(PERL) bin/html-spec-svn-history.pl > $@

## ------ Microdata ------

all-microdata: data/microdata.json data/ogp.json
clean-microdata:
	#rm -fr local/data-vocabulary/files
	rm -fr local/schemaorg.*

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
	  $(SAVEURL) local/data-vocabulary/$$x.html http://www.data-vocabulary.org/$$x/; \
	done
	touch $@

local/schemaorg.rdfa:
	$(SAVEURL) $@ https://raw.githubusercontent.com/schemaorg/schemaorg/sdo-gozer/data/schema.rdfa
	#http://schema.org/docs/schema_org_rdfa.html
local/schemaorg.json: local/schemaorg.rdfa bin/microdata-schemaorg.pl
	$(PERL) bin/microdata-schemaorg.pl > $@

local/schemaorg-wsa.html:
	$(SAVEURL) $@ https://www.w3.org/wiki/WebSchemas/Accessibility
local/schemaorg-wsa.json: local/schemaorg-wsa.html bin/extract-schemaorg-wsa.pl
	$(PERL) bin/extract-schemaorg-wsa.pl > $@

local/xls2txt:
	$(GIT) clone https://github.com/hroptatyr/xls2txt.git $@
	cd $@ && $(MAKE)
local/xls2txt/xls2txt: local/xls2txt

local/rec20.xls:
	$(SAVEURL) $@ http://www.unece.org/fileadmin/DAM/cefact/recommendations/rec20/rec20_Rev9e_2014.xls
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

all-css: data/css.json data/css-colors.json data/css-fonts.json \
    data/selectors.json
clean-css:

data/css.json: bin/css.pl src/css-at-rules.txt
	$(PERL) bin/css.pl > $@

data/css-colors.json: bin/css-colors.pl
	$(PERL) bin/css-colors.pl > $@

data/css-fonts.json: bin/css-fonts.pl
	$(PERL) bin/css-fonts.pl > $@

data/selectors.json: bin/selectors.pl
	$(PERL) bin/selectors.pl > $@

## ------ Validation ------

test: test-deps test-main

test-deps: deps local/bin/jq

test-main:
	$(PROVE) t/*.t
	!(grep '"_errors"' data/elements.json)

always:

## License: Public Domain.