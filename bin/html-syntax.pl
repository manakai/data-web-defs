use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');

my $Data = {};

sub XLINK_NS () { q<http://www.w3.org/1999/xlink> }
sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }
sub XMLNS_NS () { q<http://www.w3.org/2000/xmlns/> }

## Adjust MathML attributes
## <http://www.whatwg.org/specs/web-apps/current-work/#adjust-mathml-attributes>.
$Data->{adjusted_mathml_attr_names} = {
  definitionurl => 'definitionURL',
};

## Adjust SVG attributes
## <http://www.whatwg.org/specs/web-apps/current-work/#adjust-svg-attributes>.
$Data->{adjusted_svg_attr_names} = {
  attributename => 'attributeName',
  attributetype => 'attributeType',
  basefrequency => 'baseFrequency',
  baseprofile => 'baseProfile',
  calcmode => 'calcMode',
  clippathunits => 'clipPathUnits',
  contentscripttype => 'contentScriptType',
  contentstyletype => 'contentStyleType',
  diffuseconstant => 'diffuseConstant',
  edgemode => 'edgeMode',
  externalresourcesrequired => 'externalResourcesRequired',
  filterunits => 'filterUnits',
  glyphref => 'glyphRef',
  gradienttransform => 'gradientTransform',
  gradientunits => 'gradientUnits',
  kernelmatrix => 'kernelMatrix',
  kernelunitlength => 'kernelUnitLength',
  keypoints => 'keyPoints',
  keysplines => 'keySplines',
  keytimes => 'keyTimes',
  lengthadjust => 'lengthAdjust',
  limitingconeangle => 'limitingConeAngle',
  markerheight => 'markerHeight',
  markerunits => 'markerUnits',
  markerwidth => 'markerWidth',
  maskcontentunits => 'maskContentUnits',
  maskunits => 'maskUnits',
  numoctaves => 'numOctaves',
  pathlength => 'pathLength',
  patterncontentunits => 'patternContentUnits',
  patterntransform => 'patternTransform',
  patternunits => 'patternUnits',
  pointsatx => 'pointsAtX',
  pointsaty => 'pointsAtY',
  pointsatz => 'pointsAtZ',
  preservealpha => 'preserveAlpha',
  preserveaspectratio => 'preserveAspectRatio',
  primitiveunits => 'primitiveUnits',
  refx => 'refX',
  refy => 'refY',
  repeatcount => 'repeatCount',
  repeatdur => 'repeatDur',
  requiredextensions => 'requiredExtensions',
  requiredfeatures => 'requiredFeatures',
  specularconstant => 'specularConstant',
  specularexponent => 'specularExponent',
  spreadmethod => 'spreadMethod',
  startoffset => 'startOffset',
  stddeviation => 'stdDeviation',
  stitchtiles => 'stitchTiles',
  surfacescale => 'surfaceScale',
  systemlanguage => 'systemLanguage',
  tablevalues => 'tableValues',
  targetx => 'targetX',
  targety => 'targetY',
  textlength => 'textLength',
  viewbox => 'viewBox',
  viewtarget => 'viewTarget',
  xchannelselector => 'xChannelSelector',
  ychannelselector => 'yChannelSelector',
  zoomandpan => 'zoomAndPan',
};

## Adjust foreign attributes
## <http://www.whatwg.org/specs/web-apps/current-work/#adjust-foreign-attributes>.
$Data->{adjusted_ns_attr_names} = {
  'xlink:actuate' => [XLINK_NS, ['xlink', 'actuate']],
  'xlink:arcrole' => [XLINK_NS, ['xlink', 'arcrole']],
  'xlink:href' => [XLINK_NS, ['xlink', 'href']],
  'xlink:role' => [XLINK_NS, ['xlink', 'role']],
  'xlink:show' => [XLINK_NS, ['xlink', 'show']],
  'xlink:title' => [XLINK_NS, ['xlink', 'title']],
  'xlink:type' => [XLINK_NS, ['xlink', 'type']],
  'xml:base' => [XML_NS, ['xml', 'base']],
  'xml:lang' => [XML_NS, ['xml', 'lang']],
  'xml:space' => [XML_NS, ['xml', 'space']],
  'xmlns' => [XMLNS_NS, [undef, 'xmlns']],
  'xmlns:xlink' => [XMLNS_NS, ['xmlns', 'xlink']],
};

## The rules for parsing tokens in foreign content, Any other start
## tag, An element in the SVG namespace
## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inforeign>.
$Data->{adjusted_svg_element_names} = {
  altglyph => 'altGlyph',
  altglyphdef => 'altGlyphDef',
  altglyphitem => 'altGlyphItem',
  animatecolor => 'animateColor',
  animatemotion => 'animateMotion',
  animatetransform => 'animateTransform',
  clippath => 'clipPath',
  feblend => 'feBlend',
  fecolormatrix => 'feColorMatrix',
  fecomponenttransfer => 'feComponentTransfer',
  fecomposite => 'feComposite',
  feconvolvematrix => 'feConvolveMatrix',
  fediffuselighting => 'feDiffuseLighting',
  fedisplacementmap => 'feDisplacementMap',
  fedistantlight => 'feDistantLight',
  fedropshadow => 'feDropShadow',
  feflood => 'feFlood',
  fefunca => 'feFuncA',
  fefuncb => 'feFuncB',
  fefuncg => 'feFuncG',
  fefuncr => 'feFuncR',
  fegaussianblur => 'feGaussianBlur',
  feimage => 'feImage',
  femerge => 'feMerge',
  femergenode => 'feMergeNode',
  femorphology => 'feMorphology',
  feoffset => 'feOffset',
  fepointlight => 'fePointLight',
  fespecularlighting => 'feSpecularLighting',
  fespotlight => 'feSpotLight',
  fetile => 'feTile',
  feturbulence => 'feTurbulence',
  foreignobject => 'foreignObject',
  glyphref => 'glyphRef',
  lineargradient => 'linearGradient',
  radialgradient => 'radialGradient',
  #solidcolor => 'solidColor', ## NOTE: Commented in spec (SVG1.2)
  textpath => 'textPath',  
};

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
