encodings.json
~~~~~~~~~~~~~~

This file contains data on character encodings for the Web.

* Structure

The file contains a JSON object containing following data:

locale_default [object]

  Locale-dependent default encoding as suggested by
  <http://www.whatwg.org/specs/web-apps/current-work/#determining-the-character-encoding>.
  The names represent locales, identified by BCP 47 language tags, in
  lowercase.  The values represent the corresponding encoding names in
  the Encoding Standard, in lowercase.  The name "*" represents the
  fallback, i.e. the default encoding used when the current locale is
  not otherwise listed.

* Source

HTML Standard
<http://www.whatwg.org/specs/web-apps/current-work/#determining-the-character-encoding>.
