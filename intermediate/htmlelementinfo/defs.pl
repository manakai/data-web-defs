use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $ThisPath = path (__FILE__)->parent;

my $EDefs = {};
{
  my $path = $ThisPath->child ('local/data/elements/files/elements.json');
  my $json = json_bytes2perl $path->slurp;

  for my $ns (keys %{$json->{elements}}) {

    next unless {
      "http://www.w3.org/1999/xhtml" => 1,
      "http://www.w3.org/2000/06/xhtml2" => 1,
      "http://www.w3.org/2000/06/xhtml2/" => 1,
    }->{$ns};
    
    for my $ln (sort { $a cmp $b } keys %{$json->{elements}->{$ns}}) {
      next if $ln eq "fb:like";

      my $in = $json->{elements}->{$ns}->{$ln};
      $EDefs->{$ln} ||= {};
      $EDefs->{$ln}->{conforming} = 1 if $in->{conforming};
      $EDefs->{$ln}->{spec} = $in->{spec} if $in->{spec};
      $EDefs->{$ln}->{id} = $in->{id} if $in->{id};
      $EDefs->{$ln}->{parser_category} = $in->{parser_category}
          if defined $in->{parser_category};
    }
  }
}

{
  my $path = path ("local/data/html-syntax/files/html-syntax.json");
  my $json = json_bytes2perl $path->slurp;

  my $names = {};
  my $map = $json->{"adjusted_svg_element_names"};
  $names->{$_} = 1 for values %$map;

  my $p; $p = sub {
    my $v = $_[0];
    if (ref $v eq 'ARRAY') {
      if ($v->[0] eq 'token tag_name') {
        $names->{$_} = 1 for @{$v->[2]};
      } else {
        for (@$v) {
          if (ref $_ eq 'HASH') {
            $p->($_);
          } elsif (ref $_ eq 'ARRAY') {
            $p->($_);
          }
        }
      }
    } else {
      $names->{$v->{tag_name}} = 1 if defined $v->{tag_name};
      $names->{$v->{local_name}} = 1 if defined $v->{local_name};
      if (defined $v->{name} and not defined $v->{type}) {
        if (ref $v->{name}) {
          $names->{$_} = 1 for @{$v->{name}};
        } else {
          $names->{$v->{name}} = 1;
        }
      }

      for (@{$v->{cond} or []}, $v->{except}, $v->{until}, $v->{while_not}) {
        if (defined $_ and ref $_ eq 'HASH') {
          if (defined $_->{name}) {
            if (ref $_->{name}) {
              $names->{$_} = 1 for @{$_->{name} or []};
            } else {
              $names->{$_->{name}} = 1;
            }
          }
          if (defined $_->{except}) {
            $names->{$_} = 1 for @{$_->{except}};
          }
        }
      }

      $p->($_) for @{$v->{actions} or []};
      $p->($_) for @{$v->{false_actions} or []};
    }
  };
  $p->($json->{dispatcher_html});
  for (values %{$json->{ims}}) {
    for my $cond (keys %{$_->{conds}}) {
      if ($cond =~ /^(?:START|END):(.+)$/) {
        $names->{$_} = 1 for split / /, $1;
      }
      $p->($_->{conds}->{$cond}->{actions});
    }
  }

  for (keys %{$json->{tokenizer}->{"initial_state_by_html_element"}->{always}}) {
    $names->{$_} = 1;
  }
  for (keys %{$json->{tokenizer}->{"initial_state_by_html_element"}->{"scripting_flag_is_enabled"}}) {
    $names->{$_} = 1;
  }

  for (values %{$json->{tree_patterns}}) {
    $p->($_);
  }
  for (values %{$json->{tree_patterns_not}}) {
    $p->($_);
  }
  for (values %{$json->{tree_steps}}) {
    $p->($_);
  }

  $EDefs->{$_}->{_parser} = 1 for keys %$names;
}

for (qw(a address dd dl dt h1 h2 h3 hp1 hp2 hp3 i1 isindex li
        listing nextid node ol p plaintext restoffile title ul xmp)) {
  $EDefs->{$_}->{_www19910402} = 1;
}
for (qw(title nextid a isindex plaintext listing p
        h1 h2 h3 h4 h5 h6 hp1 hp2 hp3 dl dt dd ul li)) {
  $EDefs->{$_}->{_html19920109} = 1;
}
for (qw(base savedas ol)) {
  $EDefs->{$_}->{_html19920109} = 1;
  $EDefs->{$_}->{_html19920109_mentioned} = 1;
}

{
  for (
    ["Structured Text", [qw(html)]],
    ["The HEAD element contains", [qw(head)]],
    ["The BODY element contains", [qw(body)]],
    ["An anchor is", [qw(a)]],
    ["This element is for address", [qw(address)]],
    ["This element allows the URL", [qw(base)]],
    ["The BLOCKQUOTE element", [qw(blockquote)]],
    ["Six levels", [qw(h1 h2 h3 h4 h5 h6)]],
    ["IMG:", [qw(img)], "extra"],
    ["This element informs", [qw(isindex)]],
    ["The LINK element", [qw(link)]],
    ["A glossary", [qw(dl dt dd)]],
    ["A list is", [qw(ul li ol menu dir)]],
    ["Next ID", [qw(nextid)]],
    ["P: Paragraph mark", [qw(p)]],
    ["PRE:", [qw(pre)]],
    ["The title of a", [qw(title)]],
    ["Character highlighting", [qw(tt b i u em strong code samp
                                   kbd var dfn cite)], "extra"],
    ["The empty PLAINTEXT", [qw(plaintext)], "obsolete"],
    ["XMP and LISTING", [qw(listing xmp)], "obsolete"],
    ["Highlighted Phrase", [qw(hp1 hp2 hp3)], "obsolete"],
  ) {
    my $els = $_->[1];
    my $f = $_->[0];
    my $mode = $_->[2];
    $f =~ s/ /%20/g;
    for my $el (@$els) {
      $EDefs->{$el}->{_html10_url} = "https://datatracker.ietf.org/doc/html/draft-ietf-iiir-html-00#:~:text=" . $f;
      $EDefs->{$el}->{"_html10_" . $mode} = 1 if defined $mode;
      $EDefs->{$el}->{"_html10_mainstream"} = 1 if not defined $mode;
    }
  }
}

