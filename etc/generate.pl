use v5.12;
use utf8;
use File::Copy 'copy';
use ZRTeXtor ':all';
use ZRJCode ':all';
require 'xequery.pl';
my $program = 'generate';
my $tempb = '__ggbr';
my $tempz = 'zzggbr';
use Data::Dump 'dump';

# TeX font family name
my $font_name = 'genbros';
# where 'texucsmapping' repository is checked out
my $tum_dir = "$ENV{ZR_PRIVATE_WORK}/texlabo/texucsmapping";

my @target_enc = qw( OT1 T1 LY1 TS1 );
my @target_jenc = qw( JY1 JY2 );
my $genbros_ttf_file = 'GenEiBrice.otf';

my (@uchar, %um, %ukern, %texenc);

sub main {
  jfm_use_uptex_tool(1);
  load_font_metric();
  read_encoding();
  generate_raw_tfm();
  foreach my $enc (@target_enc) {
    generate_vf($enc);
  }
  generate_raw_jfm();
  foreach my $enc (@target_jenc) {
    generate_jvf($enc);
  }
}

#---------------------------------------

sub info {
  say STDERR (join(": ", $program, ((@_) ? (@_) : textool_error())));
}
sub error {
  info(@_); exit(1);
}

sub kpse {
  my ($f) = @_;
  local $_ = `kpsewhich $f`; chomp($_);
  ($_ ne '') or error("not found", $f);
  return $_;
}

sub FR {
  local ($_) = @_;
  return 'R', sprintf("%.6f", $_);
}
sub FD {
  local ($_) = @_;
  return 'D', int($_);
}
sub FH {
  local ($_) = @_;
  return 'H', sprintf("%X", int($_));
}
sub FUC {
  return map { sprintf("U%04X", $_) } (@_);
}
sub FXC {
  return map { sprintf("X%04X", $_) } (@_);
}

#---------------------------------------

sub load_font_metric {
  local $_ = <<'EOT';
\font\fB="[%%FONT%%]"
\newcount\cUc \newcount\cUcx
\newdimen\dLen \newbox\bPr
\let\do\relax
\let\xUList\empty \let\xUListA\empty
\cUc="21 \loop \ifnum\cUc<"FFFF
  \iffontchar\fB\cUc
    \ifnum\cUc<"3000 \edef\xUList{\xUList\do{\the\cUc}}\fi
    \edef\xUListA{\xUListA\do{\the\cUc}}
  \fi
  \advance\cUc1
\repeat
\def\xDoA#1{\cUc#1\relax
  \immediate\write16{!OUT!width:\the\cUc=\the\fontcharwd\fB\cUc}%
  \immediate\write16{!OUT!height:\the\cUc=\the\fontcharht\fB\cUc}%
  \immediate\write16{!OUT!depth:\the\cUc=\the\fontchardp\fB\cUc}}
\let\do\xDoA \xUListA
\def\xDoB#1{\cUcx#1\relax
  \setbox\bPr\hbox{\fB\char\cUc\char\cUcx}\dLen\wd\bPr
  \setbox\bPr\hbox{\fB\char\cUc\hbox{}\char\cUcx}%
  \advance\dLen-\wd\bPr
  \unless\ifdim\dLen=0pt
    \immediate\write16{!OUT!kern:\the\cUc:\the\cUcx=\the\dLen}%
  \fi}
\def\xDoA#1{\cUc#1\relax
  \begingroup\let\do\xDoB \xUList \endgroup}
\let\do\xDoA \xUList
\bye
EOT
  s/%%FONT%%/$genbros_ttf_file/g;
  info("run XeTeX");
  my $res = xequery($_, { filter => sub {
    local ($_) = @_;
    if (m/pt$/) { s/pt$//; return $_ / 10; }
    return $_;
  }}) or error("xequery failure");
  info("xequery success");
  @uchar = sort { $a <=> $b } (keys %{$res->{width}});
  %um = map {
    my ($k, $v) = ($_, $res->{$_});
    $k => {map { $_ => nonneg(tround($v->{$_})) } (keys %$v)}
  } (qw(width height depth));
  %ukern = map {
    my ($uc, $v) = ($_, $res->{kern}{$_});
    my %h = map {
      my $krn = tround($v->{$_});
      ($krn == 0) ? () : ($_ => $krn)
    } (keys %$v);
    (%h) ? ($uc => \%h) : ()
  } (keys %{$res->{kern}});
}

sub tround {
  local ($_) = @_;
  return int($_ * 1000 + .5) / 1000;
}
sub nonneg {
  local ($_) = @_;
  return ($_ < 0) ? 0 : $_;
}

#---------------------------------------

my %extra_mapping = (
  'LY1' => {
    0x0B => 0x3053, # hiragana ko
    0x0C => 0x3064, # hirakana tu
    0x0E => 0x30B1, # katakana ke
    0x0F => 0x30B3, # katakana ko
  },
  'TS1' => {
    0xF0 => 0x3053, # hiragana ko
    0xF1 => 0x3064, # hirakana tu
    0xF7 => 0x30B1, # katakana ke
    0xF8 => 0x30B3, # katakana ko
  },
);

sub read_encoding {
  local ($_);
  my %ucs = map { $_ => 1 } (@uchar);
  foreach my $enc (@target_enc) {
    info("load encoding", $enc);
    my @vec; $#vec = 255; $texenc{$enc} = \@vec;
    $_ = lc($enc); $_ = "$tum_dir/bx-$_.txt";
    open(my $h, '<', $_) or error("cannot open", $_);
    while (<$h>) {
      s/\#.*//; s/\s+\z//;
      my ($t, $u) = split(m/\t/, $_);
      (exists $ucs{hex($u)}) or next;
      $vec[hex($t)] = hex($u);
    }
    close($h);
    my $ext = $extra_mapping{$enc} or next;
    foreach (keys %$ext) {
      $vec[$_] = $ext->{$_};
    }
  }
}

sub convert_to_tex_kern {
  my ($enc) = @_; local ($_);
  my $vec = $texenc{$enc} or error("bad encoding name", $enc);
  ($enc eq 'TS1') and return ([], []);
  my (@index, @tkern);
  foreach my $tc1 (0 .. 255) {
    (exists $ukern{$vec->[$tc1]}) or next;
    my @tkern1;
    foreach my $tc2 (0 .. 255) {
      $_ = $ukern{$vec->[$tc1]}{$vec->[$tc2]} or next;
      $tkern1[$tc2] = $_;
    }
    $_ = find_same_kern(\@tkern1, \@tkern);
    if (!defined $_) {
      push(@tkern, \@tkern1); $_ = $#tkern;
    }
    $index[$tc1] = $_;
  }
  return (\@index, \@tkern);
}

sub find_same_kern {
  my ($one, $repo) = @_; local ($_);
  L1:foreach (0 .. $#$repo) {
    my $r = $repo->[$_];
    foreach (0 .. 255) {
      (($one->[$_] || 0) == ($r->[$_] || 0)) or next L1;
    }
    return $_;
  }
  return undef;
}

#---------------------------------------

sub base_pl {
  my ($cs) = @_;
  my $space = $um{width}{ord' '} || 0.5;
  return [
    ['FAMILY', uc($font_name)],
    ['CODINGSCHEME', uc($cs)],
    ['FONTDIMEN',
      ['SLANT', FR(0)],
      ['SPACE', FR($space)],
      ['STRETCH', FR($space/2)],
      ['SHRINK', FR($space/3)],
      ['XHEIGHT', FR($um{width}{ord'5'}*0.6)],
      ['QUAD', FR($um{width}{0x3000}||1)],
      ['EXTRASPACE', FR($space/3)],
    ],
  ];
}