{
  my $path = $ThisPath->child ('local/dtdinfo/html20.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_html20_deprecated} = 1 for qw(xmp listing plaintext);
  $EDefs->{$_}->{_html20_mentioned} = 1 for qw(strike u);
  $EDefs->{$_}->{_html20_level} = 1 for keys %{$json->{elements}};
  $EDefs->{$_}->{_html20_level} = 2 for qw(form select option input textarea);
  $EDefs->{$_}->{_html20_url} = 'https://datatracker.ietf.org/doc/html/rfc1866#section-' . ({qw(
    html 5.1 head 5.2 title 5.2.1 base 5.2.2 isindex 5.2.3 link 5.2.4
    meta 5.2.5 nextid 5.2.6 body 5.3 h1 5.4 h2 5.4 h3 5.5 h4 5.5 h5 5.5 h6 5.5
    p 5.5.1 pre 5.5.2 xmp 5.5.2.1 listing 5.5.2.1 address 5.5.3
    blockquote 5.5.4 ul 5.6.1 li 5.6.1 ol 5.6.2 dir 5.6.3 menu 5.6.4
    dl 5.6.5 dt 5.6.5 dd 5.6.5 cite 5.7.1.1 code 5.7.1.2 em 5.7.1.3
    kbd 5.7.1.4 samp 5.7.1.5 strong 5.7.1.6 var 5.7.1.7
    b 5.7.2.1 i 5.7.2.2 tt 5.7.2.3 a 5.7.3 br 5.8 hr 5.9 img 5.10
    strike 5.7.2 u 5.7.2
    form 8.1.1 input 8.1.2 select 8.1.3 option 8.1.3.1 textarea 8.1.4
    plaintext 5.5.2.1
  )}->{$_} // warn $_) for 'strike', 'u', keys %{$json->{elements}};
}

{
  my $path = $ThisPath->child ('local/dtdinfo/html2x.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_html2x_deprecated} = 1 for qw(xmp listing plaintext);
  $EDefs->{$_}->{_html2x} = 1 for keys %{$json->{elements}};
  $EDefs->{$_}->{_html2x_url} = 'https://datatracker.ietf.org/doc/html/rfc2070#section-' . ({qw(
    bdo 4.2.2 q 4.2.2 sup 4.2.2 sub 4.2.2 span 4.2.2
  )}->{$_} // warn $_) for qw(sub sup bdo q span);
}

for (
  ["_html19930106" => "local/dtdinfo/html10.json"],
  ["_html19920715" => "local/dtdinfo/html-19920715.json"],
  ["_htmlp19930713" => "local/dtdinfo/htmlplus-19930713.json"],
  ["_htmlp19940405_core" => "local/dtdinfo/htmlplus-19940405c.json"],
  ["_htmlp19940405" => "local/dtdinfo/htmlplus-19940405.json"],
  ["_isohtml19970327" => "local/dtdinfo/isohtml-19970327.json"],
  ["_isohtml20030424" => "local/dtdinfo/isohtml-20030424.json"],
  ["_isohtml20040424p" => "local/dtdinfo/isohtml-20030424p.json"],
) {
  my $key = $_->[0];
  my $path = $ThisPath->child ($_->[1]);
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{$key} = 1 for keys %{$json->{elements}};
}
{
  for (
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_10.html" => [qw(h1 h2 h3 h4 h5 h6)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_11.html" => [qw(p)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_14.html" => [qw(a)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_16.html" => [qw(i b u s sup sub tt)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_17.html" => [qw(em strong)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_18.html" => [qw(q cite person acronym abbrev cmd arg kbd var dfn code samp )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_19.html" => [qw(render)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_20.html" => [qw(footnote margin )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_20.html" => [qw(panel )], "mentioned"],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_21.html" => [qw(img image )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_22.html" => [qw(changed removed added )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_23.html" => [qw(online printed )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_24.html" => [qw(l br)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_26.html" => [qw(quote )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_27.html" => [qw(abstract )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_28.html" => [qw(byline )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_FootNote_111.html" => [qw(address )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_29.html" => [qw(note )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_31.html" => [qw(ol li )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_32.html" => [qw(ul li)]], # dup
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_34.html" => [qw(dl dt dd)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_35.html" => [qw(fig caption)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_39.html" => [qw(table caption tr th td)]], # dup
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_41.html" => [qw(form mh input select textarea option)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_44.html" => [qw(lit tab pre )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_45.html" => [qw(math sub sup box over array item )]], # dup
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_48.html" => [qw(htmlplus)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_49.html" => [qw(head body)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_50.html" => [qw(title )]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_51.html" => [qw(isindex)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_52.html" => [qw(nextid)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_53.html" => [qw(base)]],
    ["https://www.w3.org/MarkUp/HTMLPlus/htmlplus_54.html" => [qw(link)]],
  ) {
    my ($url, $els, $mode) = @$_;
    $EDefs->{$_}->{_htmlp_url} = $url for @$els;
    if (defined $mode) {
      $EDefs->{$_}->{'_htmlp_'.$mode} = 1 for @$els;
    }
  }
}

{
  my $path = $ThisPath->child ('local/dtdinfo/html30.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_html3_dtd} = 1 for keys %{$json->{elements}};
  for (
    ["https://www.w3.org/MarkUp/html3/overview.html" => [qw(html )]],
    ["https://www.w3.org/MarkUp/html3/dochead.html" => [qw(head base isindex link meta nextid range spot style title )]],
    ["https://www.w3.org/MarkUp/html3/docbody.html" => [qw(body )]],
    ["https://www.w3.org/MarkUp/html3/banners.html" => [qw(banner )]],
    ["https://www.w3.org/MarkUp/html3/divisions.html" => [qw(div )]],
    ["https://www.w3.org/MarkUp/html3/headings.html" => [qw(h1 h2 h3 h4 h5 h6)]],
    ["https://www.w3.org/MarkUp/html3/headings.html" => [qw(nobr wbr)], "mentioned"],
    ["https://www.w3.org/MarkUp/html3/paras.html" => [qw(p)]],
    ["https://www.w3.org/MarkUp/html3/paras.html" => [qw(nobr wbr)], "mentioned"], # dup
    ["https://www.w3.org/MarkUp/html3/lbreak.html" => [qw(br )]],
    ["https://www.w3.org/MarkUp/html3/lbreak.html" => [qw(wbr )], "mentioned"], # dup
    ["https://www.w3.org/MarkUp/html3/tabs.html" => [qw(tab )]],
    ["https://www.w3.org/MarkUp/html3/anchors.html" => [qw(a )]],
    ["https://www.w3.org/MarkUp/html3/logical.html" => [qw(em cite strong code samp kbd var dfn q lang au person acronym abbrev ins del )]],
    ["https://www.w3.org/MarkUp/html3/emphasis.html" => [qw(b i tt u  s big small sub sup )]],
    ["https://www.w3.org/MarkUp/html3/img.html" => [qw(img )]],
    ["https://www.w3.org/MarkUp/html3/bulletlists.html" => [qw(ul menu dir )]],
    ["https://www.w3.org/MarkUp/html3/seqlists.html" => [qw(ol )]],
    ["https://www.w3.org/MarkUp/html3/deflists.html" => [qw(dl)]],
    ["https://www.w3.org/MarkUp/html3/listheader.html" => [qw(lh)]],
    ["https://www.w3.org/MarkUp/html3/termname.html" => [qw(dt)]],
    ["https://www.w3.org/MarkUp/html3/termdef.html" => [qw(dd)]],
    ["https://www.w3.org/MarkUp/html3/listitem.html" => [qw(li)]],
    ["https://www.w3.org/MarkUp/html3/figures.html" => [qw(fig)]],
    ["https://www.w3.org/MarkUp/html3/overlays.html" => [qw(overlay)]],
    ["https://www.w3.org/MarkUp/html3/captions.html" => [qw(caption )]],
    ["https://www.w3.org/MarkUp/html3/credits.html" => [qw(credit)]],
    ["https://www.w3.org/MarkUp/html3/tables.html" => [qw(table )]],
    ["https://www.w3.org/MarkUp/html3/tablerows.html" => [qw(tr)]],
    ["https://www.w3.org/MarkUp/html3/tablecells.html" => [qw(th td)]],
    ["https://www.w3.org/MarkUp/html3/maths.html" => [qw(math )]],
    ["https://www.w3.org/MarkUp/html3/mathbox.html" => [qw(box)]],
    ["https://www.w3.org/MarkUp/html3/mathscripts.html" => [qw(sub sup)]], # dup
    ["https://www.w3.org/MarkUp/html3/above.html" => [qw(above)]],
    ["https://www.w3.org/MarkUp/html3/below.html" => [qw(below )]],
    ["https://www.w3.org/MarkUp/html3/vectors.html" => [qw(vec bar dot ddot hat tilde)]],
    ["https://www.w3.org/MarkUp/html3/roots.html#sqrt" => [qw(sqrt)]],
    ["https://www.w3.org/MarkUp/html3/roots.html#root" => [qw(root)]],
    ["https://www.w3.org/MarkUp/html3/arrays.html" => [qw(array)]],
    ["https://www.w3.org/MarkUp/html3/mathfields.html#rows" => [qw(row)]],
    ["https://www.w3.org/MarkUp/html3/mathfields.html#items" => [qw(item)]],
    ["https://www.w3.org/MarkUp/html3/mathtext.html" => [qw(text)]],
    ["https://www.w3.org/MarkUp/html3/mathface.html" => [qw(b t bt)]], # dup
    ["https://www.w3.org/MarkUp/html3/rules.html" => [qw(hr)]],
    ["https://www.w3.org/MarkUp/html3/literal.html" => [qw(pre)]],
    ["https://www.w3.org/MarkUp/html3/notes.html" => [qw(note )]],
    ["https://www.w3.org/MarkUp/html3/footnotes.html" => [qw(fn )]],
    ["https://www.w3.org/MarkUp/html3/blockquotes.html" => [qw(bq )]],
    ["https://www.w3.org/MarkUp/html3/blockquotes.html" => [qw(blockquote)], "mentioned"],
    ["https://www.w3.org/MarkUp/html3/address.html" => [qw(address)]],
    ["https://www.w3.org/MarkUp/html3/forms.html" => [qw(form)]],
    ["https://www.w3.org/MarkUp/html3/input.html" => [qw(input)]],
    ["https://www.w3.org/MarkUp/html3/textarea.html" => [qw(textarea)]],
    ["https://www.w3.org/MarkUp/html3/menus.html" => [qw(select )]],
    ["https://www.w3.org/MarkUp/html3/options.html" => [qw(option )]],
  ) {
    my ($url, $els, $mode) = @$_;
    $EDefs->{$_}->{_html3_url} = $url for @$els;
    if (defined $mode) {
      $EDefs->{$_}->{'_html3_'.$mode} = 1 for @$els;
    }
  }
}

{
  my $path = $ThisPath->child ('local/dtdinfo/html3-tables.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_html3tables_url} = 'https://datatracker.ietf.org/doc/html/rfc1942#page-3-' . {qw(
    table 12 caption 16 colgroup 16 col 18 thead 19 tbody 19 tfoot 19
    tr 20 th 21 td 21 
  )}->{$_} // warn $_ for keys %{$json->{elements}};
}

{
  my $path = $ThisPath->child ('local/dtdinfo/html32.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_html32_deprecated} = 1 for qw(xmp listing plaintext);
  $EDefs->{$_}->{_html32_mentioned} = 1 for qw(s);

  #$EDefs->{$_}->{_html32_url} = "https://www.w3.org/TR/2018/SPSD-html32-20180315/#" . ({qw(
  $EDefs->{$_}->{_html32_url} = "https://web.archive.org/web/20061108212618/http://www.w3.org/TR/REC-html32#" . ({qw(
    h1 headings h2 headings h3 headings h4 headings h5 headings h6 headings
    p para li ul dt dl dd dl blockquote bq
    caption table tr table td table th table
    tt font-style i font-style b font-style u font-style
    strike font-style big font-style small font-style
    sub font-style sup font-style s font-style
    em phrase strong phrase dfn phrase code phrase samp phrase
    kbd phrase var phrase cite phrase
    option select
    a anchor 
  )}->{$_} // $_) for 's', keys %{$json->{elements}};
}

{
  for (qw(
    applet basefont center dir font isindex menu s strike u
  )) {
    $EDefs->{$_}->{_html4_deprecated} = 1;
    $EDefs->{$_}->{_html4_transitional} = 1;
    $EDefs->{$_}->{_html4_frameset} = 1;
  }
  for (qw(
    noframes iframe
  )) {
    $EDefs->{$_}->{_html4_transitional} = 1;
    $EDefs->{$_}->{_html4_frameset} = 1;
  }
  for (qw(
    frameset frame
  )) {
    $EDefs->{$_}->{_html4_frameset} = 1;
  }
  
  for (split /\n/, q{A	https://www.w3.org/TR/html4/struct/links.html#edef-A
ABBR	https://www.w3.org/TR/html4/struct/text.html#edef-ABBR
ACRONYM	https://www.w3.org/TR/html4/struct/text.html#edef-ACRONYM
ADDRESS	https://www.w3.org/TR/html4/struct/global.html#edef-ADDRESS
APPLET	https://www.w3.org/TR/html4/struct/objects.html#edef-APPLET
AREA	https://www.w3.org/TR/html4/struct/objects.html#edef-AREA
B	https://www.w3.org/TR/html4/present/graphics.html#edef-B
BASE	https://www.w3.org/TR/html4/struct/links.html#edef-BASE
BASEFONT	https://www.w3.org/TR/html4/present/graphics.html#edef-BASEFONT
BDO	https://www.w3.org/TR/html4/struct/dirlang.html#edef-BDO
BIG	https://www.w3.org/TR/html4/present/graphics.html#edef-BIG
BLOCKQUOTE	https://www.w3.org/TR/html4/struct/text.html#edef-BLOCKQUOTE
BODY	https://www.w3.org/TR/html4/struct/global.html#edef-BODY
BR	https://www.w3.org/TR/html4/struct/text.html#edef-BR
BUTTON	https://www.w3.org/TR/html4/interact/forms.html#edef-BUTTON
CAPTION	https://www.w3.org/TR/html4/struct/tables.html#edef-CAPTION
CENTER	https://www.w3.org/TR/html4/present/graphics.html#edef-CENTER
CITE	https://www.w3.org/TR/html4/struct/text.html#edef-CITE
CODE	https://www.w3.org/TR/html4/struct/text.html#edef-CODE
COL	https://www.w3.org/TR/html4/struct/tables.html#edef-COL
COLGROUP	https://www.w3.org/TR/html4/struct/tables.html#edef-COLGROUP
DD	https://www.w3.org/TR/html4/struct/lists.html#edef-DD
DEL	https://www.w3.org/TR/html4/struct/text.html#edef-del
DFN	https://www.w3.org/TR/html4/struct/text.html#edef-DFN
DIR	https://www.w3.org/TR/html4/struct/lists.html#edef-DIR
DIV	https://www.w3.org/TR/html4/struct/global.html#edef-DIV
DL	https://www.w3.org/TR/html4/struct/lists.html#edef-DL
DT	https://www.w3.org/TR/html4/struct/lists.html#edef-DT
EM	https://www.w3.org/TR/html4/struct/text.html#edef-EM
FIELDSET	https://www.w3.org/TR/html4/interact/forms.html#edef-FIELDSET
FONT	https://www.w3.org/TR/html4/present/graphics.html#edef-FONT
FORM	https://www.w3.org/TR/html4/interact/forms.html#edef-FORM
FRAME	https://www.w3.org/TR/html4/present/frames.html#edef-FRAME
FRAMESET	https://www.w3.org/TR/html4/present/frames.html#edef-FRAMESET
H1	https://www.w3.org/TR/html4/struct/global.html#edef-H1
H2	https://www.w3.org/TR/html4/struct/global.html#edef-H2
H3	https://www.w3.org/TR/html4/struct/global.html#edef-H3
H4	https://www.w3.org/TR/html4/struct/global.html#edef-H4
H5	https://www.w3.org/TR/html4/struct/global.html#edef-H5
H6	https://www.w3.org/TR/html4/struct/global.html#edef-H6
HEAD	https://www.w3.org/TR/html4/struct/global.html#edef-HEAD
HR	https://www.w3.org/TR/html4/present/graphics.html#edef-HR
HTML	https://www.w3.org/TR/html4/struct/global.html#edef-HTML
I	https://www.w3.org/TR/html4/present/graphics.html#edef-I
IFRAME	https://www.w3.org/TR/html4/present/frames.html#edef-IFRAME
IMG	https://www.w3.org/TR/html4/struct/objects.html#edef-IMG
INPUT	https://www.w3.org/TR/html4/interact/forms.html#edef-INPUT
INS	https://www.w3.org/TR/html4/struct/text.html#edef-ins
ISINDEX	https://www.w3.org/TR/html4/interact/forms.html#edef-ISINDEX
KBD	https://www.w3.org/TR/html4/struct/text.html#edef-KBD
LABEL	https://www.w3.org/TR/html4/interact/forms.html#edef-LABEL
LEGEND	https://www.w3.org/TR/html4/interact/forms.html#edef-LEGEND
LI	https://www.w3.org/TR/html4/struct/lists.html#edef-LI
LINK	https://www.w3.org/TR/html4/struct/links.html#edef-LINK
MAP	https://www.w3.org/TR/html4/struct/objects.html#edef-MAP
MENU	https://www.w3.org/TR/html4/struct/lists.html#edef-MENU
META	https://www.w3.org/TR/html4/struct/global.html#edef-META
NOFRAMES	https://www.w3.org/TR/html4/present/frames.html#edef-NOFRAMES
NOSCRIPT	https://www.w3.org/TR/html4/interact/scripts.html#edef-NOSCRIPT
OBJECT	https://www.w3.org/TR/html4/struct/objects.html#edef-OBJECT
OL	https://www.w3.org/TR/html4/struct/lists.html#edef-OL
OPTGROUP	https://www.w3.org/TR/html4/interact/forms.html#edef-OPTGROUP
OPTION	https://www.w3.org/TR/html4/interact/forms.html#edef-OPTION
P	https://www.w3.org/TR/html4/struct/text.html#edef-P
PARAM	https://www.w3.org/TR/html4/struct/objects.html#edef-PARAM
PRE	https://www.w3.org/TR/html4/struct/text.html#edef-PRE
Q	https://www.w3.org/TR/html4/struct/text.html#edef-Q
S	https://www.w3.org/TR/html4/present/graphics.html#edef-S
SAMP	https://www.w3.org/TR/html4/struct/text.html#edef-SAMP
SCRIPT	https://www.w3.org/TR/html4/interact/scripts.html#edef-SCRIPT
SELECT	https://www.w3.org/TR/html4/interact/forms.html#edef-SELECT
SMALL	https://www.w3.org/TR/html4/present/graphics.html#edef-SMALL
SPAN	https://www.w3.org/TR/html4/struct/global.html#edef-SPAN
STRIKE	https://www.w3.org/TR/html4/present/graphics.html#edef-STRIKE
STRONG	https://www.w3.org/TR/html4/struct/text.html#edef-STRONG
STYLE	https://www.w3.org/TR/html4/present/styles.html#edef-STYLE
SUB	https://www.w3.org/TR/html4/struct/text.html#edef-SUB
SUP	https://www.w3.org/TR/html4/struct/text.html#edef-SUP
TABLE	https://www.w3.org/TR/html4/struct/tables.html#edef-TABLE
TBODY	https://www.w3.org/TR/html4/struct/tables.html#edef-TBODY
TD	https://www.w3.org/TR/html4/struct/tables.html#edef-TD
TEXTAREA	https://www.w3.org/TR/html4/interact/forms.html#edef-TEXTAREA
TFOOT	https://www.w3.org/TR/html4/struct/tables.html#edef-TFOOT
TH	https://www.w3.org/TR/html4/struct/tables.html#edef-TH
THEAD	https://www.w3.org/TR/html4/struct/tables.html#edef-THEAD
TITLE	https://www.w3.org/TR/html4/struct/global.html#edef-TITLE
TR	https://www.w3.org/TR/html4/struct/tables.html#edef-TR
TT	https://www.w3.org/TR/html4/present/graphics.html#edef-TT
U	https://www.w3.org/TR/html4/present/graphics.html#edef-U
UL	https://www.w3.org/TR/html4/struct/lists.html#edef-UL
VAR	https://www.w3.org/TR/html4/struct/text.html#edef-VAR}) {
    my @l = split /\t/, $_;
    $EDefs->{lc $l[0]}->{_html4_url} = $l[1];
    if (not $EDefs->{lc $l[0]}->{_html4_frameset}) {
      $EDefs->{lc $l[0]}->{_html4_strict} = 1;
      $EDefs->{lc $l[0]}->{_html4_transitional} = 1;
      $EDefs->{lc $l[0]}->{_html4_frameset} = 1;
    }
  }
}

for (qw(a address area blockquote body button col colgroup head html
        h1 h2 h3 h4 h5 h6 img input label link map object q style
        table tbody td th tr
        pre-html )) {
  $EDefs->{$_}->{_isohtml_url} = "https://web.archive.org/web/20050530074719/http://woodworm.cs.uml.edu/~rprice/15445/UG.html#" . uc $_;
}
$EDefs->{$_}->{_isohtml_url} = "https://web.archive.org/web/20050530074719/http://woodworm.cs.uml.edu/~rprice/15445/UG.html#H1.PREP"
    for qw(div1 div2 div3 div4 div5 div6);

{
  my $path = $ThisPath->child ('local/dtdinfo/xhtml10s.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_xhtml10s} = 1 for keys %{$json->{elements}};
}
{
  my $path = $ThisPath->child ('local/dtdinfo/xhtml10t.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_xhtml10t} = 1 for keys %{$json->{elements}};
}
{
  my $path = $ThisPath->child ('local/dtdinfo/xhtml10f.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_xhtml10f} = 1 for keys %{$json->{elements}};
}

for (
  ['An Example Abstract Module Definition', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#sec_4.4.1." => "XHTML Skiing Module" => [qw(resort lodge lift chalet room lobby fireplace description)], "example"],
  ['Core Modules', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_structuremodule" => "Structure Module" => [qw(body head html title)], "required"],
  ['Core Modules', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_textmodule" => "Text Module" => [qw(address blockquote pre h1 h2 h3 h4 h5 h6)], "required", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Block_Phrasal", "XHTML Block Phrasal Module"],
  ['Core Modules', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_textmodule" => "Text Module" => [qw(div  p)], "required", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Block_Structural", "XHTML Block Structural Module"],
  ['Core Modules', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_textmodule" => "Text Module" => [qw(abbr acronym  cite code dfn  em kbd q samp strong var)], "required", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Inline_Phrasal", "XHTML Inline Phrasal Module"],
  ['Core Modules', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_textmodule" => "Text Module" => [qw(br span)], "required", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Inline_Structural", "XHTML Inline Structural Module"],
  ['Core Modules', "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_hypertextmodule", "Hypertext Module", [qw(a)], "required"],
  ["Core Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_listmodule", "List Module", [qw(dl dt dd ol ul li)], "required"],
  ["Core Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_appletmodule", "Applet Module", [qw(applet)], "deprecated"],
  ["Core Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_appletmodule", "Applet Module", [qw(param)], "deprecated", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Param", "XHTML Param Element Module"],
  ["Text Extension Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_presentationmodule", "Presentation Module", [qw(hr)], undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Block_Presentational", "XHTML Block Presentation Module"],
  ["Text Extension Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_presentationmodule", "Presentation Module", [qw(b big i small sub sup tt)], undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Inline_Presentational", "XHTML Inline Presentational Module"],
  ["Text Extension Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_editmodule", "Edit Module", [qw(del ins)]],
  ["Text Extension Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_bdomodule", "Bi-directional Text Module", [qw(bdo)]],
  ["Forms Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_sformsmodule", "Basic Forms Module", [qw(form input label select option textarea)]],
  ["Forms Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_extformsmodule", "Forms Module", [qw(form input select option textarea button fieldset label legend optgroup)]],
  ["Table Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_simpletablemodule", "Basic Tables Module", [qw(table caption td th tr)]],
  ["Table Modules", "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_tablemodule", "Tables Module", [qw(caption table td th tr col colgroup tbody thead tfoot)]],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_imagemodule", "Image Module", [qw(img)]],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_imapmodule", "Client-side Image Map Module", [qw(area map)]],
  #https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_servermapmodule Server-side Image Map Module
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_objectmodule", "Object Module", [qw(object)], undef],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_objectmodule", "Object Module", [qw(param)], undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_Param", "XHTML Param Element Module"],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_framesmodule", "Frames Module", [qw(frameset frame noframes)]],
  #https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_targetmodule Target Module
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_iframemodule", "Iframe Module", [qw(iframe)]],
  #https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_intrinsiceventsmodule Intrinsic Events Module,
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_metamodule", "Metainformation Module", [qw(meta)]],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_scriptmodule", "Scripting Module", [qw(noscript script)]],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_stylemodule", "Style Sheet Module", [qw(style)]],
  #https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_styleattributemodule Style Attribute Module
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_linkmodule", "Link Module", [qw(link)]],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_basemodule", "Base Module", [qw(base)]],
  #https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_nameidentmodule Name Identification Module deprecated
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#s_legacymodule", "Legacy Module", [qw(basefont center dir font isindex menu s strike u )], "deprecated"],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_smodule_Ruby", "Ruby", [qw(ruby rbc rtc rb rt rp)]],
  [undef, "https://www.w3.org/TR/2010/REC-xhtml-modularization-20100729/xhtml-modularization.html#a_module_XHTML_Qualified_Names", "xhtml-image-2.mod", [qw(alt)], "provisional"],
) {
  my ($mgroup, $url, $mname, $els, $mode, $surl, $sname) = @$_;
  for my $el (@$els) {
    $EDefs->{$el}->{_m12n_url} = $url;
    $EDefs->{$el}->{_m12n_module}->{$mname} = {
      group => $mgroup,
      name => $mname,
    };
    $EDefs->{$el}->{_m12n_module}->{$mname}->{support} = {
      url => $surl,
      name => $sname,
    } if defined $surl;
    $EDefs->{$el}->{_m12n_module}->{$mname}->{$mode} = 1 if defined $mode;
  }
}

{
  my $path = $ThisPath->child ('local/dtdinfo/xhtml-basic10.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_basic10} = 1 for keys %{$json->{elements}};
}

{
  my $path = $ThisPath->child ('local/dtdinfo/xhtml-print10.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_print10} = 1 for keys %{$json->{elements}};
}

{
  my $path = $ThisPath->child ('local/dtdinfo/xhtml11.json');
  my $json = json_bytes2perl $path->slurp;
  $EDefs->{$_}->{_xhtml11} = 1 for keys %{$json->{elements}};
}

{
  for (
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_documentmodule", 'XHTML Document Module', [qw(html head title body)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_structuralmodule", "XHTML Structural Module", [qw(address blockcode blockquote div h p pre section separator)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_textmodule", "XHTML Text Module", [qw(abbr br cite code dfn em kbd l q samp span strong sub sup var )]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_hypertextmodule", "XHTML Hypertext Module", [qw(a)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_listmodule", "XHTML List Module", [qw(dl di dt dd ul li ol)]],
    #XHTML Core Attributes Module
    #XHTML Hypertext Attributes Module
    #XHTML I18N Attribute Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_accessmodule", "XHTML Access Module", [qw(access)]],
    #XHTML Bi-directional Text Attribute Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_captionmodule", "XHTML Caption Module", [qw(caption)]],
    #XHTML Edit Attributes Module
    #XHTML Embedding Attributes Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_imagemodule", "XHTML Image Module", [qw(img)]],
    #XHTML Image Map Attributes Module
    #XHTML Media Attribute Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_metamodule", "XHTML Metainformation Module", [qw(link meta)]],
    #XHTML Metainformation Attributes Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_objectmodule", "XHTML Object Module", [qw(object param standby)]],
    #XHTML Role Attribute Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_rubymodule", "Ruby Module", [qw(rb rt rp rbc rtc)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_styleSheetmodule", "XHTML Style Sheet Module", [qw(style)]],
    #XHTML Style Attribute Module
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_tablesmodule", "XHTML Tables Module", [qw(table summary col colgroup thead tfoot tbody tr td th )]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_xformsmodule", "XForms Module", [
      # 4.
      qw(model input secret textarea output upload range trigger submit select select1 action dispatch rebuild recalculate revalidate refresh setfocus load setvalue send reset message insert delete setindex group switch repeat),
      # 31.
      qw(model
         input secret textarea output upload range trigger submit select select1
         action dispatch rebuild recalculate revalidate refresh setfocus load setvalue send reset message insert delete setindex 
         group 
         switch 
         repeat),
    ]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_xml-eventsmodule", "XML Events Module", [qw(listener)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_handlermodule", "XML Handlers Module", [qw(action dispatchEvent addEventListener removeEventListener stopPropagation preventDefault)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_scriptingmodule", "XML Scripting Module", [qw(script)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_legacy-editmodule", "XHTML Legacy Edit Module", [qw(del ins)]],
    ["https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_legacy-headingsmodule", "XHTML Legacy Headings Module", [qw(h1 h2 h3 h4 h5 h6)]],
  ) {
    my ($murl, $mname, $els, $mode) = @$_;
    $EDefs->{$_}->{_xhtml2_module}->{$mname}->{url} = $murl for @$els;
    $murl =~ m{#s_(.+)module} or die $murl;
    my $mkey = $1;
    if ($mkey eq 'ruby') {
      $EDefs->{$_}->{_xhtml2_url} = q{https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#edef_} . $mkey . q{_} . $_
          for 'ruby';
      $EDefs->{$_}->{_xhtml2_url} //= $murl for @$els;
    } else {
      $EDefs->{$_}->{_xhtml2_url} = q{https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#edef_} . $mkey . q{_} . $_
          for @$els;
    }
  }
  for (qw(
    nl label rules
    alert bind case choices copy delete extension filename group help hint input insert instance item itemset label load mediatype message model output range rebuild recalculate refresh repeat reset revalidate secret select select1 send setfocus setindex setvalue submission submit switch textarea toggle trigger upload value
   )) { # dup
    $EDefs->{$_}->{_xhtml2_url} //= q{https://www.w3.org/TR/2010/NOTE-xhtml2-20101216/xhtml2.html#s_doctype};
  }
  # non-HTML ns : line
}

{
  for (qw(
    a abbr address area article aside audio b base bdo blockquote body br button canvas caption cite code col colgroup command datalist dd del details dfn div dl dt em embed fieldset figure footer form h1 h2 h3 h4 h5 h6 head header hgroup hr html i iframe img input ins kbd keygen label legend li link map mark menu meta meter nav noscript object ol optgroup option output p param pre progress q rp rt ruby samp script section select small source span strong style sub sup table tbody td textarea tfoot th thead time title tr ul var video
  )) {
    $EDefs->{$_}->{_html5} = 1;
  }
  for (qw(applet acronym dir frame frameset noframes isindex listing
          xmp nextid noembed plaintext rb basefont big blink center
          font marquee s spacer strike tt u)) {
    $EDefs->{$_}->{_html5_obsolete} = 1;
  }
}

{
  ## <https://www.w3.org/TR/2001/REC-SVG-20010904/eltindex.html>
  my %w = qw(
a https://www.w3.org/TR/2001/REC-SVG-20010904/linking.html#AElement
altGlyph https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#AltGlyphElement
altGlyphDef https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#AltGlyphDefElement
altGlyphItem https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#AltGlyphItemElement
animate https://www.w3.org/TR/2001/REC-SVG-20010904/animate.html#AnimateElement
animateColor https://www.w3.org/TR/2001/REC-SVG-20010904/animate.html#AnimateColorElement
animateMotion https://www.w3.org/TR/2001/REC-SVG-20010904/animate.html#AnimateMotionElement
animateTransform https://www.w3.org/TR/2001/REC-SVG-20010904/animate.html#AnimateTransformElement
circle https://www.w3.org/TR/2001/REC-SVG-20010904/shapes.html#CircleElement
clipPath https://www.w3.org/TR/2001/REC-SVG-20010904/masking.html#ClipPathElement
color-profile https://www.w3.org/TR/2001/REC-SVG-20010904/color.html#ColorProfileElement
cursor https://www.w3.org/TR/2001/REC-SVG-20010904/interact.html#CursorElement
definition-src https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#DefinitionSrcElement
defs https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#DefsElement
desc https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#DescElement
ellipse https://www.w3.org/TR/2001/REC-SVG-20010904/shapes.html#EllipseElement
feBlend https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feBlendElement
feColorMatrix https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feColorMatrixElement
feComponentTransfer https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feComponentTransferElement
feComposite https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feCompositeElement
feConvolveMatrix https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feConvolveMatrixElement
feDiffuseLighting https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feDiffuseLightingElement
feDisplacementMap https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feDisplacementMapElement
feDistantLight https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feDistantLightElement
feFlood https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feFloodElement
feFuncA https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feFuncAElement
feFuncB https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feFuncBElement
feFuncG https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feFuncGElement
feFuncR https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feFuncRElement
feGaussianBlur https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feGaussianBlurElement
feImage https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feImageElement
feMerge https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feMergeElement
feMergeNode https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feMergeNodeElement
feMorphology https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feMorphologyElement
feOffset https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feOffsetElement
fePointLight https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#fePointLightElement
feSpecularLighting https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feSpecularLightingElement
feSpotLight https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feSpotLightElement
feTile https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feTileElement
feTurbulence https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#feTurbulenceElement
filter https://www.w3.org/TR/2001/REC-SVG-20010904/filters.html#FilterElement
font https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#FontElement
font-face https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#FontFaceElement
font-face-format https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#FontFaceNameElement
font-face-name https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#FontFaceNameElement
font-face-src https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#FontFaceSrcElement
font-face-uri https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#FontFaceNameElement
foreignObject https://www.w3.org/TR/2001/REC-SVG-20010904/extend.html#ForeignObjectElement
g https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#GElement
glyph https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#GlyphElement
glyphRef https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#GlyphRefElement
hkern https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#HKernElement
image https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#ImageElement
line https://www.w3.org/TR/2001/REC-SVG-20010904/shapes.html#LineElement
linearGradient https://www.w3.org/TR/2001/REC-SVG-20010904/pservers.html#LinearGradientElement
marker https://www.w3.org/TR/2001/REC-SVG-20010904/painting.html#MarkerElement
mask https://www.w3.org/TR/2001/REC-SVG-20010904/masking.html#MaskElement
metadata https://www.w3.org/TR/2001/REC-SVG-20010904/metadata.html#MetadataElement
missing-glyph https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#MissingGlyphElement
mpath https://www.w3.org/TR/2001/REC-SVG-20010904/animate.html#mpathElement
path https://www.w3.org/TR/2001/REC-SVG-20010904/paths.html#PathElement
pattern https://www.w3.org/TR/2001/REC-SVG-20010904/pservers.html#PatternElement
polygon https://www.w3.org/TR/2001/REC-SVG-20010904/shapes.html#PolygonElement
polyline https://www.w3.org/TR/2001/REC-SVG-20010904/shapes.html#PolylineElement
radialGradient https://www.w3.org/TR/2001/REC-SVG-20010904/pservers.html#RadialGradientElement
rect https://www.w3.org/TR/2001/REC-SVG-20010904/shapes.html#RectElement
script https://www.w3.org/TR/2001/REC-SVG-20010904/script.html#ScriptElement
set https://www.w3.org/TR/2001/REC-SVG-20010904/animate.html#SetElement
stop https://www.w3.org/TR/2001/REC-SVG-20010904/pservers.html#StopElement
style https://www.w3.org/TR/2001/REC-SVG-20010904/styling.html#StyleElement
svg https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#SVGElement
switch https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#SwitchElement
symbol https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#SymbolElement
text https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#TextElement
textPath https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#TextPathElement
title https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#TitleElement
tref https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#TRefElement
tspan https://www.w3.org/TR/2001/REC-SVG-20010904/text.html#TSpanElement
use https://www.w3.org/TR/2001/REC-SVG-20010904/struct.html#UseElement
view https://www.w3.org/TR/2001/REC-SVG-20010904/linking.html#ViewElement
vkern https://www.w3.org/TR/2001/REC-SVG-20010904/fonts.html#VKernElement
);
  for (keys %w) {
    $EDefs->{$_}->{_svg}->{svg10} = $w{$_};
  }

  ## <https://www.w3.org/TR/2003/REC-SVG11-20030114/eltindex.html>
  my %x = qw(
a https://www.w3.org/TR/2003/REC-SVG11-20030114/linking.html#AElement
altGlyph https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#AltGlyphElement
altGlyphDef https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#AltGlyphDefElement
altGlyphItem https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#AltGlyphItemElement
animate https://www.w3.org/TR/2003/REC-SVG11-20030114/animate.html#AnimateElement
animateColor https://www.w3.org/TR/2003/REC-SVG11-20030114/animate.html#AnimateColorElement
animateMotion https://www.w3.org/TR/2003/REC-SVG11-20030114/animate.html#AnimateMotionElement
animateTransform https://www.w3.org/TR/2003/REC-SVG11-20030114/animate.html#AnimateTransformElement
circle https://www.w3.org/TR/2003/REC-SVG11-20030114/shapes.html#CircleElement
clipPath https://www.w3.org/TR/2003/REC-SVG11-20030114/masking.html#ClipPathElement
color-profile https://www.w3.org/TR/2003/REC-SVG11-20030114/color.html#ColorProfileElement
cursor https://www.w3.org/TR/2003/REC-SVG11-20030114/interact.html#CursorElement
definition-src https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#DefinitionSrcElement
defs https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#DefsElement
desc https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#DescElement
ellipse https://www.w3.org/TR/2003/REC-SVG11-20030114/shapes.html#EllipseElement
feBlend https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feBlendElement
feColorMatrix https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feColorMatrixElement
feComponentTransfer https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feComponentTransferElement
feComposite https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feCompositeElement
feConvolveMatrix https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feConvolveMatrixElement
feDiffuseLighting https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feDiffuseLightingElement
feDisplacementMap https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feDisplacementMapElement
feDistantLight https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feDistantLightElement
feFlood https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feFloodElement
feFuncA https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feFuncAElement
feFuncB https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feFuncBElement
feFuncG https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feFuncGElement
feFuncR https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feFuncRElement
feGaussianBlur https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feGaussianBlurElement
feImage https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feImageElement
feMerge https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feMergeElement
feMergeNode https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feMergeNodeElement
feMorphology https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feMorphologyElement
feOffset https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feOffsetElement
fePointLight https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#fePointLightElement
feSpecularLighting https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feSpecularLightingElement
feSpotLight https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feSpotLightElement
feTile https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feTileElement
feTurbulence https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#feTurbulenceElement
filter https://www.w3.org/TR/2003/REC-SVG11-20030114/filters.html#FilterElement
font https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#FontElement
font-face https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#FontFaceElement
font-face-format https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#FontFaceNameElement
font-face-name https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#FontFaceNameElement
font-face-src https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#FontFaceSrcElement
font-face-uri https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#FontFaceNameElement
foreignObject https://www.w3.org/TR/2003/REC-SVG11-20030114/extend.html#ForeignObjectElement
g https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#GElement
glyph https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#GlyphElement
glyphRef https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#GlyphRefElement
hkern https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#HKernElement
image https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#ImageElement
line https://www.w3.org/TR/2003/REC-SVG11-20030114/shapes.html#LineElement
linearGradient https://www.w3.org/TR/2003/REC-SVG11-20030114/pservers.html#LinearGradientElement
marker https://www.w3.org/TR/2003/REC-SVG11-20030114/painting.html#MarkerElement
mask https://www.w3.org/TR/2003/REC-SVG11-20030114/masking.html#MaskElement
metadata https://www.w3.org/TR/2003/REC-SVG11-20030114/metadata.html#MetadataElement
missing-glyph https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#MissingGlyphElement
mpath https://www.w3.org/TR/2003/REC-SVG11-20030114/animate.html#mpathElement
path https://www.w3.org/TR/2003/REC-SVG11-20030114/paths.html#PathElement
pattern https://www.w3.org/TR/2003/REC-SVG11-20030114/pservers.html#PatternElement
polygon https://www.w3.org/TR/2003/REC-SVG11-20030114/shapes.html#PolygonElement
polyline https://www.w3.org/TR/2003/REC-SVG11-20030114/shapes.html#PolylineElement
radialGradient https://www.w3.org/TR/2003/REC-SVG11-20030114/pservers.html#RadialGradientElement
rect https://www.w3.org/TR/2003/REC-SVG11-20030114/shapes.html#RectElement
script https://www.w3.org/TR/2003/REC-SVG11-20030114/script.html#ScriptElement
set https://www.w3.org/TR/2003/REC-SVG11-20030114/animate.html#SetElement
stop https://www.w3.org/TR/2003/REC-SVG11-20030114/pservers.html#StopElement
style https://www.w3.org/TR/2003/REC-SVG11-20030114/styling.html#StyleElement
svg https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#SVGElement
switch https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#SwitchElement
symbol https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#SymbolElement
text https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#TextElement
textPath https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#TextPathElement
title https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#TitleElement
tref https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#TRefElement
tspan https://www.w3.org/TR/2003/REC-SVG11-20030114/text.html#TSpanElement
use https://www.w3.org/TR/2003/REC-SVG11-20030114/struct.html#UseElement
view https://www.w3.org/TR/2003/REC-SVG11-20030114/linking.html#ViewElement
vkern https://www.w3.org/TR/2003/REC-SVG11-20030114/fonts.html#VKernElement);
  for (keys %x) {
    $EDefs->{$_}->{_svg}->{svg11} = $x{$_};
  }

  ## <https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html>
  my %y = qw(
a https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#linking-AElement
animate https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#animate-AnimateElement
animateColor https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#animate-AnimateColorElement
animateMotion https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#animate-AnimateMotionElement
animateTransform https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#animate-AnimateTransformElement
animation https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#multimedia-AnimationElement
audio https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#multimedia-AudioElement
circle https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#shapes-CircleElement
defs https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-DefsElement
desc https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-TitleAndDescriptionElements
discard https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-DiscardElement
ellipse https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#shapes-EllipseElement
font https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-FontElement
font-face https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-FontFaceElement
font-face-src https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-FontFaceSrcElement
font-face-uri https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-FontFaceUriElement
foreignObject https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#extend-ForeignObjectElement
g https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-GElement
glyph https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-GlyphElement
handler https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#script-HandlerElement
hkern https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-KernElements
image https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-ImageElement
line https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#shapes-LineElement
linearGradient https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#painting-LinearGradientElement
listener https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#script-ListenerElement
metadata https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#metadata-MetadataElement
missing-glyph https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#fonts-MissingGlyphElement
mpath https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#animate-MpathElement
path https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#paths-PathElement
polygon https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#shapes-PolygonElement
polyline https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#shapes-PolylineElement
prefetch https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-PrefetchElement
radialGradient https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#painting-RadialGradientElement
rect https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#shapes-RectElement
script https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#script-ScriptElement
set https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#animate-SetElement
solidColor https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#painting-SolidColorElement
stop https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#painting-StopElement
svg https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-SVGElement
switch https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-SwitchElement
tbreak https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#text-tbreakElement
text https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#text-TextElement
textArea https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#text-TextAreaElement
title https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-TitleAndDescriptionElements
tspan https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#text-TSpanElement
use https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#struct-UseElement
video https://www.w3.org/TR/2008/REC-SVGTiny12-20081222/single-page.html#multimedia-VideoElement
  );
  for (keys %y) {
    $EDefs->{$_}->{_svg}->{svgt12} = $y{$_};
  }

  ## <https://svgwg.org/svg2-draft/eltindex.html>
  my %z = qw(
a https://svgwg.org/svg2-draft/linking.html#AElement
animate https://svgwg.org/specs/animations/#AnimateElement
animateMotion https://svgwg.org/specs/animations/#AnimateMotionElement
animateTransform https://svgwg.org/specs/animations/#AnimateTransformElement
circle https://svgwg.org/svg2-draft/shapes.html#CircleElement
clipPath https://drafts.fxtf.org/css-masking-1/#ClipPathElement
defs https://svgwg.org/svg2-draft/struct.html#DefsElement
desc https://svgwg.org/svg2-draft/struct.html#DescElement
discard https://svgwg.org/specs/animations/#DiscardElement
ellipse https://svgwg.org/svg2-draft/shapes.html#EllipseElement
feBlend https://drafts.fxtf.org/filter-effects/#feBlendElement
feColorMatrix https://drafts.fxtf.org/filter-effects/#feColorMatrixElement
feComponentTransfer https://drafts.fxtf.org/filter-effects/#feComponentTransferElement
feComposite https://drafts.fxtf.org/filter-effects/#feCompositeElement
feConvolveMatrix https://drafts.fxtf.org/filter-effects/#feConvolveMatrixElement
feDiffuseLighting https://drafts.fxtf.org/filter-effects/#feDiffuseLightingElement
feDisplacementMap https://drafts.fxtf.org/filter-effects/#feDisplacementMapElement
feDistantLight https://drafts.fxtf.org/filter-effects/#feDistantLightElement
feDropShadow https://drafts.fxtf.org/filter-effects/#feDropShadowElement
feFlood https://drafts.fxtf.org/filter-effects/#feFloodElement
feFuncA https://drafts.fxtf.org/filter-effects/#feFuncAElement
feFuncB https://drafts.fxtf.org/filter-effects/#feFuncBElement
feFuncG https://drafts.fxtf.org/filter-effects/#feFuncGElement
feFuncR https://drafts.fxtf.org/filter-effects/#feFuncRElement
feGaussianBlur https://drafts.fxtf.org/filter-effects/#feGaussianBlurElement
feImage https://drafts.fxtf.org/filter-effects/#feImageElement
feMerge https://drafts.fxtf.org/filter-effects/#feMergeElement
feMergeNode https://drafts.fxtf.org/filter-effects/#feMergeElement
feMorphology https://drafts.fxtf.org/filter-effects/#feMorphologyElement
feOffset https://drafts.fxtf.org/filter-effects/#feOffsetElement
fePointLight https://drafts.fxtf.org/filter-effects/#fePointLightElement
feSpecularLighting https://drafts.fxtf.org/filter-effects/#feSpecularLightingElement
feSpotLight https://drafts.fxtf.org/filter-effects/#feSpotLightElement
feTile https://drafts.fxtf.org/filter-effects/#feTileElement
feTurbulence https://drafts.fxtf.org/filter-effects/#feTurbulenceElement
filter https://drafts.fxtf.org/filter-effects/#FilterElement
foreignObject https://svgwg.org/svg2-draft/embedded.html#ForeignObjectElement
g https://svgwg.org/svg2-draft/struct.html#GElement
image https://svgwg.org/svg2-draft/embedded.html#ImageElement
line https://svgwg.org/svg2-draft/shapes.html#LineElement
linearGradient https://svgwg.org/svg2-draft/pservers.html#LinearGradientElement
marker https://svgwg.org/svg2-draft/painting.html#MarkerElement
mask https://drafts.fxtf.org/css-masking-1/#MaskElement
metadata https://svgwg.org/svg2-draft/struct.html#MetadataElement
mpath https://svgwg.org/specs/animations/#MPathElement
path https://svgwg.org/svg2-draft/paths.html#PathElement
pattern https://svgwg.org/svg2-draft/pservers.html#PatternElement
polygon https://svgwg.org/svg2-draft/shapes.html#PolygonElement
polyline https://svgwg.org/svg2-draft/shapes.html#PolylineElement
radialGradient https://svgwg.org/svg2-draft/pservers.html#RadialGradientElement
rect https://svgwg.org/svg2-draft/shapes.html#RectElement
script https://svgwg.org/svg2-draft/interact.html#ScriptElement
set https://svgwg.org/specs/animations/#SetElement
stop https://svgwg.org/svg2-draft/pservers.html#StopElement
style https://svgwg.org/svg2-draft/styling.html#StyleElement
svg https://svgwg.org/svg2-draft/struct.html#SVGElement
switch https://svgwg.org/svg2-draft/struct.html#SwitchElement
symbol https://svgwg.org/svg2-draft/struct.html#SymbolElement
text https://svgwg.org/svg2-draft/text.html#TextElement
textPath https://svgwg.org/svg2-draft/text.html#TextPathElement
title https://svgwg.org/svg2-draft/struct.html#TitleElement
tspan https://svgwg.org/svg2-draft/text.html#TextElement
use https://svgwg.org/svg2-draft/struct.html#UseElement
view https://svgwg.org/svg2-draft/linking.html#ViewElement
);
  for (keys %z) {
    $EDefs->{$_}->{_svg}->{svg2} = $z{$_};
  }
}

{
  my %z = qw(
abs https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.abs
and https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.and
annotation https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter5.html#mixing.elements.annotation
annotation-xml https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter5.html#mixing.elements.annotation.xml
apply https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.apply
approx https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.approx
arccos https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arccosh https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arccot https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arccoth https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arccsc https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arccsch https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arcsec https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arcsech https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arcsin https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arcsinh https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arctan https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arctanh https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
arg https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.arg
bind https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.binding
bvar https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.binding
card https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.card
cartesianproduct https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.cartesianproduct
cbytes https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.cbytes
ceiling https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.ceiling
cerror https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.cerror
ci https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.ci
cn https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.cn
codomain https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.codomain
complexes https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.complexes
compose https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.compose
condition https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.domainofapplication.qualifier
conjugate https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.conjugate
cos https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
cosh https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
cot https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
coth https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
cs https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.cs
csc https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
csch https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
csymbol https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.csymbol
curl https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.curl
declare https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.declare
degree https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.degree
determinant https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.determinant
diff https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.diff
divergence https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.divergence
divide https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.divide
domain https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.domain
domainofapplication https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.domainofapplication.qualifier
el https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.eq
emptyset https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.emptyset
eq https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.eq
equivalent https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.equivalent
eulergamma https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.eulergamma
exists https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.exists
exp https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.exp
exponentiale https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.exponentiale
factorial https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.factorial
factorof https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.factorof
false https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.false
floor https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.floor
fn https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.container
forall https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.forall
gcd https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.gcd
geq https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.geq
grad https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.grad
gt https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.gt
ident https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.ident
image https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.image
imaginary https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.imaginary
imaginaryi https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.imaginaryi
implies https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.implies
in https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.in
infinity https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.infinity
int https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.int
integers https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.integers
intersect https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.intersect
interval https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.domainofapplication.qualifier
inverse https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.inverse
lambda https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.lambda
laplacian https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.laplacian
lcm https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.lcm
leq https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.leq
limit https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.limit
list https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.list
ln https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.ln
log https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.log
logbase https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.otherqualifiers
lowlimit https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.domainofapplication.qualifier
lt https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.lt
maction https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.maction
malign https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#id.3.3.9.2
maligngroup https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.malign
malignmark https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.malign
malignscope https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#id.3.5.5.1
math https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter2.html#interf.toplevel
matrix https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.matrix
matrixrow https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.matrixrow
max https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.max
mean https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.mean
median https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.median
menclose https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.menclose
merror https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.merror
mfenced https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mfenced
mfrac https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mfrac
mfraction https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#id.3.3.5.3
mglyph https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mglyph
mi https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mi
min https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.min
minus https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.minus
mlabeledtr https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mlabeledtr
mlongdiv https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mlongdiv
mmultiscripts https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mmultiscripts
mn https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mn
mo https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mo
mode https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.mode
moment https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.moment
momentabout https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.otherqualifiers
mover https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mover
mpadded https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mpadded
mphantom https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mphantom
mprescripts https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#id.3.4.7.1
mroot https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mroot
mrow https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.inferredmrow
ms https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.ms
mscarries https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mscarries
mscarry https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mscarry
msgroup https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.msgroup
msline https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.msline
mspace https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mspace
msqrt https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mroot
msrow https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.msrow
mstack https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mstack
mstyle https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mstyle
msub https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.msub
msubsup https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.msubsup
msup https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.msup
mtable https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mtable
mtd https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mtd
mtext https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mtext
mtr https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.mtr
munder https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.munder
munderover https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#presm.munderover
naturalnumbers https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.naturalnumbers
neq https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.neq
none https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter3.html#id.3.4.7.1
not https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.not
notanumber https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.notanumber
note https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.not
notin https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.notin
notprsubset https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.notprsubset
notsubset https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.notsubset
or https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.or
otherwise https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.piecewise
outerproduct https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.outerproduct
partialdiff https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.partialdiff
pi https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.pi
piece https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.piecewise
piecewise https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.piecewise
plus https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.plus
power https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.power
primes https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.primes
product https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.product
prsubset https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.prsubset
quotient https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.quotient
rationals https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.rationals
real https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.real
reals https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.reals
reln https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.container
rem https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.rem
root https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.root
scalarproduct https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.scalarproduct
sdev https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.sdev
sec https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
sech https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
selector https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.selector
semantics https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.semantics
sep https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.cn
set https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.set
setdiff https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.setdiff
share https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.sharing
sin https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.strict
sinh https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
subset https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.subset
sum https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.sum
tan https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
tanh https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.trig
tendsto https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.tendsto
times https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.times
transpose https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.transpose
true https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.true
union https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.union
uplimit https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.domainofapplication.qualifier
variance https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.variance
vector https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.vector
vectorproduct https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.vectorproduct
xor https://www.w3.org/TR/2010/REC-MathML3-20101021/chapter4.html#contm.xor
         );
  for (keys %z) {
    $EDefs->{$_}->{_mathml}->{mathml3} = $z{$_};
    if ($z{$_} =~ /chapter3/) {
      $EDefs->{$_}->{_mathml}->{mathml3_presentation} = 1;
    }
    if ($z{$_} =~ /chapter4/) {
      $EDefs->{$_}->{_mathml}->{mathml3_content} = 1;
    }
  }
  ## https://www.w3.org/TR/2010/REC-MathML3-20101021/appendixi.html#index.elem

  ## https://w3c.github.io/mathml/spec.html#mmlindex_elements
  my %y = qw(
abs https://w3c.github.io/mathml/spec.html#contm_unary_arith
and https://w3c.github.io/mathml/spec.html#contm_nary_logical
annotation https://w3c.github.io/mathml/spec.html#mixing_elements_annotation
annotation-xml https://w3c.github.io/mathml/spec.html#mixing_elements_annotation_xml
apply https://w3c.github.io/mathml/spec.html#contm_bind_apply
approx https://w3c.github.io/mathml/spec.html#contm_binary_reln
arg https://w3c.github.io/mathml/spec.html#contm_unary_arith
bind https://w3c.github.io/mathml/spec.html#contm_variable_binding
bvar https://w3c.github.io/mathml/spec.html#contm_variable_binding
card https://w3c.github.io/mathml/spec.html#contm_unary_set
cartesianproduct https://w3c.github.io/mathml/spec.html#contm_nary_set
cbytes https://w3c.github.io/mathml/spec.html#contm_cbytes_sec
ceiling https://w3c.github.io/mathml/spec.html#contm_unary_arith
cerror https://w3c.github.io/mathml/spec.html#contm_cerror_sec
ci https://w3c.github.io/mathml/spec.html#contm_ci_sec
cn https://w3c.github.io/mathml/spec.html#contm_cn_sec
codomain https://w3c.github.io/mathml/spec.html#contm_unary_functional
compose https://w3c.github.io/mathml/spec.html#contm_nary_functional
condition https://w3c.github.io/mathml/spec.html#contm_domainofapplication_qualifier
conjugate https://w3c.github.io/mathml/spec.html#contm_unary_arith
cs https://w3c.github.io/mathml/spec.html#contm_cs_sec
csymbol https://w3c.github.io/mathml/spec.html#contm_csymbol_sec
curl https://w3c.github.io/mathml/spec.html#contm_unary_veccalc
declare https://w3c.github.io/mathml/spec.html#chg_contm
degree https://w3c.github.io/mathml/spec.html#contm_degree_sec
determinant https://w3c.github.io/mathml/spec.html#contm_unary_linalg
diff https://w3c.github.io/mathml/spec.html#contm_diff_sec
divergence https://w3c.github.io/mathml/spec.html#contm_unary_veccalc
divide https://w3c.github.io/mathml/spec.html#contm_binary_arith
domain https://w3c.github.io/mathml/spec.html#contm_unary_functional
domainofapplication https://w3c.github.io/mathml/spec.html#contm_domainofapplication_qualifier
emptyset https://w3c.github.io/mathml/spec.html#contm_p2s_op
eq https://w3c.github.io/mathml/spec.html#contm_nary_reln
equivalent https://w3c.github.io/mathml/spec.html#contm_binary_logical
exists https://w3c.github.io/mathml/spec.html#contm_p2s
exp https://w3c.github.io/mathml/spec.html#contm_unary_arith
factorial https://w3c.github.io/mathml/spec.html#contm_unary_arith
factorof https://w3c.github.io/mathml/spec.html#contm_binary_reln
floor https://w3c.github.io/mathml/spec.html#contm_unary_arith
fn https://w3c.github.io/mathml/spec.html#chg_contm
forall https://w3c.github.io/mathml/spec.html#contm_quantifier
gcd https://w3c.github.io/mathml/spec.html#contm_nary_arith
geq https://w3c.github.io/mathml/spec.html#contm_nary_reln
grad https://w3c.github.io/mathml/spec.html#contm_unary_veccalc
gt https://w3c.github.io/mathml/spec.html#contm_nary_reln
ident https://w3c.github.io/mathml/spec.html#contm_unary_functional
image https://w3c.github.io/mathml/spec.html#contm_unary_functional
imaginary https://w3c.github.io/mathml/spec.html#contm_unary_arith
implies https://w3c.github.io/mathml/spec.html#contm_binary_logical
in https://w3c.github.io/mathml/spec.html#contm_binary_set
int https://w3c.github.io/mathml/spec.html#contm_int_sec
intersect https://w3c.github.io/mathml/spec.html#contm_nary_set
interval https://w3c.github.io/mathml/spec.html#contm_domainofapplication_qualifier
inverse https://w3c.github.io/mathml/spec.html#contm_unary_functional
lambda https://w3c.github.io/mathml/spec.html#contm_lambda_sec
laplacian https://w3c.github.io/mathml/spec.html#contm_unary_veccalc
lcm https://w3c.github.io/mathml/spec.html#contm_nary_arith
leq https://w3c.github.io/mathml/spec.html#contm_nary_reln
limit https://w3c.github.io/mathml/spec.html#contm_limit_sec
list https://w3c.github.io/mathml/spec.html#contm_nary_construct_set
ln https://w3c.github.io/mathml/spec.html#contm_unary_functional
log https://w3c.github.io/mathml/spec.html#contm_otherqualifiers
logbase https://w3c.github.io/mathml/spec.html#contm_otherqualifiers
lowlimit https://w3c.github.io/mathml/spec.html#contm_domainofapplication_qualifier
lt https://w3c.github.io/mathml/spec.html#contm_nary_reln
maction https://w3c.github.io/mathml/spec.html#presm_reqarg_table
maligngroup https://w3c.github.io/mathml/spec.html#presm_malign
malignmark https://w3c.github.io/mathml/spec.html#presm_malign
math https://w3c.github.io/mathml/spec.html#interf_toplevel
matrix https://w3c.github.io/mathml/spec.html#contm_nary_construct_matrix
matrixrow https://w3c.github.io/mathml/spec.html#contm_nary_construct_matrix
max https://w3c.github.io/mathml/spec.html#contm_nary_unary_minmax
mean https://w3c.github.io/mathml/spec.html#contm_nary_unary_stats
median https://w3c.github.io/mathml/spec.html#contm_nary_unary_stats
menclose https://w3c.github.io/mathml/spec.html#presm_menclose
merror https://w3c.github.io/mathml/spec.html#presm_merror
mfenced https://w3c.github.io/mathml/spec.html#presm_mfenced
mfrac https://w3c.github.io/mathml/spec.html#presm_mfrac
mglyph https://w3c.github.io/mathml/spec.html#presm_tokenchars
mi https://w3c.github.io/mathml/spec.html#presm_mi
min https://w3c.github.io/mathml/spec.html#contm_nary_unary_minmax
minus https://w3c.github.io/mathml/spec.html#contm_binary_arith
mlabeledtr https://w3c.github.io/mathml/spec.html#presm_eqno
mlongdiv https://w3c.github.io/mathml/spec.html#presm_reqarg_table
mmultiscripts https://w3c.github.io/mathml/spec.html#presm_mmultiscripts
mn https://w3c.github.io/mathml/spec.html#presm_mn
mo https://w3c.github.io/mathml/spec.html#presm_mo
mode https://w3c.github.io/mathml/spec.html#contm_nary_unary_stats
moment https://w3c.github.io/mathml/spec.html#contm_otherqualifiers
momentabout https://w3c.github.io/mathml/spec.html#contm_otherqualifiers
mover https://w3c.github.io/mathml/spec.html#presm_mover
mpadded https://w3c.github.io/mathml/spec.html#presm_mpadded
mphantom https://w3c.github.io/mathml/spec.html#presm_mphantom
mprescripts https://w3c.github.io/mathml/spec.html#presm_mmultiscripts
mroot https://w3c.github.io/mathml/spec.html#presm_mroot
mrow https://w3c.github.io/mathml/spec.html#presm_mrow
ms https://w3c.github.io/mathml/spec.html#presm_ms
mscarries https://w3c.github.io/mathml/spec.html#presm_mscarries
mscarry https://w3c.github.io/mathml/spec.html#presm_mscarries
msgroup https://w3c.github.io/mathml/spec.html#presm_msgroup
msline https://w3c.github.io/mathml/spec.html#presm_msline
mspace https://w3c.github.io/mathml/spec.html#presm_mspace
msqrt https://w3c.github.io/mathml/spec.html#presm_mroot
msrow https://w3c.github.io/mathml/spec.html#presm_msrow
mstack https://w3c.github.io/mathml/spec.html#presm_mstack
mstyle https://w3c.github.io/mathml/spec.html#presm_mstyle
msub https://w3c.github.io/mathml/spec.html#presm_msub
msubsup https://w3c.github.io/mathml/spec.html#presm_msubsup
msup https://w3c.github.io/mathml/spec.html#presm_msup
mtable https://w3c.github.io/mathml/spec.html#presm_mtable
mtd https://w3c.github.io/mathml/spec.html#presm_mtd
mtext https://w3c.github.io/mathml/spec.html#presm_mtext
mtr https://w3c.github.io/mathml/spec.html#presm_mtr
munder https://w3c.github.io/mathml/spec.html#presm_munder
munderover https://w3c.github.io/mathml/spec.html#presm_munderover
neq https://w3c.github.io/mathml/spec.html#contm_binary_reln
none https://w3c.github.io/mathml/spec.html#presm_mscarries_desc
not https://w3c.github.io/mathml/spec.html#contm_unary_logical
notin https://w3c.github.io/mathml/spec.html#contm_binary_set
notprsubset https://w3c.github.io/mathml/spec.html#contm_binary_set
notsubset https://w3c.github.io/mathml/spec.html#contm_binary_set
or https://w3c.github.io/mathml/spec.html#contm_nary_logical
otherwise https://w3c.github.io/mathml/spec.html#contm_piecewise_sec
outerproduct https://w3c.github.io/mathml/spec.html#contm_binary_linalg
partialdiff https://w3c.github.io/mathml/spec.html#contm_partialdiff_sec
piece https://w3c.github.io/mathml/spec.html#contm_piecewise_sec
piecewise https://w3c.github.io/mathml/spec.html#contm_piecewise_sec
plus https://w3c.github.io/mathml/spec.html#contm_nary_arith
power https://w3c.github.io/mathml/spec.html#contm_binary_arith
product https://w3c.github.io/mathml/spec.html#contm_product_sec
prsubset https://w3c.github.io/mathml/spec.html#contm_nary_set_reln
quotient https://w3c.github.io/mathml/spec.html#contm_binary_arith
real https://w3c.github.io/mathml/spec.html#contm_unary_arith
reln https://w3c.github.io/mathml/spec.html#chg_contm
rem https://w3c.github.io/mathml/spec.html#contm_binary_arith
root https://w3c.github.io/mathml/spec.html#contm_binary_arith
scalarproduct https://w3c.github.io/mathml/spec.html#contm_binary_linalg
sdev https://w3c.github.io/mathml/spec.html#contm_nary_unary_stats
selector https://w3c.github.io/mathml/spec.html#contm_nary_linalg
semantics https://w3c.github.io/mathml/spec.html#mixing_elements_semantics
sep https://w3c.github.io/mathml/spec.html#contm_rendering_numbers
set https://w3c.github.io/mathml/spec.html#contm_nary_construct_set
setdiff https://w3c.github.io/mathml/spec.html#contm_binary_set
share https://w3c.github.io/mathml/spec.html#contm_strict
sin https://w3c.github.io/mathml/spec.html#contm_strict
subset https://w3c.github.io/mathml/spec.html#contm_nary_set_reln
sum https://w3c.github.io/mathml/spec.html#contm_sum_sec
tendsto https://w3c.github.io/mathml/spec.html#contm_binary_reln
times https://w3c.github.io/mathml/spec.html#contm_nary_arith
transpose https://w3c.github.io/mathml/spec.html#contm_unary_linalg
union https://w3c.github.io/mathml/spec.html#contm_nary_set
uplimit https://w3c.github.io/mathml/spec.html#contm_domainofapplication_qualifier
variance https://w3c.github.io/mathml/spec.html#contm_nary_unary_stats
vector https://w3c.github.io/mathml/spec.html#contm_nary_construct_matrix
vectorproduct https://w3c.github.io/mathml/spec.html#contm_binary_linalg
xor https://w3c.github.io/mathml/spec.html#contm_nary_logical
exponentiale https://w3c.github.io/mathml/spec.html#contm_exponentiale
imaginaryi https://w3c.github.io/mathml/spec.html#contm_imaginaryi
notanumber https://w3c.github.io/mathml/spec.html#contm_notanumber
true https://w3c.github.io/mathml/spec.html#contm_true
false https://w3c.github.io/mathml/spec.html#contm_false
pi https://w3c.github.io/mathml/spec.html#contm_pi
eulergamma https://w3c.github.io/mathml/spec.html#contm_eulergamma
infinity https://w3c.github.io/mathml/spec.html#contm_infinity
  );
  # none https://w3c.github.io/mathml/spec.html#chg_presm
  #
  # Array.prototype.slice.call(document.querySelectorAll ("#mml_elements dt")).map(_=>[_,Array.prototype.slice.call (_.nextElementSibling.querySelectorAll ('a'))]).filter (_ => !_[0].textContent.match (/\(/)).map (_ => [_[0], _[1].filter(x => x.textContent.indexOf ('<' + _[0].textContent) > -1)[0] || _[1].filter (x => x.textContent.indexOf (_[0].textContent))[0] || _[1][0] ]).map(_ => _[0].textContent + " " + _[1]).join ("\n")
  for (keys %y) {
    $EDefs->{$_}->{_mathml}->{mathml4} = $y{$_};
    if ($y{$_} =~ /#chg/) {
      $EDefs->{$_}->{_mathml}->{mathml4_legacy} = 1;
      $EDefs->{$_}->{_mathml}->{mathml4_content} = 1;
    }
    if ($y{$_} =~ /#contm/) {
      $EDefs->{$_}->{_mathml}->{mathml4_content} = 1;
    }
    if ($y{$_} =~ /#presm/) {
      $EDefs->{$_}->{_mathml}->{mathml4_presentation} = 1;
    }
  }

  {
    # https://w3c.github.io/mathml-core/
    for (qw(
    annotation
    annotation-xml
    maction
    math
    merror
    mfrac
    mi
    mmultiscripts
    mn
    mo
    mover
    mpadded
    mphantom
    mprescripts
    mroot
    mrow
    ms
    mspace
    msqrt
    mstyle
    msub
    msubsup
    msup
    mtable
    mtd
    mtext
    mtr
    munder
    munderover
    semantics
    )) {
      $EDefs->{$_}->{_mathml}->{core} = "https://w3c.github.io/mathml-core/#dfn-" . $_;
    }
  }
}

print perl2json_bytes_for_record $EDefs;

## License: Public Domain.