sub generate_raw_tfm {
  local $_ = { map { ($_ >> 8) => 1 } (@uchar) };
  foreach my $row (sort { $a <=> $b } (keys %$_)) {
    my $sfx = sprintf("u%02x", $row);
    my $ntfm = "r-$font_name-r-$sfx";
    info("generate raw TFM", $ntfm);
    my $pl = base_pl("unicode-$sfx");
    foreach my $tc (0..255) {
      my $uc = (($row << 8) | $tc);
      (exists $um{width}{$uc}) or next;
      push(@$pl, ['CHARACTER', FD($tc),
        ['CHARWD', FR($um{width}{$uc})],
        ['CHARHT', FR($um{height}{$uc})],
        ['CHARDP', FR($um{depth}{$uc})],
      ]);
    }
    write_whole_file("$ntfm.tfm", x_pltotf($pl), 1) or error();
  }
}

sub generate_vf {
  my ($enc) = @_; local ($_);
  my $vec = $texenc{$enc} or error("bad encoding name", $enc);
  my $ntfm = "$font_name-r-".lc($enc);
  info("generate TFM", $ntfm);
  $_ = { map { (defined $_) ? (($_ >> 8) => 1) : () } (@$vec) };
  my @row = sort { $a <=> $b } (keys %$_);
  my %rrow = map { $row[$_] => $_ } (0 .. $#row);
  #
  my $pl = base_pl("TeX-$enc");
  unshift(@$pl, ['VTITLE', uc($font_name)]);
  foreach (0 .. $#row) {
    push(@$pl, ['MAPFONT', FD($_),
      ['FONTNAME', sprintf("r-%s-r-u%02x", $font_name, $row[$_])]]);
  }
  #
  my ($index, $tkern) = convert_to_tex_kern($enc);
  my $lig = ['LIGTABLE'];
  (@$tkern) and push(@$pl, $lig);
  my @ltc = grep { defined $index->[$_] } (0 .. 255);
  foreach my $i (0 .. $#$tkern) {
    foreach (grep { $index->[$_] == $i } (@ltc)) {
      push(@$lig, ['LABEL', FD($_)]);
    }
    foreach my $tc (0 .. 255) {
      $_ = $tkern->[$i][$tc]; (defined $_) or next;
      push(@$lig, ['KRN', FD($tc), FR($_)]);
    }
    push(@$lig, ['STOP']);
  }
  #
  foreach my $tc (0 .. 255) {
    my $uc = $vec->[$tc] or next;
    my $height = $um{height}{$uc};
    push(@$pl, ['CHARACTER', FD($tc),
      ['CHARWD', FR($um{width}{$uc})],
      ['CHARHT', FR($height)],
      ['CHARDP', FR($um{depth}{$uc})],
      ($height < 0.25) ? () : ['CHARIC', FR($height*0.12)],
      ['MAP',
        ['SELECTFONT', FD($rrow{$uc >> 8})],
        ['SETCHAR', FD($uc & 0xFF)],
      ],
    ]);
  }
  #$_ = pl_form($pl) or error(); print($_); exit;
  my ($vf, $tfm) = x_vptovf($pl) or error();
  write_whole_file("$ntfm.vf", $vf, 1) or error();
  write_whole_file("$ntfm.tfm", $tfm, 1) or error();
}

sub generate_enc {
  my ($enc) = @_; local ($_);
  my $vec = $texenc{$enc} or error("bad encoding name", $enc);
  my $nenc = "$font_name-".lc($enc);
  info("generate enc", $nenc);
  $_ = join("\n", map {
    (defined $_ && exists $um{width}{$_}) ?
      sprintf("  /uni%04X", $_) : "  /.notdef"
  } (@$vec));
  $_ = <<"EOT";
/$nenc-enc [
$_
] def
EOT
  write_whole_file("$nenc.enc", $_, 1) or error();
}

#---------------------------------------

sub base_jpl {
  my ($cs) = @_;
  my $space = $um{width}{ord' '} || 0.5;
  return [
    ['FAMILY', uc($font_name)],
    ['CODINGSCHEME', uc($cs)],
    ['FONTDIMEN',
      ['SLANT', FR(0)],
      ['SPACE', FR(0)],
      ['STRETCH', FR(0.25)],
      ['SHRINK', FR(0)],
      ['XHEIGHT', FR(1)],
      ['QUAD', FR(1)],
    ],
  ];
}

sub generate_raw_jfm {
  local ($_);
  my $ntfm = "r-$font_name-r-jy2";
  my $pl = base_jpl("unicode");
  my ($plc, $csp, $width) = codespace();
  push(@$pl, @$plc);
  foreach my $ty (0 .. $#$width) {
    push(@$pl, ['TYPE', FD($ty),
      ['CHARWD', FR($width->[$ty])],
      ['CHARHT', FR(0.88)],
      ['CHARDP', FR(0.12)],
    ]);
  }
  write_whole_file("$ntfm.tfm", jfm_form($pl), 1) or error();
}

sub generate_jvf {
  my ($enc) = @_; local ($_);
  my $ntfm = "$font_name-r-".lc($enc);
  my $pl = base_jpl("TeX-$enc");
  unshift(@$pl, ['VTITLE', $font_name]);
  my $map = jcode_map($enc);
  my ($plc, $csp, $width) = codespace($map);
  push(@$pl, @$plc, ['MAPFONT', FD(0),
    ['FONTNAME', "r-$font_name-r-jy2"],
  ]);
  foreach my $ty (0 .. $#$width) {
    (defined $width->[$ty]) or next;
    push(@$pl, ['TYPE', FD($ty),
      ['CHARWD', FR($width->[$ty])],
      ['CHARHT', FR(0.88)],
      ['CHARDP', FR(0.12)],
    ]);
  }
  foreach my $tc (@$csp) {
    my $uc = $map->{$tc} or error("what?");
    push(@$pl, ['CHARACTER', FH($tc), ['MAP',
      ['SETCHAR', FH($uc)],
    ]]);
  }
  my ($vf, $tfm) = vf_form_ex($pl) or error();
  write_whole_file("$ntfm.vf", $vf, 1) or error();
  write_whole_file("$ntfm.tfm", $tfm, 1) or error();
}

sub jcode_map {
  my ($enc) = @_; my %map;
  if ($enc eq 'JY1') {
    foreach (0 .. MAX_INTCODE) {
      my ($jc, $uc) = (in_jis($_), in_ucs($_, EJV_PTEX));
      (defined $uc) and $map{$jc} = $uc;
    }
  } elsif ($enc eq 'JY2') {
    %map = map { $_ => $_ } (0x80 .. 0xFFFF);
  }
  return \%map;
}

sub codespace {
  my ($mapi) = @_; local ($_);
  my $uw = $um{width};
  my $spwd = $uw->{0x3000};
  $_ = { reverse %$uw }; delete $_->{$spwd};
  my @width = sort { $a <=> $b } (keys %$_);
  unshift(@width, $spwd);
  my $map = (defined $mapi) ? $mapi :
    { map { $_ => $_ } (@uchar) };

  my @csp = sort { $a <=> $b } (keys %$map);
  @csp = grep { exists $uw->{$map->{$_}} } (@csp);
  my $pl = (defined $mapi) ? [['CODESPACE', FXC(@csp)]] : [];
  foreach my $ty (1 .. $#width) {
    my @cit = grep { $uw->{$map->{$_}} == $width[$ty] } (@csp);
    if (!@cit) {
      $width[$ty] = undef; next; 
    }
    push(@$pl, ['CHARSINTYPE', FD($ty), FXC(@cit)]);
  }
  return ($pl, \@csp, \@width);
}

#---------------------------------------
main();


