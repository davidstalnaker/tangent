#! /usr/bin/perl
#
# $Id: latex2html_for_mathsearch.pl,v 1.3 2007/09/24 20:34:12 byuan Exp $
#
# Comprises patches and revisions by various authors:
#   See Changes, the log file of LaTeX2HTML.
#
# Original Copyright notice:
#
# LaTeX2HTML by Nikos Drakos <nikos@cbl.leeds.ac.uk>

# ****************************************************************
# LaTeX To HTML Translation **************************************
# ****************************************************************
# LaTeX2HTML is a Perl program that translates LaTeX source
# files into HTML (HyperText Markup Language). For each source
# file given as an argument the translator will create a
# directory containing the corresponding HTML files.
#
# The man page for this program is included at the end of this file
# and can be viewed using "perldoc latex2html"
#
# For more information on this program and some examples of its
# capabilities visit 
#
#          http://www.latex2html.org/
#
# or see the accompanying documentation in the docs/  directory
#
# or
#
#    http://www-texdev.ics.mq.edu.au/l2h/docs/manual/
#
# or
#
#    http://www.cbl.leeds.ac.uk/nikos/tex2html/doc/latex2html/
#
# Original code written by Nikos Drakos, July 1993.
#
# Address: Computer Based Learning Unit
#          University of Leeds
#          Leeds,  LS2 9JT
#
# Copyright (c) 1993-95. All rights reserved.
#
#
# Extensively modified by Ross Moore, Herb Swan and others
#
# Address: Mathematics Department
#          Macquarie University
#          Sydney, Australia, 2109 
#
# Copyright (c) 1996-2001. All rights reserved.
#
# See general license in the LICENSE file.
#
##########################################################################

use 5.003; # refuse to work with old and buggy perl version
#use strict;
#use diagnostics;

# include some perl packages; these come with the standard distribution
use Getopt::Long;
use Fcntl;
use AnyDBM_File;
use FileHandle;
use File::Basename;

# The following are global variables that also appear in some modules
use vars qw($LATEX2HTMLDIR $LATEX2HTMLPLATDIR $SCRIPT
            %Month %used_icons $inside_tabbing $TABLE_attribs
            %mathentities $date_name $outer_math $TABLE__CELLPADDING_rx);

BEGIN {
  # print "scanning for l2hdir\n";
  if($ENV{'LATEX2HTMLDIR'}) {
    $LATEX2HTMLDIR = $ENV{'LATEX2HTMLDIR'};
  } else {
    $ENV{'LATEX2HTMLDIR'} = $LATEX2HTMLDIR = '/usr/share/latex2html';
  }

  if($ENV{'LATEX2HTMLPLATDIR'}) {
    $LATEX2HTMLPLATDIR = $ENV{'LATEX2HTMLPLATDIR'};
  } else {
    $LATEX2HTMLPLATDIR = '/usr/share/latex2html'||$LATEX2HTMLDIR;
    $ENV{'LATEX2HTMLPLATDIR'} = $LATEX2HTMLPLATDIR;
  }
  if(-d $LATEX2HTMLPLATDIR) {
    push(@INC,$LATEX2HTMLPLATDIR);
  }

  if(-d $LATEX2HTMLDIR) {
    push(@INC,$LATEX2HTMLDIR);
  } else {
    die qq{Fatal: Directory "$LATEX2HTMLDIR" does not exist.\n};
  }
}

use L2hos; # Operating system dependent routines

# $^W = 1; # turn on warnings

my $RELEASE = '2002-2-1';
my ($REVISION) = q$Revision: 1.3 $ =~ /:\s*(\S+)/;

# The key, which delimts expressions defined in the environment
# depends on the operating system. 
$envkey = L2hos->pathd();

# $dd is the directory delimiter character
$dd = L2hos->dd();

# make sure the $LATEX2HTMLDIR is on the search-path for forked processes
if($ENV{'PERL5LIB'}) {
  $ENV{'PERL5LIB'} .= "$envkey$LATEX2HTMLDIR"
    unless($ENV{'PERL5LIB'} =~ m|\Q$LATEX2HTMLDIR\E|o);
} else {
  $ENV{'PERL5LIB'} = $LATEX2HTMLDIR;
}

# Local configuration, read at runtime
# Read the $CONFIG_FILE  (usually l2hconf.pm )
if($ENV{'L2HCONFIG'}) {
  require $ENV{'L2HCONFIG'} ||
    die "Fatal (require $ENV{'L2HCONFIG'}): $!";
} else {
  eval 'use l2hconf';
  if($@) {
    die "Fatal (use l2hconf): $@\n";
  }
}

# MRO: Changed this to global value in config/config.pl
# change these whenever you do a patch to this program and then
# name the resulting patch file accordingly
# $TVERSION = "2002-2-1";
#$TPATCHLEVEL = " beta";
#$TPATCHLEVEL = " release";
#$RELDATE = "(March 30, 1999)";
#$TEX2HTMLV_SHORT = $TVERSION . $TPATCHLEVEL;

$TEX2HTMLV_SHORT = $RELEASE;
$TEX2HTMLVERSION = "$TEX2HTMLV_SHORT ($REVISION)";
$TEX2HTMLADDRESS = "http://www.latex2html.org/";
$AUTHORADDRESS = "http://cbl.leeds.ac.uk/nikos/personal.html";
#$AUTHORADDRESS2 = "http://www-math.mpce.mq.edu.au/%7Eross/";
$AUTHORADDRESS2 = "http://www.maths.mq.edu.au/&#126;ross/";

# Set $HOME to what the system considers the home directory
$HOME = L2hos->home();
push(@INC,$HOME);

# flush stdout with every print -- gives better feedback during
# long computations
$| = 1;

# set Perl's subscript separator to LaTeX's illegal character.
# (quite defensive but why not)
$; = "\000";

# No arguments!!
unless(@ARGV) {
  die "Error: No files to process!\n";
}

# Image prefix
$IMAGE_PREFIX = '_image';

# Partition prefix 
$PARTITION_PREFIX = 'part_' unless $PARTITION_PREFIX;

# Author address
@address_data = &address_data('ISO');
$ADDRESS = "$address_data[0]\n$address_data[1]";

# ensure non-zero defaults
$MAX_SPLIT_DEPTH = 4 unless ($MAX_SPLIT_DEPTH);
$MAX_LINK_DEPTH = 4 unless ($MAX_LINK_DEPTH);
$TOC_DEPTH = 4 unless ($TOC_DEPTH);

# A global value may already be set in the $CONFIG_FILE
$INIT_FILE_NAME = $ENV{'L2HINIT_NAME'} || '.latex2html-init'
   unless $INIT_FILE_NAME;

# Read the $HOME/$INIT_FILE_NAME if one is found
if (-f "$HOME$dd$INIT_FILE_NAME" && -r _) {
    print "Note: Loading $HOME$dd$INIT_FILE_NAME\n";
    require("$HOME$dd$INIT_FILE_NAME");
    $INIT_FILE = "$HOME$dd$INIT_FILE_NAME";
    # _MRO_TODO_: Introduce a version to be checked?
    die "Error: You have an out-of-date " . $HOME .
	"$dd$INIT_FILE_NAME file.\nPlease update or delete it.\n"
	if ($DESTDIR eq '.');
}

# Read the $INIT_FILE_NAME file if one is found in current directory
if ( L2hos->Cwd() ne $HOME && -f ".$dd$INIT_FILE_NAME" && -r _) {
    print "Note: Loading .$dd$INIT_FILE_NAME\n";
    require(".$dd$INIT_FILE_NAME");
    $INIT_FILE = "$INIT_FILE_NAME";
}
die "Error: '.' is an incorrect setting for DESTDIR.\n" .
    "Please check your $INIT_FILE_NAME file.\n"
    if ($DESTDIR eq '.');

# User home substitutions
$LATEX2HTMLSTYLES =~ s/~([$dd$dd$envkey]|$)/$HOME$1/go;
# the next line fails utterly on non-UNIX systems
$LATEX2HTMLSTYLES =~ s/~([^$dd$dd$envkey]+)/L2hos->home($1)/geo;

#absolutise the paths
$LATEX2HTMLSTYLES = join($envkey,
                        map(L2hos->Make_directory_absolute($_),
                                split(/$envkey/o, $LATEX2HTMLSTYLES)));

#HWS:  That was the last reference to HOME.  Now set HOME to $LATEX2HTMLDIR,
#	to enable dvips to see that version of .dvipsrc!  But only if we
#	have DVIPS_MODE not set - yes - this is a horrible nasty kludge
# MRO: The file has to be updated by configure _MRO_TODO_

if ($PK_GENERATION && ! $DVIPS_MODE) {
    $ENV{HOME} =  $LATEX2HTMLDIR;
    delete $ENV{PRINTER}; # Overrides .dvipsrc
}

# language of the DTD specified in the <DOCTYPE...> tag
$ISO_LANGUAGE = 'EN' unless $ISO_LANGUAGE;

# Save the command line arguments, quote where necessary
$argv = join(' ', map {/[\s#*!\$%]/ ? "'$_'" : $_ } @ARGV);

# Pre-process the command line for backward compatibility
foreach(@ARGV) {
  s/^--?no_/-no/; # replace e.g. no_fork by nofork
  # s/^[+](\d+)$/$1/; # remove + in front of integers
}

# Process command line options
my %opt;
unless(GetOptions(\%opt, # all non-linked options go into %opt
        # option                linkage (optional)
        'help|h',
        'version|V',
        'split=s',
        'link=s',
        'toc_depth=i',          \$TOC_DEPTH,
        'toc_stars!',           \$TOC_STARS,
        'short_extn!',          \$SHORTEXTN,
        'iso_language=s',       \$ISO_LANGUAGE,
        'validate!',            \$HTML_VALIDATE,
        'latex!',
        'djgpp!',               \$DJGPP,
        'fork!',                \$CAN_FORK,
        'external_images!',     \$EXTERNAL_IMAGES,
        'ascii_mode!',          \$ASCII_MODE,
        'lcase_tags!',          \$LOWER_CASE_TAGS,
        'ps_images!',           \$PS_IMAGES,
        'font_size=s',          \$FONT_SIZE,
        'tex_defs!',            \$TEXDEFS,
        'navigation!',
        'top_navigation!',      \$TOP_NAVIGATION,
        'bottom_navigation!',   \$BOTTOM_NAVIGATION,
        'auto_navigation!',     \$AUTO_NAVIGATION,
        'index_in_navigation!', \$INDEX_IN_NAVIGATION,
        'contents_in_navigation!', \$CONTENTS_IN_NAVIGATION,
        'next_page_in_navigation!', \$NEXT_PAGE_IN_NAVIGATION,
        'previous_page_in_navigation!', \$PREVIOUS_PAGE_IN_NAVIGATION,
        'footnode!',
        'numbered_footnotes!',  \$NUMBERED_FOOTNOTES,
        'prefix=s',             \$PREFIX,
        'auto_prefix!',         \$AUTO_PREFIX,
        'long_titles=i',        \$LONG_TITLES,
        'custom_titles!',       \$CUSTOM_TITLES,
        'title|t=s',            \$TITLE,
        'rooted!',              \$ROOTED,
        'rootdir=s',
        'dir=s',                \$FIXEDDIR,
        'mkdir',                \$MKDIR,
        'address=s',            \$ADDRESS,
        'noaddress',
        'subdir!',
        'info=s',               \$INFO,
        'noinfo',
        'auto_link!',
        'reuse=i',              \$REUSE,
        'noreuse',
        'antialias_text!',      \$ANTI_ALIAS_TEXT,
        'antialias!',           \$ANTI_ALIAS,
        'transparent!',         \$TRANSPARENT_FIGURES,
        'white!',               \$WHITE_BACKGROUND,
        'discard!',             \$DISCARD_PS,
        'image_type=s',         \$IMAGE_TYPE,
        'images!',
        'accent_images=s',      \$ACCENT_IMAGES,
        'noaccent_images',
        'style=s',              \$STYLESHEET,
        'parbox_images!',
        'math!',
        'math_parsing!',
        'latin!',
        'entities!',            \$USE_ENTITY_NAMES,
        'local_icons!',         \$LOCAL_ICONS,
        'scalable_fonts!',      \$SCALABLE_FONTS,
        'images_only!',         \$IMAGES_ONLY,
        'show_section_numbers!',\$SHOW_SECTION_NUMBERS,
        'show_init!',           \$SHOW_INIT_FILE,
        'init_file=s',          \$INIT_FILE,
        'up_url=s',             \$EXTERNAL_UP_LINK,
        'up_title=s',           \$EXTERNAL_UP_TITLE,
        'down_url=s',           \$EXTERNAL_DOWN_LINK,
        'down_title=s',         \$EXTERNAL_DOWN_TITLE,
        'prev_url=s',           \$EXTERNAL_PREV_LINK,
        'prev_title=s',         \$EXTERNAL_PREV_TITLE,
        'index=s',              \$EXTERNAL_INDEX,
        'biblio=s',             \$EXTERNAL_BIBLIO,
        'contents=s',           \$EXTERNAL_CONTENTS,
        'external_file=s',      \$EXTERNAL_FILE,
        'short_index!',         \$SHORT_INDEX,
        'unsegment!',           \$UNSEGMENT,
        'debug!',               \$DEBUG,
        'tmp=s',                \$TMP,
        'ldump!',               \$LATEX_DUMP,
        'timing!',              \$TIMING,
        'verbosity=i',          \$VERBOSITY,
        'html_version=s',       \$HTML_VERSION,
        'strict!',              \$STRICT_HTML,
        'xbit!',                \$XBIT_HACK,
        'ssi!',                 \$ALLOW_SSI,
        'php!',                 \$ALLOW_PHP,
        'test_mode!' # undocumented switch
       )) {
    &usage();
    exit 1;
}

# interpret options, check option consistency
if(defined $opt{'split'}) {
    if ($opt{'split'} =~ /^(\+?)(\d+)$/) {
        $MAX_SPLIT_DEPTH = $2;
        if ($1) { $MAX_SPLIT_DEPTH *= -1; $REL_DEPTH = 1; }
    } else { 
        &usage;
        die "Error: Unrecognised value for -split: $opt{'split'}\n";
    }
}
if(defined $opt{'link'}) {
    if ($opt{'link'} =~ /^(\+?)(\d+)$/) {
        $MAX_LINK_DEPTH = $2;
        if ($1) { $MAX_LINK_DEPTH *= -1 }
    } else { 
        &usage;
        die "Error: Unrecognised value for -link: $opt{'link'}\n";
    }
}
unless ($ISO_LANGUAGE =~ /^[A-Z.]+$/) {
    die "Error: Language (-iso_language) must be uppercase and dots only: $ISO_LANGUAGE\n";
}
if ($HTML_VALIDATE && !$HTML_VALIDATOR) {
    die "Error: Need a HTML_VALIDATOR when -validate is specified.\n";
}
&set_if_false($NOLATEX,$opt{latex}); # negate the option...
if ($ASCII_MODE || $PS_IMAGES) {
    $EXTERNAL_IMAGES = 1;
}
if ($FONT_SIZE && $FONT_SIZE !~ /^\d+pt$/) {
    die "Error: Font size (-font_size) must end with 'pt': $FONT_SIZE\n"
}
&set_if_false($NO_NAVIGATION,$opt{navigation});
&set_if_false($NO_FOOTNODE,$opt{footnode});
if (defined $TITLE && !length($TITLE)) {
    die "Error: Empty title (-title).\n";
}
if ($opt{rootdir}) {
    $ROOTED = 1;
    $FIXEDDIR = $opt{rootdir};
}
if ($FIXEDDIR && !-d $FIXEDDIR) {
    if ($MKDIR) {
	print "\n *** creating directory: $FIXEDDIR ";
	die "Failed: $!\n" unless (mkdir($FIXEDDIR, 0755));
        # _TODO_ use File::Path to create a series of directories
    } else {
	&usage;
	die "Error: Specified directory (-rootdir, -dir) does not exist.\n";
    }
}
&set_if_false($NO_SUBDIR, $opt{subdir});
&set_if_false($NO_AUTO_LINK, $opt{auto_link});
if ($opt{noreuse}) {
    $REUSE = 0;
}
unless(grep(/^\Q$IMAGE_TYPE\E$/o, @IMAGE_TYPES)) {
    die <<"EOF";
Error: No such image type '$IMAGE_TYPE'.
       This installation supports (first is default): @IMAGE_TYPES
EOF
}
&set_if_false($NO_IMAGES, $opt{images});
if ($opt{noaccent_images}) {
    $ACCENT_IMAGES = '';
}
if($opt{noaddress}) {
    $ADDRESS = '';
}
if($opt{noinfo}) {
    $INFO = 0;
}
if($ACCENT_IMAGES && $ACCENT_IMAGES !~ /^[a-zA-Z,]+$/) {
    die "Error: Single word or comma-list of style words needed for -accent_images, not: $_\n";
}
&set_if_false($NO_PARBOX_IMAGES, $opt{parbox_images});
&set_if_false($NO_SIMPLE_MATH, $opt{math});
if (defined $opt{math_parsing}) {
    $NO_MATH_PARSING = !$opt{math_parsing};
    $NO_SIMPLE_MATH = !$opt{math_parsing} unless(defined $opt{math});
}
&set_if_false($NO_ISOLATIN, $opt{latin});
if ($INIT_FILE) {
    if (-f $INIT_FILE && -r _) {
        print "Note: Initialising with file: $INIT_FILE\n"
            if ($DEBUG || $VERBOSITY);
        require($INIT_FILE);
    } else {
        die "Error: Could not find file (-init_file): $INIT_FILE\n";
    }
}
foreach($EXTERNAL_UP_LINK, $EXTERNAL_DOWN_LINK, $EXTERNAL_PREV_LINK,
        $EXTERNAL_INDEX, $EXTERNAL_BIBLIO, $EXTERNAL_CONTENTS) {
    $_ ||= ''; # initialize
    s/~/&#126;/g; # protect `~'
}
if($TMP && !(-d $TMP && -w _)) {
    die "Error: '$TMP' not usable as temporary directory.\n";
}
if ($opt{help}) {
    L2hos->perldoc($SCRIPT);
    exit 0;
}
if ($opt{version}) {
    &banner();
    exit 0;
}
if ($opt{test_mode}) {
    $TITLE = 'LaTeX2HTML Test Document';
    $TEXEXPAND = "$PERL /usr/bin/texexpand";
    $PSTOIMG   = "$PERL /usr/bin/pstoimg";
    $ICONSERVER = L2hos->path2URL("${LATEX2HTMLDIR}/icons");
    $TEST_MODE  = 1;
    $RGBCOLORFILE = "${LATEX2HTMLDIR}/styles/rgb.txt";
    $CRAYOLAFILE = "${LATEX2HTMLDIR}/styles/crayola.txt";
}
if($DEBUG) {
    # make the OS-dependent functions more chatty, too
    $L2hos::Verbose = 1;
}

undef %opt; # not needed any more


$FIXEDDIR = $FIXEDDIR || $DESTDIR || '';  # for backward compatibility

if ($EXTERNAL_UP_TITLE xor $EXTERNAL_UP_LINK) {
    warn "Warning (-up_url, -up_title): Need to specify both a parent URL and a parent title!\n";
    $EXTERNAL_UP_TITLE = $EXTERNAL_UP_LINK = "";
}

if ($EXTERNAL_DOWN_TITLE xor $EXTERNAL_DOWN_LINK) {
    warn "Warning (-down_url, -down_title): Need to specify both a parent URL and a parent title!\n";
    $EXTERNAL_DOWN_TITLE = $EXTERNAL_DOWN_LINK = "";
}

# $NO_NAVIGATION = 1 unless $MAX_SPLIT_DEPTH;	#  Martin Wilck

if ($MAX_SPLIT_DEPTH && $MAX_SPLIT_DEPTH < 0) {
    $MAX_SPLIT_DEPTH *= -1; $REL_DEPTH = 1;
}
if ($MAX_LINK_DEPTH && $MAX_LINK_DEPTH < 0) {
    $MAX_LINK_DEPTH *= -1; $LEAF_LINKS = 1;
}

$FOOT_FILENAME = 'footnode' unless ($FOOT_FILENAME);
$NO_FOOTNODE = 1 unless ($MAX_SPLIT_DEPTH || $NO_FOOTNODE);
$NO_SPLIT = 1 unless $MAX_SPLIT_DEPTH; # _MRO_TODO_: is this needed at all?
$SEGMENT = $SEGMENTED = 0;
$NO_MATH_MARKUP = 1;

# specify the filename extension to use with the generated HTML files
if ($SHORTEXTN) { $EXTN = ".htm"; }	# for HTML files on CDROM
elsif ($ALLOW_PHP) { $EXTN = ".php"; }  # has PHP dynamic includes
	# with server-side includes (SSI) :
elsif ($ALLOW_SSI && !$XBIT_HACK) { $EXTN = ".shtml"; }
	# ordinary names, valid also for SSI with XBit hack :
else { $EXTN = ".html"; }

$NODE_NAME = 'node' unless (defined $NODE_NAME);

# space for temporary files
# different to the $TMPDIR for image-generation
# MRO: No directory should end with $dd!
$TMP_ = "TMP";

$TMP_PREFIX = "l2h" unless ($TMP_PREFIX);

# This can be set to 1 when using a version of dvips that is safe
# from the "dot-in-name" bug.
# _TODO_ this should be determined by configure
#$DVIPS_SAFE = 1;

$CHARSET = $charset || 'iso-8859-1';

####################################################################
#
# If possible, use icons of the same type as generated images
#
if ($IMAGE_TYPE && defined %{"icons_$IMAGE_TYPE"}) {
    %icons = %{"icons_$IMAGE_TYPE"};
}

####################################################################
#
# Figure out what options we need to pass to DVIPS and store that in
# the $DVIPSOPT variable.  Also, scaling is taken care of at the
# dvips level if PK_GENERATION is set to 1, so adjust SCALE_FACTORs
# accordingly.
#
if ($SCALABLE_FONTS) {
    $PK_GENERATION = 0;
    $DVIPS_MODE = '';
}

if ($PK_GENERATION) {
    if ($MATH_SCALE_FACTOR <= 0) { $MATH_SCALE_FACTOR = 2; }
    if ($FIGURE_SCALE_FACTOR <= 0) { $FIGURE_SCALE_FACTOR = 2; }
    my $saveMSF = $MATH_SCALE_FACTOR;
    my $saveFSF = $FIGURE_SCALE_FACTOR;
    my $desired_dpi = int($MATH_SCALE_FACTOR*75);
    $FIGURE_SCALE_FACTOR = ($METAFONT_DPI / 72) *
	($FIGURE_SCALE_FACTOR / $MATH_SCALE_FACTOR) ;
    $MATH_SCALE_FACTOR = $METAFONT_DPI / 72;
    $dvi_mag = int(1000 * $desired_dpi / $METAFONT_DPI);
    if ($dvi_mag > 1000) {
	&write_warnings(
	    "WARNING: Your SCALE FACTOR is too large for PK_GENERATION.\n" .
	    "         See $CONFIG_FILE for more information.\n");
    }

    # RRM: over-sized scaling, using dvi-magnification
    if ($EXTRA_IMAGE_SCALE) {
	print "\n *** Images at $EXTRA_IMAGE_SCALE times resolution of displayed size ***\n";
	$desired_dpi = int($EXTRA_IMAGE_SCALE * $desired_dpi+.5);
	print "    desired_dpi = $desired_dpi  METAFONT_DPI = $METAFONT_DPI\n"
            if $DEBUG;
	$dvi_mag = int(1000 * $desired_dpi / $METAFONT_DPI);
	$MATH_SCALE_FACTOR = $saveMSF;
	$FIGURE_SCALE_FACTOR = $saveFSF;
    }
    # no space after "-y", "-D", "-e" --- required by DVIPS under DOS !
    my $mode_switch = "-mode $DVIPS_MODE" if $DVIPS_MODE;
    $DVIPSOPT .= " -y$dvi_mag -D$METAFONT_DPI $mode_switch -e5 ";
} else { # no PK_GENERATION
#    if ($EXTRA_IMAGE_SCALE) {
#	&write_warnings(
#	   "the \$EXTRA_IMAGE_SCALE feature requires either \$PK_GENERATION=1"
#			. " or the '-scalable_fonts' option");
#	$EXTRA_IMAGE_SCALE = '';
#    }
    # MRO: shifted to l2hconf
    #$DVIPSOPT .= ' -M';
} # end PK_GENERATION

# The mapping from numbers to accents.
# These are required to process the \accent command, which is found in
# tables of contents whenever there is an accented character in a
# caption or section title.  Processing the \accent command makes
# $encoded_*_number work properly (see &extract_captions) with
# captions that contain accented characters.
# I got the numbers from the plain.tex file, version 3.141.

# Missing entries should be looked up by a native speaker.
# Have a look at generate_accent_commands and $iso_8859_1_character_map.

# MEH: added more accent types
# MRO: only uppercase needed!
%accent_type = (
   '18' => 'grave',		# \`
   '19' => 'acute',		# `'
   '20' => 'caron',		# \v
   '21' => 'breve',		# \u
   '22' => 'macr',		# \=
   '23' => 'ring',		#
   '24' => 'cedil',		# \c
   '94' => 'circ',		# \^
   '95' => 'dot',		# \.
   '7D' => 'dblac',		# \H
   '7E' => 'tilde',		# \~
   '7F' => 'uml',		# \"
);

&driver;

exit 0; # clean exit, no errors

############################ Subroutines ##################################

#check that $TMP is writable, if so create a subdirectory
sub make_tmp_dir {
    &close_dbm_database if $DJGPP; # to save file-handles

    # determine a suitable temporary path
    #
    $TMPDIR = '';
    my @tmp_try = ();
    push(@tmp_try, $TMP) if($TMP);
    push(@tmp_try, "$DESTDIR$dd$TMP_") if($TMP_);
    push(@tmp_try, $DESTDIR) if($DESTDIR);
    push(@tmp_try, L2hos->Cwd());

    my $try;
    TempTry: foreach $try (@tmp_try) {
      next unless(-d $try && -w _);
      my $tmp = "$try$dd$TMP_PREFIX$$";
      if(mkdir($tmp,0755)) {
        $TMPDIR=$tmp;
	last TempTry;
      } else {
        warn "Warning: Cannot create temporary directory '$tmp': $!\n";
      }
    }

    $dvips_warning = <<"EOF";

Warning: There is a '.' in \$TMPDIR, $DVIPS will probably fail.
Set \$TMP to use a /tmp directory, or rename the working directory.
EOF
    die ($dvips_warning . "\n\$TMPDIR=$TMPDIR  ***\n\n")
	if ($TMPDIR =~ /\./ && $DVIPS =~ /dvips/ && !$DVIPS_SAFE);

    &open_dbm_database if $DJGPP;
}

# MRO: set first parameter to the opposite of the second if second parameter is defined
sub set_if_false {
    $_[0] = !$_[1] if(defined $_[1]);
}

sub check_for_dots {
    local($file) = @_;
    if ($file =~ /\.[^.]*\./) {
	die "\n\n\n *** Fatal Error --- but easy to fix ***\n"
	    . "\nCannot have '.' in file-name prefix, else dvips fails on images"
	    . "\nChange the name from  $file  and try again.\n\n";
    }
}

# Process each file ...
sub driver {
    local($FILE, $orig_cwd, %unknown_commands, %dependent, %depends_on
	  , %styleID, %env_style, $bbl_cnt, $dbg, %numbered_section);
    # MRO: $texfilepath has to be global!
    local(%styles_loaded);
    $orig_cwd = L2hos->Cwd();

    print "\n *** initialise *** " if ($VERBOSITY > 1);
    &initialise;		# Initialise some global variables

    print "\n *** check modes *** " if ($VERBOSITY > 1);
    &ascii_mode if $ASCII_MODE;	# Must come after initialization
    &titles_language($TITLES_LANGUAGE);
    &make_numbered_footnotes if ($NUMBERED_FOOTNOTES);
    $dbg = $DEBUG ? "-debug" : "";
    $dbg .= (($VERBOSITY>2) ? " -verbose" : "");

    #use the same hashes for all files in a batch
    local(%cached_env_img, %id_map, %symbolic_labels, %latex_labels)
	if ($FIXEDDIR && $NO_SUBDIR);

    local($MULTIPLE_FILES,$THIS_FILE);
    $MULTIPLE_FILES = 1+$#ARGV if $ROOTED;
    print "\n *** $MULTIPLE_FILES file".($MULTIPLE_FILES ? 's: ' : ': ')
    	. join(',',@ARGV) . " *** " if ($VERBOSITY > 1);

    local(%section_info, %toc_section_info, %cite_info, %ref_files);
    
    foreach $FILE (@ARGV) {
	&check_for_dots($FILE) unless $DVIPS_SAFE;
	++$THIS_FILE if $MULTIPLE_FILES;
	do {
	    %section_info = ();
	    %toc_section_info = ();
	    %cite_info = ();
	    %ref_files = ();
	} unless $MULTIPLE_FILES;
	local($bbl_nr) = 1;

	# The number of reused images and those in images.tex
	local($global_page_num) = (0) unless($FIXEDDIR && $NO_SUBDIR);
	# The number of images in images.tex
	local($new_page_num) = (0); # unless($FIXEDDIR && $NO_SUBDIR);
	local($pid, $sections_rx,
	    , $outermost_level, %latex_body, $latex_body
	    , %encoded_section_number
	    , %verbatim, %new_command, %new_environment
	    , %provide_command, %renew_command, %new_theorem
	    , $preamble, $aux_preamble, $prelatex, @preamble);

	# must retain these when all files are in the same directory
	# else the images.pl and labels.pl files get clobbered
	unless ($FIXEDDIR && $NO_SUBDIR) {
	    print "\nResetting image-cache" if ($#ARGV);
	    local(%cached_env_img, %id_map, %symbolic_labels, %latex_labels)
	}

## AYS: Allow extension other than .tex and make it optional
	($EXT = $FILE) =~ s/.*\.([^\.]*)$/$1/;
	if ( $EXT eq $FILE ) {
	    $EXT = "tex";
	    $FILE =~ s/$/.tex/;
	}

	#RRM: allow user-customisation, dependent on file-name
	# e.g. add directories to $TEXINPUTS named for the file
	# --- idea due to Fred Drake <fdrake@acm.org>
	&custom_driver_hook($FILE) if (defined &custom_driver_hook);

# JCL(jcl-dir)
# We need absolute paths for TEXINPUTS here, because
# we change the directory
	if ($orig_cwd eq $texfilepath) {
	    &deal_with_texinputs($orig_cwd);
	} else {
	    &deal_with_texinputs($orig_cwd, $texfilepath);
	}

	($texfilepath, $FILE) = &get_full_path($FILE);
	$texfilepath = '.' unless($texfilepath);

	die "Cannot read $texfilepath$dd$FILE \n"
	    unless (-f "$texfilepath$dd$FILE");


# Tell texexpand which files we *don't* want to look at.
	$ENV{'TEXE_DONT_INCLUDE'} = $DONT_INCLUDE if $DONT_INCLUDE;
# Tell texexpand which files we *do* want to look at, e.g.
# home-brew style files
	$ENV{'TEXE_DO_INCLUDE'} = $DO_INCLUDE if $DO_INCLUDE;

	$FILE =~ s/\.[^\.]*$//; ## AYS
	$DESTDIR = ''; # start at empty
	if ($FIXEDDIR) {
	    $DESTDIR = $FIXEDDIR unless ($FIXEDDIR eq '.');
	    if (($ROOTED)&&!($texfilepath eq $orig_cwd)) {
		$DESTDIR .= $dd . $FILE unless $NO_SUBDIR;
	    };
	} elsif ($texfilepath eq $orig_cwd) {
	    $DESTDIR = ($NO_SUBDIR ? '.' : $FILE);
	} else {
	    $DESTDIR = $ROOTED ? '.' : $texfilepath;
	    $DESTDIR .= $dd . $FILE unless $NO_SUBDIR;
	}
	$PREFIX  = "$FILE-" if $AUTO_PREFIX;

	print "\nOPENING $texfilepath$dd$FILE.$EXT \n"; ## AYS

	next unless (&new_dir($DESTDIR,''));
        # establish absolute path to $DESTDIR
	$DESTDIR = L2hos->Make_directory_absolute($DESTDIR);
        &make_tmp_dir;
        print "\nNote: Working directory is $DESTDIR\n";
        print "Note: Images will be generated in $TMPDIR\n\n";

# Need to clean up a bit in case there's garbage left
# from former runs.
	if ($DESTDIR) { chdir($DESTDIR) || die "$!\n"; }
	if (opendir (TMP,$TMP_)) {
	    foreach (readdir TMP) {
		L2hos->Unlink("TMP_$dd$_") unless (/^\.\.?$/);
	    }
	    closedir TMP; 
	}
	&cleanup(1);
	unless(-d $TMP_) {
	    mkdir($TMP_, 0755) ||
	      die "Cannot create directory '$TMP_': $!\n";
	}
	chdir($orig_cwd);

# RRM 14/5/98  moved this to occur earlier
## JCL(jcl-dir)
## We need absolute paths for TEXINPUTS here, because
## we change the directory
#	if ($orig_cwd eq $texfilepath) {
#	    &deal_with_texinputs($orig_cwd);
#	} else {
#	    &deal_with_texinputs($orig_cwd, $texfilepath);
#	}


# This needs $DESTDIR to have been created ...
	print " *** calling  `texexpand' ***" if ($VERBOSITY > 1);
	local($unseg) = ($UNSEGMENT ? "-unsegment " : "");

# does DOS need to check these here ?
#	die "File $TEXEXPAND does not exist or is not executable\n"
#	    unless (-x $TEXEXPAND);
	L2hos->syswait("$TEXEXPAND $dbg -auto_exclude $unseg"
		 . "-save_styles $DESTDIR$dd$TMP_${dd}styles "
		 . ($TEXINPUTS ? "-texinputs $TEXINPUTS " : '' )
		 . (($VERBOSITY >2) ? "-verbose " : '' )
		 . "-out $DESTDIR$dd$TMP_$dd$FILE "
		 . "$texfilepath$dd$FILE.$EXT")
	    && die " texexpand  failed: $!\n";
	print STDOUT "\n ***  `texexpand' done ***\n" if ($VERBOSITY > 1);

	chdir($DESTDIR) if $DESTDIR;
	$SIG{'INT'} = 'handler';

	&open_dbm_database;
	&initialise_sections;
	print STDOUT "\n ***  database open ***\n" if ($VERBOSITY > 1);

	if ($IMAGES_ONLY) {
	    &make_off_line_images;
	} else {
	    &rename_image_files;
	    &load_style_file_translations;
	    &make_language_rx;
	    &make_raw_arg_cmd_rx;
#	    &make_isolatin1_rx unless ($NO_ISOLATIN);
	    &translate_titles;
	    &make_sections_rx;
	    print "\nReading ...";
	    if ($SHORT_FILENAME) {
		L2hos->Rename ("$TMP_$dd$FILE" ,"$TMP_$dd$SHORT_FILENAME" );
		&slurp_input_and_partition_and_pre_process(
		      "$TMP_$dd$SHORT_FILENAME");
	    } else {
		&slurp_input_and_partition_and_pre_process("$TMP_$dd$FILE");
	    }
	    &add_preamble_head;
	    # Create a regular expressions
	    &set_depth_levels;
	    &make_sections_rx;
	    &make_order_sensitive_rx;
	    &add_document_info_page if ($INFO && !(/\\htmlinfo/));
	    &add_bbl_and_idx_dummy_commands;
	    &translate;	# Destructive!
	}
	&style_sheet;
	&close_dbm_database;
	&cleanup();

#JCL: read warnings from file to $warnings
	local($warnings) = &get_warnings;
	print "\n\n*********** WARNINGS ***********  \n$warnings"
	    if ($warnings || $NO_IMAGES || $IMAGES_ONLY);
	&image_cache_message if ($NO_IMAGES || $IMAGES_ONLY);
	&image_message if ($warnings =~ /Failed to convert/io);
	undef $warnings;

# JCL - generate directory index entry.
# Yet, a hard link, cause Perl lacks symlink() on some systems.
	do {
	    local($EXTN) = $EXTN;
	    $EXTN =~ s/_\w+(\.html?)/$1/ if ($frame_main_name);
	    local($from,$to) = (eval($LINKPOINT),eval($LINKNAME));
	    if (length($from) && length($to) && ($from ne $to)) {
		#frames may have altered $EXTN
		$from =~ s/$frame_main_name(\.html?)/$1/ if ($frame_main_name);
		$to =~ s/$frame_main_name(\.html?)/$1/ if ($frame_main_name);
		L2hos->Unlink($to);
		L2hos->Link($from,$to);
	    }
	} unless ($NO_AUTO_LINK || !($LINKPOINT) || !($LINKNAME));

	&html_validate if ($HTML_VALIDATE && $HTML_VALIDATOR);

# Go back to the source directory
	chdir($orig_cwd);
        $TEST_MODE = $DESTDIR if($TEST_MODE); # save path
	$DESTDIR = '';
	$OUT_NODE = 0 unless $FIXEDDIR;
	$STYLESHEET = '' if ($STYLESHEET =~ /^\Q$FILE./);
    }
    print "\nUnknown commands: ". join(" ",keys %unknown_commands)
	if %unknown_commands;
###MEH -- math support
    print "\nMath commands outside math: " .
	join(" ",keys %commands_outside_math) .
	    "\n  Output may look weird or may be faulty!\n"
		if %commands_outside_math;
    print "\nDone.\n";
    if($TEST_MODE) {
      $TEST_MODE =~ s:[$dd$dd]+$::;
      print "\nTo view the results, point your browser at:\n",
        L2hos->path2URL(L2hos->Make_directory_absolute($TEST_MODE).$dd.
        "index$EXTN"),"\n";
    }
    $end_time = time; 
    $total_time = $end_time - $start_time;
    print STDOUT join(' ',"Timing:",$total_time,"seconds\n")
	if ($TIMING||$DEBUG||($VERBOSITY > 2));
    $_;
}

sub open_dbm_database {
    # These are DBM (unix DataBase Management) arrays which are actually
    # stored in external files. They are used for communication between
    # the main process and forked child processes;
    print STDOUT "\n"; # this mysteriously prevents a core dump !

    dbmopen(%verb, "$TMP_${dd}verb",0755);
#    dbmopen(%verbatim, "$TMP_${dd}verbatim",0755);
    dbmopen(%verb_delim, "$TMP_${dd}verb_delim",0755);
    dbmopen(%expanded,"$TMP_${dd}expanded",0755);
# Holds max_id, verb_counter, verbatim_counter, eqn_number
    dbmopen(%global, "$TMP_${dd}global",0755);
# Hold style sheet information
    dbmopen(%env_style, "$TMP_${dd}envstyles",0755);
    dbmopen(%txt_style, "$TMP_${dd}txtstyles",0755);
    dbmopen(%styleID, "$TMP_${dd}styleIDs",0755);

# These next two are used during off-line image conversion
# %new_id_map maps image id's to page_numbers of the images in images.tex
# %image_params maps image_ids to conversion parameters for that image
    dbmopen(%new_id_map, "$TMP_${dd}ID_MAP",0755);
    dbmopen(%img_params, "$TMP_${dd}IMG_PARAMS",0755);
    dbmopen(%orig_name_map, "$TMP_${dd}ORIG_MAP",0755);

    $global{'max_id'} = ($global{'max_id'} | 0);
    &read_mydb(\%verbatim, "verbatim");
    $global{'verb_counter'} = ($global{'verb_counter'} | 0);
    $global{'verbatim_counter'} = ($global{'verbatim_counter'} | 0);

    &read_mydb(\%new_command, "new_command");
    &read_mydb(\%renew_command, "renew_command");
    &read_mydb(\%provide_command, "provide_command");
    &read_mydb(\%new_theorem, "new_theorem");
    &read_mydb(\%new_environment, "new_environment");
    &read_mydb(\%dependent, "dependent");
#    &read_mydb(\%env_style, "env_style");
#    &read_mydb(\%styleID, "styleID");
    # MRO: Why should we use read_mydb instead of catfile?
    $preamble = &catfile(&_dbname("preamble"),1) || '';
    $prelatex = &catfile(&_dbname("prelatex"),1) || '';
    $aux_preamble = &catfile(&_dbname("aux_preamble"),1) || '';
    &restore_critical_variables;
}

sub close_dbm_database {
    &save_critical_variables;
    dbmclose(%verb); undef %verb;
#    dbmclose(%verbatim); undef %verbatim;
    dbmclose(%verb_delim); undef %verb_delim;
    dbmclose(%expanded); undef %expanded;
    dbmclose(%global); undef %global;
    dbmclose(%env_style); undef %env_style;
    dbmclose(%style_id); undef %style_id;
    dbmclose(%new_id_map); undef %new_id_map;
    dbmclose(%img_params); undef %img_params;
    dbmclose(%orig_name_map); undef %orig_name_map;
    dbmclose(%txt_style); undef %txt_style;
    dbmclose(%styleID); undef %styleID;
}

sub clear_images_dbm_database {
    # <Added calls to dbmclose dprhws>
    # %new_id_map will be used by the off-line image conversion process
    #
    dbmclose(%new_id_map);
    dbmclose(%img_params);
    dbmclose(%orig_name_map);
    undef %new_id_map;
    undef %img_params;
    undef %orig_name_map;
    dbmopen(%new_id_map, "$TMP_${dd}ID_MAP",0755);
    dbmopen(%img_params, "$TMP_${dd}IMG_PARAMS",0755);
    dbmopen(%orig_name_map, "$TMP_${dd}ORIG_MAP",0755);
}

sub initialise_sections {
    local($key);
    foreach $key (keys %numbered_section) {
	$global{$key} = $numbered_section{$key}}
}

sub save_critical_variables {
    $global{'math_markup'} = $NO_MATH_MARKUP;
    $global{'charset'} = $CHARSET;
    $global{'charenc'} = $charset;
    $global{'language'} = $default_language;
    $global{'isolatin'} = $ISOLATIN_CHARS;
    $global{'unicode'} = $UNICODE_CHARS;
    if ($UNFINISHED_ENV) {
	$global{'unfinished_env'} = $UNFINISHED_ENV;
	$global{'replace_end_env'} = $REPLACE_END_ENV;
    }
    $global{'unfinished_comment'} = $UNFINISHED_COMMENT;
    if (@UNMATCHED_OPENING) {
	$global{'unmatched'} = join(',',@UNMATCHED_OPENING);
    }
}

sub restore_critical_variables {
    $NO_MATH_MARKUP = ($global{'math_markup'}|
	(defined $NO_MATH_MARKUP ? $NO_MATH_MARKUP:1));
    $CHARSET = ($global{'charset'}| $CHARSET);
    $charset = ($global{'charenc'}| $charset);
    $default_language = ($global{'language'}|
	(defined $default_language ? $default_language:'english'));
    $ISOLATIN_CHARS = ($global{'isolatin'}|
	(defined $ISOLATIN_CHARS ? $ISOLATIN_CHARS:0));
    $UNICODE_CHARS = ($global{'unicode'}|
	(defined $UNICODE_CHARS ? $UNICODE_CHARS:0));
    if ($global{'unfinished_env'}) {
	$UNFINISHED_ENV = $global{'unfinished_env'};
	$REPLACE_END_ENV = $global{'replace_end_env'};
    }
    $UNFINISHED_COMMENT = $global{'unfinished_comment'};
    if ($global{'unmatched'}) {
	@UNMATCHED_OPENING = split(',',$global{'unmatched'});
    }

    # undef any renewed-commands...
    # so the new defs are read from %new_command
    local($cmd,$key,$code);
    foreach $key (keys %renew_command) {
	$cmd = "do_cmd_$key";
	$code = "undef \&$cmd"; eval($code) if (defined &$cmd);
	if ($@) { print "\nundef \&do_cmd_$cmd failed"}
    }
}

#JCL: The warnings should have been handled within the DBM database.
# Unfortunately if the contents of an array are more than ~900 (system
# dependent) chars long then dbm cannot handle it and gives error messages.
sub write_warnings { #clean
    my ($str) = @_;
    $str .= "\n" unless($str =~ /\n$/);
    print STDOUT "\n *** Warning: $str" if ($VERBOSITY > 1);
    my $warnings = '';
    if(-f 'WARNINGS') {
        $warnings = &catfile('WARNINGS') || '';
    }
    return () if ($warnings =~ /\Q$str\E/);
    if(open(OUT,">>WARNINGS")) {
        print OUT $str;
        close OUT;
    } else {
        print "\nError: Cannot append to 'WARNINGS': $!\n";
    }
}

sub get_warnings {
    return &catfile('WARNINGS',1) || '';
}

# MRO: Standardizing
sub catfile {
    my ($file,$ignore) = @_;
    unless(open(CATFILE,"<$file")) {
        print "\nError: Cannot read '$file': $!\n"
            unless($ignore);
        return undef;
    }
    local($/) = undef; # slurp in whole file
    my $contents = <CATFILE>;
    close(CATFILE);
    $contents;
}


sub html_validate {
    my ($extn) = $EXTN;
    if ($EXTN !~ /^\.html?$/i) {
	$extn =~ s/^[^\.]*(\.html?)$/$1/;
    }
    print "\n *** Validating ***\n";
    my @htmls = glob("*$extn");
    my $file;
    foreach $file (@htmls) {
      system("$HTML_VALIDATOR $file");
    }
}

sub lost_argument {
    local($cmd) = @_;
    &write_warnings("\nincomplete argument to command: \\$cmd");
}


# These subroutines should have been handled within the DBM database.
# Unfortunately if the contents of an array are more than ~900 (system
# dependent) chars long then dbm cannot handle it and gives error messages.
# So here we save and then read the contents explicitly.
sub write_mydb {
    my ($db, $key, $str) = @_;
    &write_mydb_simple($db, "\n$mydb_mark#$key#$str");
}

# generate the DB file name from the DB name
sub _dbname {
    "$TMP_$dd$_[0]";
}

sub write_mydb_simple {
    my ($db, $str) = @_;
    my $file = &_dbname($db);
    if(open(DB,">>$file")) {
        print DB $str;
        close DB;
    } else {
        print "\nError: Cannot append to '$file': $!\n";
    }
}

sub clear_mydb {
    my ($db) = @_;
    my $file = &_dbname($db);
    if(open(DB,">$file")) {
        close DB;
    } else {
        print "\nError: Cannot clear '$file': $!\n";
    }
}

# Assumes the existence of a DB file which contains
# sequences of e.g. verbatim counters and verbatim contents.
sub read_mydb {
    my ($dbref,$name) = @_;
    my $contents = &catfile(&_dbname($name),1);
    return '' unless(defined $contents);
    my @tmp = split(/\n$mydb_mark#([^#]*)#/, $contents);
    my $i = 1;	# Ignore the first element at 0
    print "\nDBM: $name open..." if ($VERBOSITY > 2);
    while ($i < scalar(@tmp)) {
	my $tmp1 = $tmp[$i];
        my $tmp2 = $tmp[++$i];
	$$dbref{$tmp1} = defined $tmp2 ? $tmp2 : '';
	++$i;
    };
    $contents;
}


# Reads in a latex generated file (e.g. .bbl or .aux)
# It returns success or failure
# ****** and binds $_ in the caller as a side-effect ******
sub process_ext_file {
    local($ext) = @_;
    local($found, $extfile,$dum,$texpath);
    $extfile =  $EXTERNAL_FILE||$FILE;
    local($file) = &fulltexpath("$extfile.$ext");
    $found = 0;
    &write_warnings(
	    "\n$extfile.$EXT is newer than $extfile.$ext: Please rerun latex" . ## AYS
	    (($ext =~ /bbl/) ? " and bibtex.\n" : ".\n"))
	if ( ($found = (-f $file)) &&
	    &newer(&fulltexpath("$extfile.$EXT"), $file)); ## AYS
    if ((!$found)&&($extfile =~ /\.$EXT$/)) {
	$file = &fulltexpath("$extfile");
	&write_warnings(
	    "\n$extfile is newer than $extfile: Please rerun latex" . ## AYS
	    (($ext =~ /bbl/) ? " and bibtex.\n" : ".\n"))
	    if ( ($found = (-f $file)) &&
		&newer(&fulltexpath("$extfile"), $file)); ## AYS
    }

    # check in other directories on the $TEXINPUTS paths
    if (!$found) {
	foreach $texpath (split /$envkey/, $TEXINPUTS ) {
	    $file = "$texpath$dd$extfile.$ext";
	    last if ($found = (-f $file));
	}
    }
    if ( $found ) {
	print "\nReading $ext file: $file ...";
	# must allow @ within control-sequence names
	$dum = &do_cmd_makeatletter();
	&slurp_input($file);
	if ($ext =~ /bbl/) {
	    # remove the \newcommand{\etalchar}{...} since not needed
	    s/^\\newcommand{\\etalchar}[^\n\r]*[\n\r]+//s;
	}
	&pre_process;
	&substitute_meta_cmds if (%new_command || %new_environment);
	if ($ext eq "aux") {
            my $latex_pathname = L2hos->path2latex($file);
	    $aux_preamble .=
		"\\AtBeginDocument{\\makeatletter\n\\input $latex_pathname\n\\makeatother\n}\n";
	    local(@extlines) = split ("\n", $_);
	    print " translating ".(0+@extlines). " lines " if ($VERBOSITY >1);
	    local($eline,$skip_to); #$_ = '';
	    foreach $eline (@extlines) {
		if ($skip_to) { next unless ($eline =~ s/$O$skip_to$C//) }
		$skip_to = '';
		# skip lines added for pdfTeX/hyperref compatibility
		next if ($eline =~ /^\\(ifx|else|fi|global \\let|gdef|AtEndDocument|let )/);
		# remove \index and \label commands, else invalid links may result
		$eline =~ s/\\(index|label)\s*($O\d+$C).*\2//g;
		if ($eline =~ /\\(old)?contentsline/) {
		    do { local($_,$save_AUX) = ($eline,$AUX_FILE);
		    $AUX_FILE = 0;
		    &wrap_shorthand_environments;
		    #footnote markers upset the numbering
		    s/\\footnote(mark|text)?//g;
		    $eline = &translate_environments($_);
		    $AUX_FILE = $save_AUX;
		    undef $_ };
		} elsif ($eline =~ s/^\\\@input//) {
		    &do_cmd__at_input($eline);
		    $eline = '';
		} elsif ($eline =~ s/^\\\@setckpt$O(\d+)$C//) {
		    $skip_to = $1; next;
		}
#	    $eline =~ s/$image_mark#([^#]+)#/print "\nIMAGE:",$img_params{$1},"\n";''/e;
#		$_ .= &translate_commands(&translate_environments($eline));
		$_ .= &translate_commands($eline) if $eline;
	    }
	    undef @extlines;
	} elsif ($ext =~ /$caption_suffixes/) {
	    local(@extlines) = split ("\n", $_);
	    print " translating ".(0+@extlines). " lines "if ($VERBOSITY >1);
	    local($eline); $_ = '';
	    foreach $eline (@extlines) {
		# remove \index and \label commands, else invalid links may result
		$eline =~ s/\\(index|label)\s*($O\d+$C).*\2//gso;
                if ($eline =~ /\\(old)?contentsline/) {
		    do { local($_,$save_PREAMBLE) = ($eline,$PREAMBLE);
		    $PREAMBLE = 0;
                    &wrap_shorthand_environments;
                    $eline = &translate_environments($_);
		    $PREAMBLE = $save_PREAMBLE;
                    undef $_ };
                }
		$_ .= &translate_commands($eline);
	    }
	    undef @extlines;
	} else {
	    print " wrapping " if ($VERBOSITY >1);
	    &wrap_shorthand_environments;
	    $_ = &translate_commands(&translate_environments($_));
	    print " translating " if ($VERBOSITY >1);
	}
	print "\n processed size: ".length($_)."\n" if($VERBOSITY>1);
	$dum = &do_cmd_makeatother();
    } else { 
	print "\n*** Could not find file: $file ***\n" if ($DEBUG)
    };
    $found;
}

sub deal_with_texinputs {
# The dot precedes all, this let's local files override always.
# The dirs we want are given as parameter list.
    if(!$TEXINPUTS) { $TEXINPUTS = '.' }
    elsif ($TEXINPUTS =~ /^$envkey/) {
	$TEXINPUTS = '.'.$TEXINPUTS
    };
    if ($ROOTED) {$TEXINPUTS .= "$envkey$FIXEDDIR"}
    $TEXINPUTS = &absolutize_path($TEXINPUTS);
    $ENV{'TEXINPUTS'} = join($envkey,".",@_,$TEXINPUTS,$ENV{'TEXINPUTS'});
}

# provided by Fred Drake
sub absolutize_path {
    my ($path) = @_;
    my $npath = '';
    foreach $dir (split /$envkey/o, $path) {
        $npath .= L2hos->Make_directory_absolute($dir) . $envkey;
    }
    $npath =~ s/$envkey$//;
    $npath;
}

sub add_document_info_page {
    # Uses $outermost_level
    # Nasty race conditions if the next two are done in parallel
    local($X) = ++$global{'max_id'};
    local($Y) = ++$global{'max_id'};
    ###MEH -- changed for math support: no underscores in commandnames
    $_ = join('', $_
	      , (($MAX_SPLIT_DEPTH <= $section_commands{$outermost_level})?
		 "\n<HR>\n" : '')
	      , "\\$outermost_level", "*"
	      , "$O$X$C$O$Y$C\\infopagename$O$Y$C$O$X$C\n",
	      , " \\textohtmlinfopage");
}


# For each style file name in TMP_styles (generated by texexpand) look for a
# perl file in $LATEX2HTMLDIR/styles and load it.
sub load_style_file_translations {
    local($_, $style, $options, $dir);
    print "\n";
    if ($TEXDEFS) {
	foreach $dir (split(/$envkey/,$LATEX2HTMLSTYLES)) {
	    if (-f ($_ = "$dir${dd}texdefs.perl")) {
		print "\nLoading $_...";
		require ($_);
		$styles_loaded{'texdefs'} = 1;
		last;
	    }
	}
    }

    # packages automatically implemented
    local($auto_styles) = $AUTO_STYLES;
    $auto_styles .= 'array|' if ($HTML_VERSION > 3.1);
    $auto_styles .= 'tabularx|' if ($HTML_VERSION > 3.1);
    $auto_styles .= 'theorem|';

    # these are not packages, but can appear as if class-options
    $auto_styles .= 'psamsfonts|';
    $auto_styles .= 'noamsfonts|';

    $auto_styles =~ s/\|$//;

    if(open(STYLES, "<$TMP_${dd}styles")) {
        while(<STYLES>) {
            if(s/^\s*(\S+)\s*(.*)$/$style = $1; $options = $2;/eo) {
                &do_require_package($style);
	        $_ = $DONT_INCLUDE;
	        s/:/|/g;
	        &write_warnings("No implementation found for style \`$style\'\n")
		    unless ($styles_loaded{$style} || $style =~ /^($_)$/
			|| $style =~ /$auto_styles/);

                # MRO: Process options for packages
                &do_package_options($style,$options) if($options);
            }
        }
        close(STYLES);
    } else {
        print "\nError: Cannot read '$TMP_${dd}styles': $!\n";
    }
}

################## Weird Special case ##################

# The new texexpand can be told to leave in \input and \include
# commands which contain code that the translator should simply pass
# to latex, such as the psfig stuff.  These should still be seen by
# TeX, so we add them to the preamble ...

sub do_include_lines {
    while (s/$include_line_rx//o) {
	local($include_line) = &revert_to_raw_tex($&);
	&add_to_preamble ('include', $include_line);
    }
}

########################## Preprocessing ############################

# JCL(jcl-verb)
# The \verb declaration and the verbatim environment contain simulated
# typed text and should not be processed. Characters such as $,\,{,and }
# loose their special meanings and should not be considered when marking
# brackets etc. To achieve this \verb declarations and the contents of
# verbatim environments are replaced by markers. At the end the original
# text is put back into the document.
# The markers for verb and verbatim are different so that these commands
# can be restored to what the raw input was just in case they need to
# be passed to latex.

sub pre_process {
    # Modifies $_;
    #JKR: We need support for some special environments.
    # This has to be here, because  they might contain
    # structuring commands like \section etc.
    local(%comments);
    &pre_pre_process if (defined &pre_pre_process);
    s/\\\\/\\\\ /go;		# Makes it unnecessary to look for escaped cmds
    &replace_html_special_chars;
    # Remove fake environment which should be invisible to LaTeX2HTML.
    s/\001//m;
    s/[%]end\s*{latexonly}/\001/gom;
    s/[%]begin\s*{latexonly}([^\001]*)\001/%/gos;
    s/\001//m;

    &preprocess_alltt if defined(&preprocess_alltt);

    $KEEP_FILE_MARKERS = 1;
    if ($KEEP_FILE_MARKERS) {
#	if (s/%%% TEXEXPAND: \w+ FILE( MARKER)? (\S*).*/
#	    '<tex2html_'.($1?'':'end').'file>'.qq|#$2#|."\n"/em) {
#	    $_ = "<tex2html_file>#$2#\n". $_ };
	#RRM: ignore \n at end of included file, else \par may result
	if (s/(\n{1,2})?%%% TEXEXPAND: \w+ FILE( MARKER)? (\S*).*\n?/
	    ($2?$1:"\n").'<tex2html_'.($2?'':'end').'file>'.qq|#$3#|."\n"/em) {
	    $_ = "<tex2html_file>#$3#\n". $_ };
    } else {
	s/%%% TEXEXPAND[^\n]*\n//gm;
    }

    # Move all LaTeX comments into a local list
    s/([ \t]*(^|\G|[^\\]))(%.*(\n[ \t]*|$))/print "%";
	$comments{++$global{'verbatim_counter'}} = "$3";
	&write_mydb("verbatim", $global{'verbatim_counter'}, $3);
	"$1$comment_mark".$global{'verbatim_counter'}."\n"/mge;
    # Remove the htmlonly-environment
    s/\\begin\s*{htmlonly}\s*\n?//gom;
    s/\\end\s*{htmlonly}\s*\n?//gom;
    # Remove enviroments which should be invisible to LaTeX2HTML.
    s/\n[^%\n]*\\end\s*{latexonly}\s*\n?/\001/gom;
    s/((^|\n)[^%\n]*)\\begin\s*{latexonly}([^\001]*)\001/$1/gom;
    s/\\end\s*{comment}\s*\n?/\001/gom;
    s/\\begin\s*{comment}([^\001]*)\001//gom;

    # this used to be earlier, but that can create problems with comments
    &wrap_other_environments if (%other_environments);

#    s/\\\\/\\\\ /go;		# Makes it unnecessary to look for escaped cmds
    local($next, $esc_del);
    &normalize_language_changes;
    # Patches by #JKR, #EI#, #JCL(jcl-verb)

    #protect \verb|\begin/end....|  parts, for LaTeX documentation
    s/(\\verb\*?(.))\\(begin|end)/$1\003$3/g;

    local(@processedV);
    local($opt, $style_info,$before, $contents, $after, $env);
    while (($UNFINISHED_COMMENT)||
  (/\\begin\s*($opt_arg_rx)?\s*\{($verbatim_env_rx|$keepcomments_rx)\}/o)) {
	($opt, $style_info) = ($1,$2);
	$before=$contents=$after=$env='';
	if ($UNFINISHED_COMMENT) {
	    $UNFINISHED_COMMENT =~ s/([^:]*)::(\d+)/$env=$1;$after=$_;
	        $before = join("",$unfinished_mark,$env,$2,"#");''/e;
	    print "\nfound the lost \\end{$env}\n";
	}
	#RRM: can we avoid copying long strings here ?
	#     maybe this loop can be an  s/.../../s  with (.*?)
	#
	($before, $after, $env) = ($`, $', $3) unless ($env);
	if (!($before =~ 
     /\\begin(\s*\[[^\]]*\]\s*)?\{($verbatim_env_rx|$keepcomments_rx)\}/)) {
	    push(@processedV,$before);
	    print "'";$before = '';
	}
 	if ($after =~ /\s*\\end{$env[*]?}/) { # Must NOT use the s///o option!!!
	    ($contents, $after) = ($`, $');
 	    $contents =~ s/^\n+/\n/s;
# 	    $contents =~ s/\n+$//s;

	    # re-insert comments
	    $contents =~ s/$comment_mark(\d+)\n?/$comments{$1}/g;
#	    $contents =~ s/$comment_mark(\d+)/$verbatim{$1}/g;

	    # revert '\\ ' -> '\\' only once 
	    if ($env =~ /rawhtml|$keepcomments_rx/i) {
		$contents = &revert_to_raw_tex($contents);
	    } else {
		$contents =~ s/([^\\](?:\\\\)*\\)([$html_escape_chars])/$1.&special($2)/geos;
		$contents =~ s/\\\\ /\\\\/go;
	    }

	    if ($env =~/$keepcomments_rx/) {
		$verbatim{++$global{'verbatim_counter'}} = "$contents";
	    } else {
		&write_mydb("verbatim", ++$global{'verbatim_counter'}, $contents);
	    }
#	    $verbatim{$global{'verbatim_counter'}} = "$contents" if ($env =~/$keepcomments_rx/);
#	    $verbatim{$global{'verbatim_counter'}} = "$contents";

	    if ($env =~ /rawhtml|$keepcomments_rx/i) {
		if ($before) {
		    $after = join("",$verbatim_mark,$env
			      ,$global{'verbatim_counter'},"#",$after);
		} else {
		    push (@processedV, join("",$verbatim_mark,$env
			   ,$global{'verbatim_counter'},"#"));
		}
	    } elsif ($env =~ /tex2html_code/) {
		if ($before) {
		    $after = join("","\\begin", $opt, "\{verbatim_code\}"
			  , $verbatim_mark,$env
			  , $global{'verbatim_counter'},"#"
			  , "\\end\{verbatim_code\}",$after);
		} else {
		    push (@processedV
			  , join("","\\begin", $opt, "\{verbatim_code\}"
				 , $verbatim_mark,$env
				 , $global{'verbatim_counter'},"#"
				 , "\\end\{verbatim_code\}"));
		}
	    } else {
		if ($before) {
		    $after = join("","\\begin", $opt, "\{tex2html_preform\}"
			  , $verbatim_mark,$env
			  , $global{'verbatim_counter'},"#"
			  , "\\end\{tex2html_preform\}",$after);
		} else {
		    push (@processedV
			  , join("","\\begin", $opt, "\{tex2html_preform\}"
				 , $verbatim_mark,$env
				 , $global{'verbatim_counter'},"#"
				 , "\\end\{tex2html_preform\}" ));
		}
	    }
	} else {
	    print "Cannot find \\end{$env}\n";
	    $after =~ s/$comment_mark(\d+)\n?/$comments{$1}/g;
#	    $after =~ s/$comment_mark(\d+)/$verbatim{$1}/g;
	    if ($env =~ /rawhtml|$keepcomments_rx/i) {
                $after = &revert_to_raw_tex($contents);
	    } else {
		$after =~ s/([^\\](?:\\\\)*\\)([$html_escape_chars])/$1.&special($2)/geos;
                $after =~ s/\\\\ /\\\\/go;
	    }
	    if ($env =~/$keepcomments_rx/) {
                $verbatim{++$global{'verbatim_counter'}} = "$after";
	    } else {
                &write_mydb("verbatim", ++$global{'verbatim_counter'}, $after );
	    }
	    $after = join("",$unfinished_mark,$env
			  ,$global{'verbatim_counter'},"#");
	}
	$_ = join("",$before,$after);
    }
    print STDOUT "\nsensitive environments found: ".(int(0+@processedV/2))." "
	if((@processedV)&&($VERBOSITY > 1));
    $_ = join('',@processedV, $_); undef @processedV;

    #restore \verb|\begin/end....|  parts, for LaTeX documentation
#    $_ =~ s/(\\verb\W*?)\003(begin|end)/$1\\$2/g;
    $_ =~ s/(\\verb(;SPM\w+;|\W*?))\003(begin|end)/$1\\$3/g;

    # Now do the \verb declarations
    # Patches by: #JKR, #EI#, #JCL(jcl-verb)
    # Tag \verb command and legal opening delimiter with unique number.
    # Replace tagged ones and its contents with $verb_mark & id number if the
    # closing delimiter can be found. After no more \verb's are to tag, revert
    # tagged one's to the original pattern.
    local($del,$contents,$verb_rerun);
    local($id) = $global{'verb_counter'};
    # must tag only one alternation per loop
    ##RRM: can this be speeded up using a list ??
    my $vbmark = $verb_mark;
    while (s/\\verb(\t*\*\t*)(\S)/"<verb$1".++$id.">$2"/e ||
	    s/\\verb()(\;SPM\w+\;|[^a-zA-Z*\s])/"<verb$1".++$id.">$2"/e ||
	    s/\\verb(\t\t*)([^*\s])/"<verb$1".++$id.">$2"/e) {

	$del = $2;
	#RRM: retain knowledge of whether \verb* or \verb
	$vb_mark = ($1 =~/^\s*\*/? $verbstar_mark : $verb_mark);
	$esc_del = &escape_rx_chars($del);
	$esc_del = '' if (length($del) > 2);

	# try to find closing delimiter and substitute the complete
	# statement with $verb_mark or $verbstar_mark
#	s/(<verb[^\d>]*$id>[\Q$del\E])([^$esc_del\n]*)([\Q$del\E]|$comment_mark(\d+)\n?)/
	s/(<verb[^\d>]*$id>\Q$del\E)([^$esc_del\n]*?)(\Q$del\E|$comment_mark(\d+)\n?)/
	    $contents=$2;
	    if ($4) { $verb_rerun = 1;
		join('', "\\verb$del", $contents, $comments{$4})
	    } else {
		$contents =~ s|\\\\ |\\\\|g;
		$contents =~ s|\n| |g;
		$verb{$id}=$contents;
		$verb_delim{$id}=$del;
		join('',$vb_mark,$id,$verb_mark)
	    }
	/e;
    }
    $global{'verb_counter'} = $id;
    # revert changes to fake verb statements
    s/<verb([^\d>]*)\d+>/\\verb$1/g;

    #JKR: the comments include the linebreak and the following whitespace
#   s/([^\\]|^)(%.*\n[ \t]*)+/$1/gom; # Remove Comments but not % which may be meaningful
    s/((^|\n)$comment_mark(\d+))+//gom; # Remove comment markers on new lines, but *not* the trailing \n
    s/(\\\w+|(\W?))($comment_mark\d*\n?)/($2)? $2.$3:($1? $1.' ':'')/egm; # Remove comment markers, not after braces
#    s/(\W?)($comment_mark\d*\n?)/($1)? $1.$2:''/egm; # Remove comment markers, not after braces
    # Remove comment markers, but *not* the trailing \n
#  HWS:  Correctly remove multiple %%'s.
#
    s/\\%/\002/gm;
#    s/(%.*\n[ \t]*)//gm;
    s/(%[^\n]*\n)[ \t]*/$comment_mark\n/gm;

    s/\002/\\%/gm;

    local($tmp1,$tmp2);
    s/^$unfinished_mark$keepcomments_rx(\d+)#\n?$verbatim_mark$keepcomments_rx(\d+)#/
	$verbatim{$4}."\n\\end{$1}"/egm; # Raw TeX
    s/$verbatim_mark$keepcomments_rx(\d+)#/
	$tmp1 = $1;
	$tmp2 = &protect_after_comments($verbatim{$2});
	$tmp2 =~ s!\n$!!s;
	join ('', "\\begin{$tmp1}"
		, $tmp2
		, "\n\\end{$tmp1}"
		)/egm; # Raw TeX
    s/$unfinished_mark$keepcomments_rx(\d+)#/$UNFINISHED_COMMENT="$1::$2";
	"\\begin{$1}\n".$verbatim{$2}/egm; # Raw TeX

    $KEEP_FILE_MARKERS = 1;
    if ($KEEP_FILE_MARKERS) {
	s/%%% TEXEXPAND: \w+ FILE( MARKER) (\S*).*\n/
	    '<tex2html_'.($1?'':'end').'file>'.qq|#.$2#\n|/gem;
    } else {
	s/%%% TEXEXPAND[^\n]*\n//gm;
    }

    &mark_string($_);


    # attempt to remove the \html \latex and \latexhtml commands
    s/\\latex\s*($O\d+$C)(.*)\1//gm;
    s/\\latexhtml\s*($O\d+$C)(.*)\1\s*($O\d+$C)(.*)\3/$4/sg;
    s/\\html\s*($O\d+$C)(.*)\1/$2/sg;
    s/\\html\s*($O\d+$C)//gm;

#    &make_unique($_);
}

# RRM:  When comments are retained, then ensure that they are benign
# by removing \s and escaping braces, 
# so that environments/bracing cannot become unbalanced.
sub protect_after_comments {
    my ($verb_text) = @_;
#    $verb_text =~ s/\%(.*)/'%'.&protect_helper($1)/eg;
    $verb_text =~ s/(^|[^\\])(\\\\)*\%(.*)/$1.$2.'%'.&protect_helper($3)/emg;
    $verb_text;
}

sub protect_helper {
    my ($text) = @_;
    $text =~ s/\\/ /g;
    $text =~ s/(\{|\})/\\$1/g;
    $text;
}

sub make_comment {
    local($type,$_) = @_;
    $_ =~ s/\\(index|label)\s*(($O|$OP)\d+($C|$CP)).*\2//sg;
    $_ = &revert_to_raw_tex($_);  s/^\n+//m;
    $_ =~ s/\\(index|label)\s*\{.*\}//sg;
    s/\-\-/- -/g; s/\-\-/- -/g; # cannot have -- inside a comment
    $_ = join('', '<!-- ', $type , "\n ", $_ , "\n -->" );
    $verbatim{++$global{'verbatim_counter'}} = $_;
    &write_mydb('verbatim', $global{'verbatim_counter'}, $_ );
    join('', $verbatim_mark, 'verbatim' , $global{'verbatim_counter'},'#')
}

sub wrap_other_environments {
    local($key, $env, $start, $end, $opt_env, $opt_start);
    foreach $key (keys %other_environments) {
	# skip bogus entries
	next unless ($env = $other_environments{$key});
	$key =~ s/:/($start,$end)=($`,$');':'/e;

	if (($end =~ /^\#$/m) && ($start =~ /^\#/m)) {
	    # catch Indica pre-processor language switches
	    $opt_start = $';
	    if ($env =~ s/\[(\w*)\]//o) {
		$opt_env = join('','[', ($1 ? $1 : $opt_start ), ']');
	    }
	    local($next);
	    while ($_ =~ /$start\b/) {
		push(@pre_wrapped, $`, "\\begin\{pre_$env\}", $opt_env );
		$_=$';
		if (/(\n*)$end/) {
		    push(@pre_wrapped, $`.$1,"\\end\{pre_$env\}$1");
		    $_ = $';
		    if (!(s/^N(IL)?//o)) {$_ = '#'.$_ }
		} else {
		    print "\n *** unclosed $start...$end chunk ***\n";
		    last;
		}
	    }
	    $_ = join('', @pre_wrapped, $_);
	    undef @pre_wrapped;

	} elsif (($end=~/^\n$/) && ($start =~ /^\#/)) {
	    # catch ITRANS pre-processor language info;  $env = 'nowrap';
	    local($ilang) = $start; $ilang =~ s/^\#//m;
	    s/$start\s*\=([^<\n%]*)\s*($comment_mark\d*|\n|%)/\\begin\{tex2html_$env\}\\ITRANSinfo\{$ilang\}\{$1\}\n\\end\{tex2html_$env\}$2/g;

	} elsif (!$end &&($start =~ /^\#/m)) {
	    # catch Indica pre-processor input-mode switches
	    s/$start(.*)\n/\\begin\{tex2html_$env\}$&\\end\{tex2html_$env\}\n/g;

	} elsif (($start eq $end)&&(length($start) == 1)) {
	    $start =~ s/(\W)/\\$1/; $end = $start;
	    s/([^$end])$start([^$end]+)$end/$1\\begin\{pre_$env\}$2\\end\{pre_$env\}/mg;
	} elsif ($start eq $end) {
	    if (!($start =~ /\#\#/)) {
		$start =~ s/(\W)/\\$1/g; $end = $start; }
	    local (@pre_wrapped);
	    local($opt); $opt = '[indian]' if ($start =~ /^\#\#$/m);
	    while ($_ =~ /$start/s) {
		push(@pre_wrapped, $` , "\\begin\{pre_$env\}$opt");
		$_=$';
		if (/$end/s) {
		    push(@pre_wrapped, $`, "\\end\{pre_$env\}");
		    $_ = $';
		} else {
		    print "\n *** unclosed $start...$end chunk ***\n";
		    last;
		}
	    }
	    $_ = join('', @pre_wrapped, $_);
	    undef @pre_wrapped;
	} elsif ($start && ($env =~ /itrans/)) {
	    # ITRANS is of this form
	    local($indic); if($start =~ /\#(\w+)$/m) {$indic = $1}
	    #include the language-name as an optional parameter
	    s/$start\b/\\begin\{pre_$env\}\[$indic\]/sg;
	    s/$end\b/\\end\{pre_$env\}/sg;
	} elsif (($start)&&($end)) {
	    s/$start\b/\\begin\{pre_$env\}/sg;
	    s/$end\b/\\end\{pre_$env\}/sg;
	}
    }
    $_;
}

#################### Marking Matching Brackets ######################

# Reads the entire input file and performs pre_processing operations
# on it before returning it as a single string. The pre_processing is
# done on separate chunks of the input file by separate Unix processes
# as determined by LaTeX \input commands, in order to reduce the memory
# requirements of LaTeX2HTML.
sub slurp_input_and_partition_and_pre_process {
    local($file) = @_;
    local(%string, @files, $pos);
    local ($count) =  1;

    unless(open(SINPUT,"<$file")) {
        die "\nError: Cannot read '$file': $!\n";
    }
    local(@file_string);
    print STDOUT "$file" if ($VERBOSITY >1);
    while (<SINPUT>) {
	if (/TEXEXPAND: INCLUDED FILE MARKER (\S*)/) {
	    # Forking seems to screw up the rest of the input stream
	    # We save the current position ...
	    $pos = tell SINPUT;
	    print STDOUT " fork at offset $pos " if ($VERBOSITY >1);
            $string{'STRING'} = join('',@file_string); @file_string = ();
	    &write_string_out($count);
	    delete $string{'STRING'};
	    # ... so that we can return to it
	    seek(SINPUT, $pos, 0);
	    print STDOUT "\nDoing $1 ";
	    ++$count}
	else {
#	    $string{'STRING'} .= $_
	    push(@file_string,$_);
	}
    }
    $string{'STRING'} = join('',@file_string); @file_string = ();
    &write_string_out($count);
    delete $string{'STRING'};
    close SINPUT;
    @files = ();
    if(opendir(DIR, $TMP_)) {
        @files = sort grep(/^\Q$PARTITION_PREFIX\E\d+/, readdir(DIR));
        closedir(DIR);
    }

    unless(@files) {
        die "\nFailed to read in document parts.\n".
	     "Look up section Globbing in the troubleshooting manual.\n";
    }

    $count = 0;
    foreach $file (@files) {
	print STDOUT "\nappending file: $TMP_$dd$file " if ($VERBOSITY > 1);
        $_ .= (&catfile("$TMP_$dd$file") || '');
	print STDOUT "\ntotal length: ".length($_)." characters\n" if ($VERBOSITY > 1);
    }
    die "\nFailed to read in document parts (out of memory?).\n"
	unless length($_);
    print STDOUT "\ntotal length: ".length($_)." characters\n" if ($VERBOSITY > 1);
}

sub write_string_out {
    local($count) = @_;
    if ($count < 10) {$count = '00'.$count}
    elsif ($count < 100) {$count = '0'.$count}
    local($pid);
    # All open unflushed streams are inherited by the child. If this is
    # not set then the parent will *not* wait
    $| = 1;
    # fork returns 0 to the child and PID to the parent
    &write_mydb_simple("prelatex", $prelatex);
    &close_dbm_database;
    unless ($CAN_FORK) {
	&do_write_string_out;
    } else {
	unless ($pid = fork) {
	    &do_write_string_out;
	    exit 0;
	};
	waitpid($pid,0);
    }
    &open_dbm_database;
}

sub do_write_string_out {
    local($_);
    close (SINPUT) if($CAN_FORK);
    &open_dbm_database;
    $_ = delete $string{'STRING'};
    # locate blank-lines, for paragraphs.
    # Replace verbatim environments etc.
    &pre_process;
    # locate the blank lines for \par s
    &substitute_pars;
    # Handle newcommand, newenvironment, newcounter ...
    &substitute_meta_cmds;
    &wrap_shorthand_environments;
    print STDOUT "\n *** End-of-partition ***" if ($VERBOSITY > 1);
    if(open(OUT, ">$TMP_$dd$PARTITION_PREFIX$count")) {
        print OUT $_;
        close(OUT);
    } else {
        print "\nError: Cannot write '$TMP_$dd$PARTITION_PREFIX$count': $!\n";
    }
    print STDOUT $_ if ($VERBOSITY > 9);
    $preamble = join("\n",$preamble,@preamble); # undef @preamble;
    &write_mydb_simple("preamble", $preamble);
    # this was done earlier; it should not be repeated
    #&write_mydb_simple("prelatex", $prelatex);
    &write_mydb_simple("aux_preamble", $aux_preamble);
    &close_dbm_database;
}

# Reads the entire input file into a
# single string.
sub slurp_input  {
    local($file) = @_;
    local(%string);
    if(open(INPUT,"<$file")) {
        local(@file_string);
        while (<INPUT>) {
	    push(@file_string, $_ );
        }
        $string{'STRING'} = join('',@file_string);
        close INPUT;
        undef @file_string;
    } else {
        print "\nError: Cannot read '$file': $!\n";
    }
    $_ = delete $string{'STRING'}; # Blow it away and return the result
}

# MRO: make them more efficient
sub special {
    $html_specials{$_[0]} || $_[0];
}

sub special_inv {
    $html_specials_inv{$_[0]} || $_[0];
}

sub special_html {
    $html_special_entities{$_[0]} || $_[0];
}

sub special_html_inv {
    $html_spec_entities_inv{$_[0]} || $_[0];
}

# Mark each matching opening and closing bracket with a unique id.
sub mark_string {
    # local (*_) = @_; # Modifies $_ in the caller;
    # -> MRO: changed to $_[0] (same effect)
    # MRO: removed deprecated $*, replaced by option /m
    $_[0] =~ s/(^|[^\\])\\{/$1tex2html_escaped_opening_bracket/gom;
    $_[0] =~ s/(^|[^\\])\\{/$1tex2html_escaped_opening_bracket/gom; # repeat this
    $_[0] =~ s/(^|[^\\])\\}/$1tex2html_escaped_closing_bracket/gom;
    $_[0] =~ s/(^|[^\\])\\}/$1tex2html_escaped_closing_bracket/gom; # repeat this
    my $id = $global{'max_id'};
    my $prev_id = $id;
    # mark all balanced braces
    # MRO: This should in fact mark all of them as the hierarchy is
    # processed inside-out.
    1 while($_[0] =~ s/{([^{}]*)}/join("",$O,++$id,$C,$1,$O,$id,$C)/geo);
    # What follows seems esoteric...
    my @processedB = ();
    # Take one opening brace at a time
    while ($_[0] =~ /\{/) { 
	my ($before,$after) = ($`,$');
        my $change = 0;
	while (@UNMATCHED_OPENING && $before =~ /\}/) {
            my $this = pop(@UNMATCHED_OPENING);
            print "\n *** matching brace \#$this found ***\n";
            $before =~ s/\}/join("",$O,$this,$C)/eo;
            $change = 1;
        }
        $_[0] = join('',$before,"\{",$after) if($change);
        # MRO: mark one opening brace
	if($_[0] =~ s/^([^{]*){/push(@processedB,$1);join('',$O,++$id,$C)/eos) {
	    $before=''; $after=$';
        }
        if ($after =~ /\}/) { 
	    $after =~ s/\}/join("",$O,$id,$C)/eo;
	    $_[0] = join('',$before,$O,$id,$C,$after);
	} else {
	    print "\n *** opening brace \#$id  is unmatched ***\n";
	    $after =~ /^(.+\n)(.+\n)?/;
	    print " preceding: $after \n";
	    push (@UNMATCHED_OPENING,$id);
	}
    }
    $_[0] = join('',@processedB,$_[0]); undef(@processedB);
    print STDOUT "\nInfo: bracketings found: ", $id - $prev_id,"\n"
        if ($VERBOSITY > 1);
    # process remaining closing braces
    while (@UNMATCHED_OPENING && $_[0] =~ /\}/) {
        my $this = pop(@UNMATCHED_OPENING);
        print "\n *** matching brace \#$this found ***\n";
	$_[0] =~ s/\}/join("",$O,$this,$C)/eo;
    }

    while ($_[0] =~ /\}/) {
        print "\n *** there was an unmatched closing \} ";
        my ($beforeline,$prevline,$afterline) = ($`, $`.$& , $');
        $prevline =~ /\n([^\n]+)\}$/m;
        if ($1) {
	    print "at the end of:\n" . $1 . "\}\n\n";
        } else {
	    $afterline =~ /^([^\n]+)\n/m;
	    if ($1) {
	        print "at the start of:\n\}" . $1 ."\n\n";
	    } else {
	        $prevline =~ /\n([^\n]+)\n\}$/m;
	        print "on a line by itself after:\n" . $1 . "\n\}\n\n";
	    }
        }
        $_[0] =  $beforeline . $afterline;
    }
    $global{'max_id'} = $id;

    # restore escaped braces
    $_[0] =~ s/tex2html_escaped_opening_bracket/\\{/go;
    $_[0] =~ s/tex2html_escaped_closing_bracket/\\}/go;
}

sub replace_html_special_chars {
    # Replaces html special characters with markers unless preceded by "\"
    s/([^\\])(<|>|&|\"|``|'')/&special($1).&special($2)/geom;
    # MUST DO IT AGAIN JUST IN CASE THERE ARE CONSECUTIVE HTML SPECIALS
    s/([^\\])(<|>|&|\"|``|'')/&special($1).&special($2)/geom;
    s/^(<|>|&|\"|``|'')/&special($1)/geom;
}

#  used in \verbatiminput only:   $html_escape_chars = '<>&';
sub replace_all_html_special_chars { s/([$html_escape_chars])/&special($1)/geom; }

# The bibliography and the index should be treated as separate sections
# in their own HTML files. The \bibliography{} command acts as a sectioning command
# that has the desired effect. But when the bibliography is constructed
# manually using the thebibliography environment, or when using the
# theindex environment it is not possible to use the normal sectioning
# mechanism. This subroutine inserts a \bibliography{} or a dummy
# \textohtmlindex command just before the appropriate environments
# to force sectioning.
sub add_bbl_and_idx_dummy_commands {
    local($id) = $global{'max_id'};

    s/([\\]begin\s*$O\d+$C\s*thebibliography)/$bbl_cnt++; $1/eg;
    ## if ($bbl_cnt == 1) {
	s/([\\]begin\s*$O\d+$C\s*thebibliography)/$id++; "\\bibliography$O$id$C$O$id$C $1"/geo;
    #}
    $global{'max_id'} = $id;
    s/([\\]begin\s*$O\d+$C\s*theindex)/\\textohtmlindex $1/o;
    s/[\\]printindex/\\textohtmlindex /o;
    &lib_add_bbl_and_idx_dummy_commands() if defined(&lib_add_bbl_and_idx_dummy_commands);
}


# Uses and modifies $default_language
# This would be straight-forward except when there are
#  \MakeUppercase, \MakeLowercase  or \uppercase , \lowercase commands
# present in the source. The cases have to be adjusted before the
# ISO-character code is set; e.g. with "z --> "Z  in  german.perl
#
sub convert_iso_latin_chars {
    local($_) = @_;
    local($next_language, $pattern);
    local($xafter, $before, $after, $funct, $level, $delim);
    local(@case_processed);
    while (/$case_change_rx/) {
	$xafter = $2;
#	$before .= $`;
	push(@case_processed, $`);
	$funct = $3;
	$after = '';
	$_ = $';
	if ($xafter =~ /noexpand/) { $before .= "\\$funct"; next; }

	s/^[\s%]*(.)/$delim=$1;''/eo;
	if ($delim =~ /{/ ) {
            # brackets not yet numbered...
#	    $before .= $funct . $delim;
	    push(@case_processed, $funct . $delim);
	    $level = 1;
	    $after = $delim;
	    while (($level)&&($_)&&(/[\{\}]/)) {
		$after .= $` . $&;
		$_ = $';
		if ( "$&" eq "\{" ) {$level++}
		elsif ( "$&" eq "\}" ) { $level-- }
		else { print $_ }
		print "$level";
	    } 
#	    $before .= $after;
	    push(@case_processed, $after);
	} elsif ($delim eq "<") {
            # brackets numbered, but maybe not processed...
	    s/((<|#)(\d+)(>|#)>).*\1//;
	    $after .= $delim . $&;
	    $_ = $';
	    print STDOUT "\n<$2$funct$4>" if ($VERBOSITY > 2);
	    $funct =~ s/^\\//o;
	    local($cmd) = "do_cmd_$funct";
	    $after = &$cmd($after);
#	    $before .= $after;
	    push(@case_processed, $after);
	} elsif (($xafter)&&($delim eq "\\")) {
	    # preceded by \expandafter ...
	    # ...so expand the following macro first
	    $funct =~ s/^\\//o;
	    local($case_change) = $funct;
	    s/^(\w+|\W)/$funct=$1;''/eo;
	    local($cmd) = $funct;
	    local($thiscmd) = "do_cmd_$funct";
	    if (defined &$thiscmd) { $_ = &$thiscmd($_) }
	    elsif ($new_command{$funct}) { 
		local($argn, $body, $opt) = split(/:!:/, $new_command{$funct});
		do { ### local($_) = $body;
		     &make_unique($body);
		} if ($body =~ /$O/);
		if ($argn) {
		    do { 
			local($before) = '';
			local($after) = "\\$funct ".$_;
			$after = &substitute_newcmd;   # may change $after
			$after =~ s/\\\@#\@\@/\\/o ;
		    }
		} else { $_ = $body . $_; }
	    } else { print "\nUNKNOWN COMMAND: $cmd "; }

	    $cmd = $case_change;
	    $case_change = "do_cmd_$cmd";
	    if (defined &$case_change) { $_ = &$case_change($_) }
	} else {
            # this should not happen, but just in case...
	    $funct =~ s/^\\//o;
	    local($cmd) = "do_cmd_$funct";
	    print STDOUT "\n\n<$delim$funct>" if ($VERBOSITY > 2);
	    $_ = join('', $delim , $_ );
	    if (defined &$cmd) { $_ = &$cmd($_) }
	}
    }
#   $_ = join('', $before, $_) if ($before);
    $_ = join('', @case_processed, $_) if (@case_processed);

    # ...now do the conversions
    ($before, $after, $funct) = ('','','');
    @case_processed = ();
    if (/$language_rx/o) {
	($next_language, $pattern, $before, $after) = (($2||$1), $&, $`, $');
	$before = &convert_iso_latin_chars($before) if ($before);
#	push(@case_processed, $pattern, $before);
	local($br_id) = ++$global{'max_id'};
	$pattern = join('' , '\selectlanguage', $O.$br_id.$C
	    , (($pattern =~ /original/) ? $TITLES_LANGUAGE : $next_language )
	    , $O.$br_id.$C );
	push(@case_processed, $before, $pattern);
	push(@language_stack, $default_language);
	$default_language = $next_language;
	$_ = &convert_iso_latin_chars($after);
	$default_language = pop @language_stack;
    } else {
	$funct = $language_translations{$default_language};
	(defined(&$funct) ? $_ = &$funct($_) :
	 do {   &write_warnings(
		"\nCould not find translation function for $default_language.\n\n")
	    }
	);
	if ($USE_UTF ||(!$NO_UTF &&(defined %unicode_table)&&length(%unicode_table)>2)) {
	    &convert_to_unicode($_)};
    }
    $_ = join('', @case_processed, $_); undef(@case_processed);
    $_;
}

# May need to add something here later
sub english_translation { $_[0] }

# This replaces \setlanguage{\language} with \languageTeX
# This makes the identification of language chunks easier.
sub normalize_language_changes {
    s/$setlanguage_rx/\\$2TeX/gs;
}

sub get_current_language {
    return () if ($default_language eq $TITLES_LANGUAGE);
    local($lang,$lstyle) = ' LANG="';
    $lang_code = $iso_languages{$default_language};
    if (%styled_languages) {
	$lstyle = $styled_languages{$default_language};
	$lstyle = '" CLASS="'.$lstyle  if $lstyle;
    }
    ($lang_code ? $lang.$lang_code.$lstyle.'"' : '');
}

%styled_languages = ();

sub do_cmd_htmllanguagestyle {
    local($_) = @_;
    local($class) = &get_next_optional_argument;
    local($lang) = &missing_braces unless (
	(s/$next_pair_pr_rx/$lang=$2;''/e)
	||(s/$next_pair_rx/$lang=$2;''/e));
    return ($_) unless $lang;
    local($class) = $iso_languages{$lang} unless $class;
    if ($USING_STYLES && $class) {
	print "\nStyling language: $lang = \"$class\" ";
    	$styled_languages{"$lang"} = $class;
    }
    $_;
}

# General translation mechanism:
#
#
# The main program latex2html calls texexpand with the document name
# in order to expand some of its \input and \include statements, here
# also called 'merging', and to write a list of sensitized style, class,
# input, or include file names.
# When texexpand has finished, all is contained in one file, TMP_foo.
# (assumed foo.tex is the name of the document to translate).
#
# In this version, texexpand cares for following environments
# that may span include files / section boundaries:
# (For a more technical description, see texexpand.)
#  a) \begin{comment}
#  b) %begin{comment}
#  c) \begin{any}  introduced with \excludecomment
#  d) %begin{any}
#  e) \begin{verbatim}
#  f) \begin{latexonly}
#  g) %begin{latexonly}
# 
# a)-d) cause texexpand to drop its contents, it will not show up in the
# output file. You can use this to 'comment out' a bunch of files, say.
# 
# e)-g) prevent texexpand from expanding input files, but the environment
# content goes fully into the output file.
# 
# Together with each merging of \input etc. there are so-called %%%texexpand
# markers accompanying the boundary.
#
# When latex2html reads in the output file, it uses these markers to write
# each part to a separate file, and process them further.
#
#
# If you have, for example:
#
# a) preample
# b) \begin{document}
# c) text
# d) \input{chapter}
# e) more text
# f) \end{document}
#
# you end up in two parts, part 1 is a)-c), part 2 is the rest.
# Regardless of environments spanning input files or sections.
#
#
# What now starts is meta command substitution:
# Therefore, latex2html forks a child process on the first part and waits
# until it finished, then forks another on the next part and so forth
# (see also &slurp_input_and_partition_and_preprocess).
#
# Here's what each child is doing:
# Each child process reads the new commands translated so far by the previous
# child from the TMP_global DBM database.
# After &pre_processing, it substitutes the meta commands (\newcommand, \def,
# and the like) it finds, and adds the freshly retrieved new commands to the
# list so far.
# This is done *only on its part* of the document; this saves upwards of memory.
# Finally, it writes its list of new commands (synopsis and bodies) to the
# DBM database, and exits.
# After the last child finished, latex2html reads in all parts and
# concatenates them.
#
#
# So, at this point in time (start of &translate), it again has the complete
# document, but now preprocessed and with new commands substituted.
# This has several disadvantages: an amount of commands is substituted (in
# TeX lingo, expanded) earlier than the rest.
# This causes trouble if commands really must get expanded at the point
# in time they show up.
#
#
# Then, still in &translate, latex2html uses the list of section commands to
# split the complete document into chunks.
# The chunks are not written to files yet. They are retained in the @sections
# list, but each chunk is handled separately.
# latex2html puts the current chunk to $_ and processes it with
# &translate_environments etc., then fetches the next chunk, and so on.
# This prevents environments that span section boundaries from getting
# translated, because \begin and \end cannot find one another, to say it this
# way.
#
#
# After the chunk is translated to HTML, it is written to a file.
# When all chunks are done, latex2html rereads each file to get cross
# references right, replace image markers with the image file names, and
# writes index and bibliography.
#
#
sub translate {
    &normalize_sections;	# Deal with the *-form of sectioning commands

    # Split the input into sections, keeping the preamble together
    # Due to the regular expression, each split will create 5 more entries.
    # Entry 1 and 2: non-letter/letter sectioning command,
    # entry 4: the delimiter (may be empty)
    # entry 5: the text.
    local($pre_section, @sections);
    if (/\\(startdocument|begin\s*($O\d+$C)\s*document\s*\2)/) {
	$pre_section = $`.$&; $_ = $';
    }
    @sections = split(/$sections_rx/, $_);
    $sections[0] = $pre_section.$sections[0] if ($pre_section);
    undef $pre_section;
    local($sections) = int(scalar(@sections) / 5);

    # Initialises $curr_sec_id to a list of 0's equal to
    # the number of sectioning commands.
    local(@curr_sec_id) = split(' ', &make_first_key);
    local(@segment_sec_id) = @curr_sec_id;
    local($i, $j, $current_depth) = (0,0,0);
    local($curr_sec) = $SHORT_FILENAME||$FILE;
    local($top_sec) = ($SEGMENT ? '' : 'top of ');
#    local(%section_info, %toc_section_info, $CURRENT_FILE, %cite_info, %ref_files);
    local($CURRENT_FILE);
    # These filenames may be set when translating the corresponding commands.
    local($tocfile, $loffile, $lotfile, $footfile, $citefile, $idxfile,
	  $figure_captions, $table_captions, $footnotes, $citations, %font_size, %index,
	  %done, $t_title, $t_author, $t_date, $t_address, $t_affil, $changed);
    local(@authors,@affils,@addresses,@emails,@authorURLs);
    local(%index_labels, %index_segment, $preindex, %footnotes, %citefiles);
    local($segment_table_captions, $segment_figure_captions);
    local($dir,$nosave) = ('','');
    local($del,$close_all,$open_all,$toc_sec_title,$multiple_toc);
    local($open_tags_R) = [];
    local(@save_open_tags)= ();
    local(@language_stack) = ();
    push (@language_stack, $default_language);

#    $LATEX_FONT_SIZE = '10pt' unless ($LATEX_FONT_SIZE);
    &process_aux_file 
	if $SHOW_SECTION_NUMBERS || /\\(caption|(html|hyper)?((eq)?ref|cite))/;

    require ("${PREFIX}internals.pl") if (-f "${PREFIX}internals.pl");
#JCL(jcl-del)
    &make_single_cmd_rx;
#
    $tocfile = $EXTERNAL_CONTENTS;
    $idxfile = $EXTERNAL_INDEX;
    $citefile = $EXTERNAL_BIBLIO; $citefile =~ s/#.*$//;
    $citefiles{1} = $citefile if ($citefile);
    print "\nTranslating ...";

    while ($i <= @sections) {
        undef $_;
	$_ = $sections[$i];
	s/^[\s]*//;		# Remove initial blank lines

	# The section command was removed when splitting ...
	s/^/\\$curr_sec$del/  if ($i > 0); # ... so put it back
	if ($current_depth < $MAX_SPLIT_DEPTH)  {
	    if (($footnotes)&&($NO_FOOTNODE)&&( $current_depth < $MAX_SPLIT_DEPTH)) {
		local($thesenotes) = &make_footnotes ;
		print OUTPUT $thesenotes;
	    }
	    $CURRENT_FILE = &make_name($curr_sec, join('_',@curr_sec_id));
	    
	    open(OUTPUT, ">$CURRENT_FILE")
		|| die "Cannot write '$CURRENT_FILE': $!\n";
	    if ($XBIT_HACK) { # use Apache's XBit hack
		chmod 0744, $CURRENT_FILE;
		&check_htaccess;
	    } else {
		chmod 0644, $CURRENT_FILE;
	    }

	    if ($MULTIPLE_FILES && $ROOTED) {
	        if ($DESTDIR =~ /^\Q$FIXEDDIR\E[$dd$dd]?([^$dd$dd]+)/)
	            { $CURRENT_FILE = "$1$dd$CURRENT_FILE" };
	    }
	}
	&remove_document_env;
#        &wrap_shorthand_environments;    #RRM  Is this needed ?
	print STDOUT "\n" if ($VERBOSITY);
	print STDOUT "\n" if ($VERBOSITY > 2);
	print $i/5,"/$sections";
	print ":$top_sec$curr_sec:" if ($VERBOSITY);

	# Must do this early ... It also sets $TITLE
	&process_command($sections_rx, $_) if (/^$sections_rx/);
	# reset tags saved from the previous section
	$open_tags_R = [ @save_open_tags ];
	@save_open_tags = ();

	local($curr_sec_tex);
	if ((! $TITLE) || ($TITLE eq $default_title)) {
	    eval '$TITLE = '.$default_title;
	    $TITLE = $default_title if $@;
	    $curr_sec_tex = ($top_sec ? '' :
		  join('', '"', &revert_to_raw_tex($curr_sec), '"'));
	    print STDOUT "$curr_sec_tex for $CURRENT_FILE\n" if ($VERBOSITY);
	} else { 
	    local($tmp) = &purify($TITLE,1);
	    $tmp = &revert_to_raw_tex($tmp);
	    print STDOUT "\"$tmp\" for $CURRENT_FILE\n" if ($VERBOSITY); 
	}

	if (/\\(latextohtmlditchpreceding|startdocument)/m) {
 	    local($after) = $';
 	    local($before) = $`.$&;
	    $SEGMENT = 1 if ($1 =~ /startdocument/);
	    print STDOUT "\n *** translating preamble ***\n" if ($VERBOSITY);
	    $_ = &translate_preamble($before);
	    s/\n\n//g; s/<BR>//g;	# remove redundant blank lines and breaks
#
#	    &process_aux_file  if $AUX_FILE_NEEDED;
#
	    print STDOUT "\n *** preamble done ***\n" if ($VERBOSITY);
	    $PREAMBLE = 0;
 	    $NESTING_LEVEL=0;
	    &do_AtBeginDocument;
	    $after =~ s/^\s*//m;
	    print STDOUT (($VERBOSITY >2)? "\n*** Translating environments ***" : ";");
	    $after = &translate_environments($after);
	    print STDOUT (($VERBOSITY >2)? "\n*** Translating commands ***" : ";");
	    $_ .= &translate_commands($after);
#            $_ = &translate_commands($after);
 	} else {
	    &do_AtBeginDocument;
	    $PREAMBLE = 0;
 	    $NESTING_LEVEL=0;
	    print STDOUT (($VERBOSITY >2)? "\n*** Translating environments ***" : ";");
 	    $_ = &translate_environments($_);
	    print STDOUT (($VERBOSITY >2)? "\n*** Translating commands ***" : ";");
 	    $_ = &translate_commands($_);
 	}

	# close any tags that remain open
	if (@$open_tags_R) {
	    ($close_all,$open_all) = &preserve_open_tags();
	    $_ .= $close_all; 
	    @save_open_tags = @$open_tags_R; $open_tags_R = [];
	} else { ($close_all,$open_all) = ('','') }

	print STDOUT (($VERBOSITY >2)? "\n*** Translations done ***" : "\n");
#	if (($footnotes)&&($NO_FOOTNODE)&&( $current_depth < $MAX_SPLIT_DEPTH)) {
#	    $_ .= &make_footnotes
#	}
	print OUTPUT $_;

	# Associate each id with the depth, the filename and the title
	###MEH -- starred sections don't show up in TOC ...
	# RRM:  ...unless $TOC_STARS is set
#	$toc_sec_title = &simplify($toc_sec_title);
	$toc_sec_title = &purify($toc_sec_title);# if $SEGMENT;
	$toc_sec_title = &purify($TITLE) unless ($toc_sec_title);	

	if ($TOC_STARS) {
	    $toc_section_info{join(' ',@curr_sec_id)} =
		"$current_depth$delim$CURRENT_FILE$delim$toc_sec_title"
#		    if ($current_depth <= $MAX_SPLIT_DEPTH + $MAX_LINK_DEPTH);
		    if ($current_depth <= $TOC_DEPTH);
	} else {
	    $toc_section_info{join(' ',@curr_sec_id)} =
		"$current_depth$delim$CURRENT_FILE$delim$toc_sec_title"
		. ($curr_sec =~ /star$/ ? "$delim<tex2html_star_mark>" : "")
#		    if ($current_depth <= $MAX_SPLIT_DEPTH + $MAX_LINK_DEPTH);
		    if ($current_depth <= $TOC_DEPTH);
	}

	# include $BODYTEXT in the section_info, when starting a new page
	$section_info{join(' ',@curr_sec_id)} =
	    "$current_depth$delim$CURRENT_FILE$delim$TITLE$delim"
		. (($current_depth < $MAX_SPLIT_DEPTH)? $BODYTEXT: "");

	# Get type of section (see also the split above)
	$curr_sec = $sections[$i+1].$sections[$i+2];
	$del = $sections[$i+4];

	# Get the depth of the current section;
#	$curr_sec = $outermost_level unless $curr_sec;
	$current_depth = $section_commands{$curr_sec};
	if ($after_segment) {
	    $current_depth = $after_segment;
            $curr_sec_id[$after_segment] += $after_seg_num;
            ($after_segment,$after_seg_num) = ('','');
	    for($j=1+$current_depth; $j <= $#curr_sec_id; $j++) {
		$curr_sec_id[$j] = 0;
	    }
	}
	if ($SEGMENT||$SEGMENTED) {
	    for($j=1; $j <= $#curr_sec_id; $j++) {
		$curr_sec_id[$j] += $segment_sec_id[$j];
		$segment_sec_id[$j] = 0;
	    }
	}; 


	# this may alter the section-keys
	$multiple_toc = 1 if ($MULTIPLE_FILES && $ROOTED && (/$toc_mark/));


	#RRM : Should this be done here, or in \stepcounter ?
	@curr_sec_id = &new_level($current_depth, @curr_sec_id);

	$toc_sec_title = $TITLE = $top_sec = '';
	$i+=5; #skip to next text section
    }
    $open_tags_R = [];
    $open_all = '';

    $_ = undef;
    $_ = &make_footnotes if ($footnotes);
    $CURRENT_FILE = '';
    print OUTPUT;
    close OUTPUT;
    

#    # this may alter the section-keys
#    &adjust_root_keys if $multiple_toc;

    if ($PREPROCESS_IMAGES) { &preprocess_images }
    else { &make_image_file }
    print STDOUT "\n *** making images ***" if ($VERBOSITY > 1);
    &make_images;

    # Link sections, add head/body/address do cross-refs etc
    print STDOUT "\n *** post-process ***" if ($VERBOSITY > 1);
    &post_process;

    if (defined &document_post_post_process) {
    	#BRM: extra document-wide post-processing
	print STDOUT "\n *** post-processing Document ***" if ($VERBOSITY > 1);
	&document_post_post_process();
    }

    print STDOUT "\n *** post-processed ***" if ($VERBOSITY > 1);
    &copy_icons if $LOCAL_ICONS;
    if ($SEGMENT || $DEBUG || $SEGMENTED) {
	&save_captions_in_file("figure",  $figure_captions) if $figure_captions;
	&save_captions_in_file("table",  $table_captions) if $table_captions;
#	&save_array_in_file ("captions", "figure_captions", 0, %figure_captions) if %figure_captions;
#	&save_array_in_file ("captions", "table_captions", 0, %table_captions) if %table_captions;
	&save_array_in_file ("index", "index", 0, %index);
	&save_array_in_file ("sections", "section_info", 0, %section_info);
	&save_array_in_file ("contents", "toc_section_info", 0,%toc_section_info);
	&save_array_in_file ("index", "sub_index", 1, %sub_index) if %sub_index;
	&save_array_in_file ("index", "index_labels", 1, %index_labels) if %index_labels;
	&save_array_in_file ("index", "index_segment", 1, %index_segment) if %index_segment;
	&save_array_in_file ("index", "printable_key", 1, %printable_key) 
	    if (%printable_key || %index_segment);
    }
    elsif ($MULTIPLE_FILES && $ROOTED) {
	&save_array_in_file ("sections", "section_info", 0, %section_info);
	&save_array_in_file ("contents", "toc_section_info", 0, %toc_section_info);
    }
    &save_array_in_file ("internals", "ref_files", 0, %ref_files) if $changed;
    &save_array_in_file ("labels", "external_labels", 0, %ref_files);
    &save_array_in_file ("labels", "external_latex_labels", 1, %latex_labels);
    &save_array_in_file ("images", "cached_env_img", 0, %cached_env_img);
}

# RRM:
sub translate_preamble {
    local($_) = @_;
    $PREAMBLE = 1;
    $NESTING_LEVEL=0;   #counter for TeX group nesting level
    # remove some artificially inserted constructions
    s/\n${tex2html_deferred_rx}\\par\s*${tex2html_deferred_rx2}\n/\n/gm;
    s/\\newedcommand(<<\d+>>)([A-Za-z]+|[^A-Za-z])\1(\[\d+\])?(\[[^]]*\])?(<<\d+>>)[\w\W\n]*\5($comment_mark\d*)?//gm;
    s/\n{2,}/\n/ogm;

    if (/\\htmlhead/) {
        print STDOUT "\nPREAMBLE: discarding...\n$`" if ($VERBOSITY > 4);
        local($after) = $&.$';
	# translate segment preamble preceding  \htmlhead
	&translate_commands(&translate_environments($`));
	# translate \htmlhead  and rest of preamble
	$_=&translate_commands(&translate_environments($after));
        print STDOUT "\nPREAMBLE: retaining...\n$_" if ($VERBOSITY > 4);
    } else {
	# translate only preamble here (metacommands etc.)
	# there should be no textual results, if so, discard them
	&translate_commands(&translate_environments($_));
        print STDOUT "\nPREAMBLE: discarding...\n$_" if ($VERBOSITY > 4);
	$_="";
    };
    $_ = &do_AtBeginDocument($_);
    if (! $SEGMENT) { $_ = ''} # segmented documents have a heading already
    $_;
}

############################ Processing Environments ##########################

sub wrap_shorthand_environments {
    # This wraps a dummy environment around environments that do not use
    # the begin-end convention. The wrapper will force them to be
    # evaluated by Latex rather than them being translated.
    # Wrap a dummy environment around matching TMPs.
    # s/^\$\$|([^\\])\$\$/{$1.&next_wrapper('tex2html_double_dollar')}/ge;
    # Wrap a dummy environment around matching $s.
    # s/^\$|([^\\])\$/{$1.&next_wrapper('$')}/ge;
    # s/tex2html_double_dollar/\$\$/go;
    # Do \(s and \[s
    #
    local($wrapper) = "tex2html_wrap_inline";	# \ensuremath wrapper
    print STDOUT "\n *** wrapping environments ***\n" if ($VERBOSITY > 3);

    # MRO: replaced $* with /m
    print STDOUT "\\(" if ($VERBOSITY > 3);
    s/(^\\[(])|([^\\])(\\[(])/{$2.&make_any_wrapper(1,'',$wrapper).$1.$3}/geom;
    print STDOUT "\\)" if ($VERBOSITY > 3);
    s/(^\\[)]|[^\\]\\[)])/{$1.&make_any_wrapper(0,'',$wrapper)}/geom;

    print STDOUT "\\[" if ($VERBOSITY > 3);
    s/(^\\[[])|([^\\])(\\[[])/{$2.&make_any_wrapper(1,1,"displaymath")}/geom;
    print STDOUT "\\]" if ($VERBOSITY > 3);
    s/(^\\[\]])|([^\\])(\\[\]])/{$2.&make_any_wrapper(0,1,"displaymath")}/geom;

    print STDOUT "\$" if ($VERBOSITY > 3);
    s/$enspair/print "\$";
       {&make_any_wrapper(1,'',$wrapper).$&.&make_any_wrapper(0,'',$wrapper)}/geom;

    $double_dol_rx = '(^|[^\\\\])\\$\\$';
    $single_dol_rx = '(^|[^\\\\])\\$';
    print STDOUT "\$" if ($VERBOSITY > 3);

    local($dollars_remain) = 0;
    $_ = &wrap_math_environment;
    $_ = &wrap_raw_arg_cmds;
}

sub wrap_math_environment {

    # This wraps math-type environments
    # The trick here is that the opening brace is the same as the close,
    # but they *can* still nest, in cases like this:
    #
    # $ outer stuff ... \hbox{ ... $ inner stuff $ ... } ... $
    #
    # Note that the inner pair of $'s is nested within a group.  So, to
    # handle these cases correctly, we need to make sure that the outer
    # brace-level is the same as the inner. --- rst
    #tex2html_wrap
    # And yet another problem:  there is a scungy local idiom to do
    # this:  $\_$ for a boldfaced underscore.  xmosaic can't display the
    # resulting itty-bitty bitmap, for some reason; even if it could, it
    # would probably come out as an overbar because of the floating-
    # baseline problem.  So, we have to special case this.  --- rst again.

    local ($processed_text, @processed_text, $before, $end_rx, $delim, $ifclosed);
    local ($underscore_match_rx) = "^\\s*\\\\\\_\\s*\\\$";
    local ($wrapper);
    print STDOUT "\nwrap math:" if ($VERBOSITY > 3);

    #find braced dollars, in tabular-specs
    while (/((($O|$OP)\d+($C|$CP))\s*)\$(\s*\2)/) {
        push (@processed_text, $`, $1.$dol_mark.$5);
        $_ = $';
    }
    $_ = join('',@processed_text, $_) if (@processed_text);
    undef @processed_text;

    $dollars_remain = 0;
    while (/$single_dol_rx/) {
	$processed_text .= $`.$1;
	$_ = $';
	$wrapper = "tex2html_wrap_inline";
	$end_rx = $single_dol_rx; # Default, unless we begin with $$.
	$delim = "\$";

        if (/^\$/ && (! $`)) {
	    s/^\$//;
	    $end_rx = $double_dol_rx;
	    $delim = "";	# Cannot say "\$\$" inside displaymath
	    $wrapper = "displaymath";

        } elsif (/$underscore_match_rx/ && (! $`)) {

            # Special case for $\_$ ...

            s/$underscore_match_rx//;
            $processed_text .= '\\_';
            next;
        }

        # Have an opening $ or $$.  Find matching close, at same bracket level
#	$processed_text .= &make_any_wrapper(1,'',$wrapper).$delim;

	print STDOUT "\$" if ($VERBOSITY > 3);
	$ifclosed = 0;
	local($thismath);
        while (/$end_rx/) {
	    # Forget the $$ if we are going to replace it with "displaymath"
            $before = $` . (($wrapper eq "displaymath")? "$1" : $&);
	    last if ($before =~ /\\(sub)*(item|section|chapter|part|paragraph)(star)?\b/);
	    $thismath .= $before;
            $_ = $';
	    s/^( [^\n])/\\space$1/s;  #make sure a trailing space doesn't get lost.

            # Found dollar sign inside open subgroup ... now see if it's
            # at the same brace-level ...

            local ($losing, $br_rx) = (0, '');
	    print STDOUT "\$" if ($VERBOSITY > 3);
            while ($before =~ /$begin_cmd_rx/) {
                $br_rx = &make_end_cmd_rx($1);  $before = $';

                if ($before =~ /$br_rx/) { $before = $'; }
                else { $losing = 1; last; }
            }
            do { $ifclosed = 1; last } unless $losing;

            # It wasn't ... find the matching close brace farther on; then
            # keep going.

            /$br_rx/;

            $thismath .= $`.$&;

	    #RRM: may now contain unprocessed $s e.g. $\mbox{...$...$...}$
	    # the &do_cmd_mbox uses this specially to force an image
	    # ...but there may be other situations; e.g. \hbox
	    # so set a flag:
	    $dollars_remain = 1;

            $_ = $';
        }

        # Got to the end.  Whew!
	if ($ifclosed) {
	    # also process any nested math
	    while (($dollars_remain)&&($delim eq "\$")) {
		local($saved) = $_;
                $thismath =~ s/\$$//;
                $_ = $thismath;
		$thismath =  &wrap_math_environment;
		$thismath .= "\$";
		$_ = $saved;
	    }
	    $processed_text .= &make_any_wrapper(1,'',$wrapper) . $delim 
		. $thismath . &make_any_wrapper(0,'',$wrapper);
	} else {
	    print STDERR "\n\n *** Error: unclosed math or extra `\$', before:\n$thismath\n\n";
#	    # remove a $ to try to recover as much as possible.
#	    $thismath =~ s/([^\\]\\\\|[^\\])\$/$1\%\%/;
#	    $_ = $thismath . $_; $thismath = "";
	print "\n$thismath\n\n\n$_\n\n\n"; die;
	    
	}
    }
    $processed_text . $_;
}

sub translate_environments {
    local ($_) = @_;
    local($tmp, $capenv);
#   print "\nTranslating environments ...";
    local($after, @processedE);
    local ($contents, $before, $br_id, $env, $pattern);
    for (;;) {
#	last unless (/$begin_env_rx/o);
	last unless (/$begin_env_rx|$begin_cmd_rx|\\(selectlanguage)/o);
#	local ($contents, $before, $br_id, $env, $pattern);
	local($this_env, $opt_arg, $style_info);
	$contents = '';
	# $1,$2 : optional argument/text --- stylesheet info
	# $3 : br_id (at the beginning of an environment name)
	# $4 : environment name
	# $5 : br_id of open-brace, when $3 == $4 == '';
	# $6 : \selectlanguage{...}
	if ($7) {
	    push(@processedE,$`);
	    $_ = $';
	    if (defined &do_cmd_selectlanguage) {
		$_ = &do_cmd_selectlanguage($_);
	    } else {
		local($cmd) = $7;
		$pattern = &missing_braces unless (
		    s/$next_pair_rx/$pattern = $2;''/e);
		local($trans) = $pattern.'_translation';
		if (defined &$trans) {
		    &set_default_language($pattern,$_);
		}
		undef $cmd; undef $trans;
	    }
	    next;
	} elsif ($4) {
	    ($before, $opt_arg, $style_info, $br_id
	         , $env, $after, $pattern) = ($`, $2, $3, $4, $5, $', $&);
	    if (($before)&& (!($before =~ /$begin_env_rx|$begin_cmd_rx/))) {
		push(@processedE,$before);
		$_ = $pattern . $after; $before = '';
	    }
	} else {
	    ($before, $br_id, $env, $after, $pattern) = ($`, $6, 'group', $', $&);
	    if (($before)&& (!($before =~ /$begin_env_rx|$begin_cmd_rx/))) {
		push(@processedE,$before);
		$_ = $pattern . $after; $before = '';
	    }
	    local($end_cmd_rx) = &make_end_cmd_rx($br_id);
	    if ($after =~ /$end_cmd_rx/) {
		# ... find the the matching closing one
		$NESTING_LEVEL++;
		($contents, $after) = ($`, $');
		$contents = &process_group_env($contents);
		print STDOUT "\nOUT: {$br_id} ".length($contents) if ($VERBOSITY > 3);
		print STDOUT "\n:$contents\n" if ($VERBOSITY > 7);
		# THIS MARKS THE OPEN-CLOSE DELIMITERS AS PROCESSED
		$_ = join("", $before,"$OP$br_id$CP", $contents,"$OP$br_id$CP", $after);
		$NESTING_LEVEL--;
	    } else {
		$pattern = &escape_rx_chars($pattern);
		s/$pattern//;
		print "\nCannot find matching bracket for $br_id";
		$_ = join("", $before,"$OP$br_id$CP", $after);
	    }
	    next;
	}
	$contents = undef;
	local($defenv) = $env =~ /deferred/;
#	local($color_env);
	local($color_env)
	    unless ($env =~ /tabular|longtable|in(line|display)|math/);
	local($closures,$reopens);
	local(@save_open_tags) = @$open_tags_R unless ($defenv);
	local($open_tags_R) = [ @save_open_tags ] unless ($defenv);
	local(@saved_tags) if ($env =~ /tabular|longtable/);
	if ($env =~ /tabular|longtable|makeimage|in(line|display)/) {
	    @save_open_tags = @$open_tags_R;
	    $open_tags_R = [ @save_open_tags ];
	    # check for color
	    local($color_test) = join(',',@$open_tags_R);
	    if ($color_test =~ /(color{[^}]*})/g ) {
		$color_env = $1;
	    } # else { $color_env = '' }

	    if ($env =~ /tabular|longtable|makeimage/) {
		# close to the surrounding block-type tag
		($closures,$reopens,@saved_tags) = &preserve_open_block_tags();
		@save_open_tags = @$open_tags_R;
		$open_tags_R = [ @save_open_tags ];
		if ($color_env) {
		    $color_test = join(',',@saved_tags);
		    if ($color_test =~ /(color{[^}]*})/g ) {
		        $color_env = $1;
		    }
		}
	    } elsif ($env =~ /in(line|display)/) {
		$closures = &close_all_tags() if ((&defined_env($env))
		    &&!($defenv)&&!($env=~/inline/)&&(!$declarations{$env}));
		if ($color_env) {
		    $color_test = $declarations{$color_env};
		    $color_test =~ s/<\/.*$//;
		    $closures .= "\n$color_test";
		    push (@$open_tags_R , $color_env);		
		}
	    }
	} elsif ($env =~ /alltt|tex2html_wrap/) {
	    # alltt is constructed as paragraphs, not with <PRE>
	    #  tex2html_wrap  creates an image, which is at text-level
	} else {
	    $closures = &close_all_tags() if ((&defined_env($env))
		&&!($defenv)&&(!$declarations{$env}) );
	}
	# Sets $contents and modifies $after
	if (&find_end_env($env,$contents,$after)) {
	    print STDOUT "\nIN-A {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    &process_command($counters_rx, $before)
		if ($before =~ /$counters_rx/);
	    # This may modify $before and $after
	    # Modifies $contents
#RRM: the do_env_... subroutines handle when to translate sub-environments
#	    $contents = &translate_environments($contents) if
##		((!$defenv) && (&defined_env($env)) && (! $raw_arg_cmds{$env})
##		&& (!$declarations{$env})
#		((&defined_env($env)) && (! $raw_arg_cmds{$env})
#		&& (!($env =~ /latexonly|enumerate|figure|table|makeimage|wrap_inline/))
#		&& ((! $NO_SIMPLE_MATH)||(!($env =~ /wrap/)))
#		&& (!($env =~ /(math|wrap|equation|eqnarray|makeimage|minipage|tabular)/) )
#		);
	    if ($opt_arg) { 
		&process_environment(1, $env, $br_id, $style_info); # alters $contents
	    } else {
		&process_environment(0, $env, $br_id, '');
	    }
	    undef $_;
	    print STDOUT "\nOUT-A {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    #JCL(jcl-env) - insert the $O$br_id$C stuff to handle environment grouping
	    if (!($contents eq '')) {
		$after =~ s/^\n//o if ($defenv);
		$this_env = join("", $before, $closures
			  , $contents
			  , ($defenv ? '': &balance_tags())
			  , $reopens ); $_ = $after;
	    } else { 
		$this_env = join("", $before , $closures
			  , ($defenv ? '': &balance_tags())
			  , $reopens ); $_ = $after;
	    };
	### Evan Welsh <welsh@epcc.ed.ac.uk> added the next 24 lines ##
	} elsif (&defined_env($env)) {
	    print STDOUT "\nIN-B {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    # If I specify a function for the environment then it
	    # calls it with the contents truncated at the next section.
	    # It assumes I know what I'm doing and doesn't give a
	    # deferred warning.
	    $contents = $after;
	    if ($opt_arg) { 
		$contents = &process_environment(1, $env, $br_id, $style_info);
	    } else {
		$contents = &process_environment(0, $env, $br_id, '');
	    }
	    print STDOUT "\nOUT-B {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    $this_env = join("", $before, $closures ,$contents, $reopens);

	    # there should not be anything left over 
#	    $_ = $after;
	    $_ = '';
	} elsif ($ignore{$env}) {
	    print STDOUT "\nIGNORED {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    # If I specify that the environment should be ignored then
	    # it is but I get a deferred warning.
	    $this_env = join("", $before , $closures , &balance_tags()
		      , $contents, $reopens );
	    $_ = $after;
	    &write_warnings("\n\\end{$env} not found (ignored).\n");
	} elsif ($raw_arg_cmds{$env}) {
	    print "\nIN-C {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    # If I specify that the environment should be passed to tex
	    # then it is with the environment truncated at the next
	    # section and I get a deferred warning.

	    $contents = $after;
	    if ($opt_arg) { 
		$contents = &process_environment(1, $env, $br_id, $style_info);
	    } else {
		$contents = &process_environment(0, $env, $br_id, '');
	    }
	    print STDOUT "\nOUT-C {$env $br_id}\n$contents\n" if ($VERBOSITY > 4);
	    $this_env = join("", $before, $closures
			     , $contents, &balance_tags(), $reopens );
	    $_='';
	    &write_warnings(
	        "\n\\end{$env $br_id} not found (truncated at next section boundary).\n");
	} else {
	    $pattern = &escape_rx_chars($pattern);
	    s/$pattern/$closures/;
	    print "\nCannot find \\end{$env $br_id}\n";
	    $_ .= join('', &balance_tags(), $reopens) unless ($defenv);
	}
	if ($this_env =~ /$begin_env_rx|$begin_cmd_rx/) {
	    $_ = $this_env . $_;
	} else { push (@processedE, $this_env) }
    }
    $_ = join('',@processedE) . $_;
    $tmp = $_; undef $_;
    &process_command($counters_rx, $tmp) if ($tmp =~ /$counters_rx/);
    $_ = $tmp; undef $tmp;
    $_
}

sub find_end_env {
    # MRO: find_end_env($env,$contents,$rest)
    #local ($env, *ref_contents, *rest) = @_;
    my $env = $_[0];
    my $be_rx = &make_begin_end_env_rx($env);
    my $count = 1;

    while ($_[2] =~ /($be_rx)(\n?)/s) { # $rest
	$_[1] .= $`; # $contents

	if ($2 eq "begin") { ++$count }
	else { --$count };

	#include any final \n at an {end} only
	$_[2] = (($2 eq 'end')? $5 : '') . $'; # $rest
	last if $count == 0;

	$_[1] .= $1; # $contents
    }

    if ($count != 0) {
	$_[2] = join('', $_[1], $_[2]); # $rest = join('', $contents, $rest);
	$_[1] = ''; # $contents
	return(0)
    } else { return(1) }
}


sub process_group_env {
    local($contents) = @_;
    local(@save_open_tags) = @$open_tags_R;
    local($open_tags_R) = [ @save_open_tags ];
    print STDOUT "\nIN::{group $br_id}" if ($VERBOSITY > 4);
    print STDOUT "\n:$contents\n" if ($VERBOSITY > 6);

    # need to catch explicit local font-changes
    local(%font_size) = %font_size if (/\\font\b/);

    # record class/id info for a style-sheet entry
    local($env_id, $tmp, $etmp);
    if (($USING_STYLES) && !$PREAMBLE ) { $env_id = $br_id; }
#	$env_id = "grp$br_id";
#	$styleID{$env_id} = " ";
#        $env_id = " ID=\"$env_id\"";
#    }

    undef $_;
    $contents =~ s/^\s*$par_rx\s*//s; # don't start with a \par 
    if ($contents =~ /^\s*\\($image_switch_rx)\b\s*/s) {
	# catch TeX-like environments: {\fontcmd ... }
	local($image_style) = $1;
	if ($USING_STYLES) {
	    $env_style{$image_style} = " " unless ($env_style{$image_style});
	}
	local($switch_cmd) = "do_cmd_${image_style}";
	if (defined &$switch_cmd ) {
	    eval "\$contents = \&${switch_cmd}(\$')";
	    print "\n*** &$switch_cmd didn't work: $@\n$contents\n\n" if ($@);
	} elsif ($contents =~ /$par_rx/) {
	    # split into separate image for each paragraph
	    local($par_style,$this_par_img) = '';
	    local(@par_pieces) = split($par_rx, $contents);
	    local($this_par,$par_style,$par_comment);
	    $contents = '';
	    while (@par_pieces) {
		$this_par = shift @par_pieces;
		if ($this_par =~ /^\s*\\($image_switch_rx)\b/s) {
		    $image_style = $1;
		    $par_style = 'P.'.$1;
		    $env_style{$par_style} = " " unless ($env_style{$par_style});
		}
#	no comment: source is usually too highly encoded to be meaningful
#	$par_comment = &make_comment($image_style,$this_par);
		$this_par_img = &process_in_latex("\{".$this_par."\}");
		$contents .=  join(''  #,"\n", $par_comment
			, "\n<P"
			, (($USING_STYLES && $image_style)? " CLASS=\"$image_style\"" :'')
			,">", $this_par_img
			, "</P>\n");
		if (@par_pieces) {
		    # discard the pieces from matching  $par_rx
		    $dum = shift @par_pieces;
		    $dum = shift @par_pieces;
		    $dum = shift @par_pieces;
		    $dum = shift @par_pieces;
		    $dum = shift @par_pieces;
		    $dum = shift @par_pieces;
#		    $contents .= "\n</P>\n<P>";
		}
	    }
	} else {
	    $contents = &process_undefined_environment("tex2html_accent_inline"
		, ++$global{'max_id'},"\{".$contents."\}");
        }
    } elsif ($contents =~ /^\s*\\(html)?url\b($O\d+$C)[^<]*\2\s*/) {
	# do nothing
	$contents = &translate_environments($contents);
	$contents = &translate_commands($contents);
    } elsif (($env_switch_rx)&&($contents =~ s/^(\s*)\\($env_switch_rx)\b//s)) {
	# write directly into images.tex, protected by \begingroup...\endgroup
	local($prespace, $cmd, $tmp) = ($1,$2,"do_cmd_$2");
	$latex_body .= "\n\\begingroup ";
	if (defined &$tmp) {
	    eval("\$contents = &do_cmd_$cmd(\$contents)");
	}
	$contents = &translate_environments($contents);
	$contents = &translate_commands($contents);
	undef $tmp; undef $cmd;
	$contents .= "\n\\endgroup ";
    } elsif ($contents =~ /^\s*\\([a-zA-Z]+)\b/s) { 
	local($after_cmd) = $';
	local($cmd) = $1; $tmp = "do_cmd_$cmd"; $etmp = "do_env_$cmd";
	if (($cmd =~/^(rm(family)?|normalsize)$/)
		||($declarations{$cmd}&&(defined &$tmp))) {
	    do{
		local(@save_open_tags) = @$open_tags_R;
		eval "\$contents = \&$tmp(\$after_cmd);";
		print "\n*** eval &$tmp failed: $@\n$contents\n\n" if ($@);
		$contents .= &balance_tags();
	    };
	} elsif ($declarations{$cmd}&&(defined &$etmp)) {
	    eval "\$contents = \&$etmp(\$after_cmd);";
	} else {
	    $contents = &translate_environments($contents);
	    $contents = &translate_commands($contents)
		if ($contents =~ /$match_br_rx/o);
	    # Modifies $contents
	    &process_command($single_cmd_rx,$contents) if ($contents =~ /\\/o);
	}
	undef $cmd; undef $tmp; undef $etmp;
    } else { 
	$contents = &translate_environments($contents);
	$contents = &translate_commands($contents)
	    if ($contents =~ /$match_br_rx/o);
        # Modifies $contents
	&process_command($single_cmd_rx,$contents)
	    if ($contents =~ /\\/o);
    }
    $contents . &balance_tags();
}

# MODIFIES $contents
sub process_environment {
    local($opt, $env, $id, $styles) = @_;

    local($envS) = $env; $envS =~ s/\*\s*$/star/;
    local($env_sub,$border,$attribs,$env_id) = ("do_env_$envS",'','','');
    local($original) = $contents;

    if ($env =~ /tex2html_deferred/ ) {
	$contents = &do_env_tex2html_deferred($contents);
	return ($contents);
    }
    $env_id = &read_style_info($opt, $env, $id, $styles) 
	if (($USING_STYLES)&&($opt));

    if (&defined_env($env)) {
	print STDOUT ",";
	print STDOUT "{$env $id}" if ($VERBOSITY > 1);
#	$env_sub =~ s/\*$/star/;
	$contents = &$env_sub($contents);

    } elsif ($env =~ /tex2html_nowrap/) {
	#pass it on directly for LaTeX, via images.tex
	$contents = &process_undefined_environment($env, $id, $contents);
	return ($contents);

#    elsif (&special_env) {	# &special_env modifies $contents
    } else {
	local($no_special_chars) = 0;
	local($failed) = 0;
	local($has_special_chars) = 0;
	&special_env; #  modifies $contents
	print STDOUT "\n<MATH $env$id $contents>" if ($VERBOSITY > 3);
	if ($failed || $has_special_chars) {
	    $contents = $original;
	    $failed = 1;
	    print STDOUT " !failed!\n" if ($VERBOSITY > 3);
        }
    }
    if (($contents) && ($contents eq $original)) {
        if ($ignore{$env}) {  return(''); }
        # Generate picture
	if ($contents =~ s/$htmlborder_rx//o) {
	    $attribs = $2; $border = (($4)? "$4" : 1)
	} elsif ($contents =~ s/$htmlborder_pr_rx//o) { 
	    $attribs = $2; $border = (($4)? "$4" : 1)
	}
	$contents = &process_undefined_environment($env, $id, $contents);
	$env_sub = "post_latex_$env_sub"; # i.e. post_latex_do_env_ENV
        if ( defined &$env_sub) {
	    $contents = &$env_sub($contents);
	} elsif (($border||($attributes))&&($HTML_VERSION > 2.1)) {
	    $contents = &make_table($border,$attribs,'','','',$contents);
	} else {
	    $contents = join('',"<BR>\n",$contents,"\n<BR>")
	        unless (!($contents)||($inner_math)||($env =~
	              /^(tex2html_wrap|tex2html_nowrap|\w*math|eq\w*n)/o ));
	}
    }
    $contents;
}


#RRM: This reads the style information contained in the optional argument
#   to the \begin command. It is stored to be recovered later as an entry
#   within the automatically-generated style-sheet, if $USING_STYLES is set.
# Syntax for this info is:
#   <style names> ; <extra style-info> 

sub read_style_info {
    local($opt, $envS, $id, $styles) = @_;
    return() unless (($opt)&&($USING_STYLES));
    # allow macro-expansion within the style-info
    $opt = &translate_commands($opt) if ($opt =~ /\\/);

    # record class/id info for a style-sheet entry
    local($style_names, $style_extra, $env_id)=(''," ",'');
    if ($opt) {
	# if there is a `;'  then <names> ; <extra>
	if ($styles =~ /^\s*([^\|]*)\|\s*(.*)$/) {
	    $style_names = $1; $style_extra = $2;
	    if ($style_names =~ /[=:;]/) {
		# cannot be <names>, so is <extra>
		$style_extra = $style_names.$style_extra;
		$style_names = '';
	    }
	} elsif ($styles =~ /[\=\:]/) {
	    # cannot be <names>, so is <extras>
	    $style_extra = $styles;
	} else { $style_names = $styles }
	$style_extra =~ s/\s*[=:]\s*/ : /go;
	$style_extra =~ s/([\w,\-]+)\s+([\w,\-]+)/$1 ; $2/go;
	$style_extra =~ s/\s*,\s*/ /go;

	if ($style_names) {
	    local($sname);
	    local(@names) = split ( /\s+/ , $style_names );
	    # ensure a style-sheet entry for each new name
	    foreach $sname (@names) {
		$env_style{$sname} = " "
		    unless (($env_style{$sname})||($sname =~ /^\s*$/));		
	    }
	}
    }
    # remove uninformative part of internally-defined env names
    $envS =~ s/tex2html_(\w+_)?(\w+)/$2/; $envS =~ s/preform/pre/;
    $env_id = $envS.$id;
    $styleID{$env_id} = $style_extra unless ($PREAMBLE);
    
    if ($style_names) { $envS = "$style_names" }
    elsif (($envS =~ /^pre$/)&&
	(/^\\begin.*preform($O|$OP)\d+($C|$CP)$verbatim_mark(\w*[vV]erbatim)(\*?)/))
	    { $envS = $3.($4 ? 'star' : '') };
    $env_style{$envS} = " " unless (($style_names)||($env_style{$envS}));
    $env_id = " ID=\"$env_id\"".(($envS) ? " CLASS=\"$envS\"" : '');
    return($env_id);
}

# RRM: This provides the mechanism to save style information in %env_style
#      using LaTeX macros  \htmlsetstyle  and  \htmladdtostyle
#
sub process_htmlstyles {
    local($mode, $_) = @_;
    local($pre_tags) = &get_next_optional_argument;
    local($class) = &missing_braces unless (
        (s/$next_pair_pr_rx/$class = $2;''/e)
        ||(s/$next_pair_rx/$class = $2;''/e));
    local($sinfo) = &missing_braces unless (
        (s/$next_pair_pr_rx/$sinfo = $2;''/e)
        ||(s/$next_pair_rx/$sinfo = $2;''/e));
    return ($_) unless ($class||$pre_tags);

    $class = $pre_tags.($class ?'.':'').$class;
    $sinfo =~ s/\s*[:=]\s*/ : /g;
    $sinfo =~ s/\s*,\s*/ /g;
    if ($mode =~ /add/) {
    	$sinfo = '; '.$sinfo if ($env_style{$class}); 
	$env_style{$class} .= $sinfo;
    } else { $env_style{$class} = $sinfo }
    $_;
}
sub do_cmd_htmlsetstyle   { &process_htmlstyles('set',@_) }
sub do_cmd_htmladdtostyle { &process_htmlstyles('add',@_) }


# The $<$, $>$, $|$ and $=>$, etc strings are replaced with their textual
# equivalents instead of passing them on to latex for processing in math-mode.
# This will not be necessary when the mechanism for passing environments
# to Latex is improved.
# RETURNS SUCCESS OR FAILURE
sub special_env {
    # Modifies $contents in its caller
    local($next)='';
    local ($allow) = $HTML_VERSION ge '3.0' ?
	 "[^#\$%&~\\\\{}]|\\limits" : "[^^#\$%&~_\\\\{}]";
    #JKR: Use italics instead of bold #HWS: Generalize to include more symbols.
#    $contents =~ s/^\$(\s*($html_specials_inv_rx|$allow)*\s*)\$(.)?/
#	$next=$3;&simple_math_env($1).(($next =~ m|\w|)? " ":'').$next/ige;
    $contents =~ s/^\$(\s*($html_specials_inv_rx|$allow)*\s*)\$$/
	&simple_math_env($1)." "/ige;
    if ($contents =~ /\&\w*;/) { $has_math_chars=1 }
    if ($contents =~ /;SPM([a-zA-Z]+);/) { $has_special_chars=1 };
}

# Translate simple math environments into italic.
# Only letters should become italic; symbols should stay non-italic.
sub simple_math_env {
    local($mathcontents) = @_;
    if ($mathcontents eq '') { return("$mathcontents"); }
    elsif ($NO_SIMPLE_MATH) {  # always make an image
	$failed = 1; return($mathcontents);
    } elsif ($mathcontents =~ /\\/) { # any macro kills "simple-math"
	local($save_math) = $mathcontents;
	local(@text_only) = ();
	while ((!$failed)&&($mathcontents =~
		/\\((boldsymbol|bm)|(math|text)(bf|rm|it|tt)|times|[{}@#^_])(\b|[^A-Za-z]|$)/)) {
	    # ...except when only simple styles
	    push (@text_only, $`, ("$2$4" ? "\\simplemath".($4 ? $4 :"bf") :"\\$1") );
	    $mathcontents = $5.$';
	    $failed = 1 if ($` =~ /\\/);
	}
	$failed = 1 if ($mathcontents =~ /\\/);
	return($save_math) if $failed;
	$mathcontents = join('',@text_only,$mathcontents);
    }
    # Is there a problem here, with nested super/subscripts ?
    # Yes, so do each pattern-match for bracketings within a while-loop
    while ($mathcontents =~ s/\^$any_next_pair_rx/<SUP>$2<\/SUP>/go){};
    while ($mathcontents =~ s/\^$any_next_pair_pr_rx/<SUP>$2<\/SUP>/go){};
    while ($mathcontents =~ s/_$any_next_pair_rx/<SUB>$2<\/SUB>/g){};
    while ($mathcontents =~ s/_$any_next_pair_pr_rx/<SUB>$2<\/SUB>/g){};

    $mathcontents =~ s/\^(\\[a-zA-Z]+|.)/<SUP>$1<\/SUP>/g;
    $mathcontents =~ s/_(\\[a-zA-Z]+|.)/<SUB>$1<\/SUB>/g;
    $mathcontents =~ s/(^|\s|[,;:'\?\.\[\]\(\)\+\-\=\!>]|[^\\<]\/|\d)(<(I|TT|B)>)?([a-zA-Z]([a-zA-Z ]*[a-zA-Z])?)(<\/\3>)?/
	$1.(($2)? $2 :'<I>').$4.(($6)? $6 : '<\/I>')/eig;

    $mathcontents =~ s/\\times($|\b|[^A-Za-z])/ x $1/g;
    $mathcontents =~ s/\\times($|\b|[^A-Za-z])/ x $1/g;
    $mathcontents =~ s/\\\\/<BR>\n/g;
    $mathcontents =~ s/\\\\/<BR>\n/g;
    $mathcontents =~ s/\\([,;])/ /g;
    $mathcontents =~ s/\\(\W)/$1/g;
    $mathcontents =~ s/ {2,}/ /g;

    # any simple style changes remove enclosed <I> tags
    $mathcontents = &translate_commands($mathcontents)
	if ($mathcontents =~ /\\/);

    $mathcontents =~ s/<I><\/(SUB|SUP)>/<\/$1><I>/g;
    $mathcontents =~ s/<(SUB|SUP)><\/I>/<\/I><$1>/g;
    $mathcontents =~ s/;<I>SPM([a-zA-Z]+)<\/I>;/;SPM$1;/go;
    $mathcontents =~ s/<(\/?)<I>(SUB|SUP|I|B|TT)<\/I>>/<$1$2>/g;
    $mathcontents =~ s/<\/(B|I|TT)><\1>//g;
    $mathcontents;
}

sub do_cmd_simplemathrm { 
    local ($_) = @_;
    local($text);
    $text = &missing_braces unless (
        (s/$next_pair_pr_rx/$text = $2;''/e)
        ||(s/$next_pair_rx/$text = $2;''/e));
    $text =~ s/<\/?I>//g;
    join('', $text, $_)
}
sub do_cmd_simplemathbf { 
    local ($_) = @_;
    local($text);
    $text = &missing_braces unless (
        (s/$next_pair_pr_rx/$text = $2;''/e)
        ||(s/$next_pair_rx/$text = $2;''/e));
    $text =~ s/<\/?I>//g;
    join('','<B>', $text, '</B>', $_)
}
sub do_cmd_simplemathtt {
    local ($_) = @_;
    local($text);
    $text = &missing_braces unless (
        (s/$next_pair_pr_rx/$text = $2;''/e)
        ||(s/$next_pair_rx/$text = $2;''/e));
    $text =~ s/<\/?I>//g;
    join('','<TT>', $text, '</TT>', $_)
}

sub process_math_in_latex {
    local($mode,$style,$level,$math) = @_;
    local(@anchors);
    if ($level) {
	$style = (($level > 1) ? "script" : "") . "script";
    } elsif (! $style) { 
	$style = (($mode =~/display|equation/)? "display" : "")
    }
    $style = "\\${style}style" if ($style);

    #  &process_undefined_environment  changes $_ , so save it.
    local($after) = $_;

    # the 'unless' catches nested AMS-aligned environments
    $mode = "tex2html_wrap_" .
	(($mode =~/display|equation|eqnarray/) ? 'indisplay' : 'inline')
	    unless ($mode =~ /^equationstar/ && $outer_math =~ /^equationstar/);

    $global{'max_id'}++;
    $math =~ s/\\(\n|$)/\\ $1/g;	# catch \ at end of line or string
    $math =~ s/^\s*((\\!|;SPMnegsp;)\s*)*//g;		# remove neg-space at start of string
    if ($mode =~ /tex2html_wrap_/ ) {
	$math = &process_undefined_environment( $mode
	    , $global{'max_id'}, join('', "\$$style ", $math, "\$"));
    } else {
	# some AMS environments must be within {equation} not {displaymath}
	$math =~ s/displaymath/equation*/
		if ($math =~ /\\begin\{(x+|fl)*align/);
	$math = &process_undefined_environment($mode, $global{'max_id'}, $math);
    }
    $math .= "\n" if ($math =~ /$comment_mark\s*\d+$/s);
    $_ = $after;
    # the delimiter \001 inhibits an unwanted \n at image-replacement
    $math . ($math =~ /$image_mark/? "\001" : '');
}
     
#RRM: Explicit font switches need images. Use the image_switch mechanism.
sub do_cmd_font {
    local($_) = @_;
    local($fontinfo,$fontname,$size) = ('','','10pt');
    s/\s*\\(\w+)\s*=?\s*(.*)(\n|$)/$fontname=$1;$fontinfo=$2;''/eo;
    $image_switch_rx .= "|$fontname";

    if ($fontinfo =~ /([.\d]+\s*(true)?(pt|mm|cm))/ ) { $size = $1 }
    elsif ( $fontinfo =~ /[a-zA-Z]+(\d+)\b/ ) { $size = $1.'pt' }
    if  ( $fontinfo =~ /(scaled|at)\s*\\?(.+)/) { $size .= " scaled $1" }
    $font_size{$fontname} = $size;
    $_;
}
sub wrap_cmd_font {
    local($cmd, $_) = @_;
    local ($args, $dummy, $pat) = "";
    if (/\n/) { $args .= $`.$& ; $_ = $' } else {$args = $_; $_ = ''};
    (&make_deferred_wrapper(1).$cmd.$padding.$args.&make_deferred_wrapper(0),$_)
}

sub do_cmd_newfont {
    local($_) = @_;
    local($fontinfo,$fontname,$size) = ('','','10pt');
    $fontname = &missing_braces unless (
	(s/$next_pair_pr_rx/$fontname=$2;''/eo)
	||(s/$next_pair_rx/$fontname=$2;''/eo));
    $fontname=~ s/^\s*\\|\s*$//g;
    $image_switch_rx .= "|$fontname";

    $fontinfo = &missing_braces unless (
	(s/$next_pair_pr_rx/$fontinfo=$2;''/eo)
	||(s/$next_pair_rx/$fontinfo=$2;''/eo));
    if ($fontinfo =~ /([.\d]+\s*(true)?(pt|mm|cm))/ ) { $size = $1 }
    elsif ( $fontinfo =~ /[a-zA-Z]+(\d+)\b/ ) { $size = $1.'pt' }
    if  ( $fontinfo =~ /(scaled|at)\s*\\?(.+)/) { $size .= " scaled $1" }
    $font_size{$fontname} = $size;
    $_;
}

sub defined_env {
    local($env) = @_;
    $env =~ s/\*$/star/;
    local($env_sub) = ("do_env_$env");
    # The test using declarations should not be necessary but 'defined'
    # doesn't seem to recognise subroutines generated dynamically using 'eval'.
    # Remember that each entry in $declarations generates a dynamic prodedure ...
    ((defined &$env_sub) || ($declarations{$env}));
}

# RRM: utility to add style information to stored image-parameters
#      currently only (math) scaling info is included;
#      current color, etc.  could also be added here.
sub addto_encoding {
    local($env, $contents) = @_;
#    $contents =~ s/(\\(begin|end)\s*)?<<\d*>>|\n//g;	# RRM: remove env delimiters
    $contents =~ s/(\\(begin|end)\s*(<<\d*>>))|\n//g;	# RRM: remove env delimiters
    # append scaling information for environments using it
    if (($MATH_SCALE_FACTOR)
	&&(($contents =~ /makeimage|inline|indisplay|entity|displaymath|eqnarray|equation|xy|diagram/)
	   ||($env =~ /makeimage|inline|indisplay|entity|displaymath|eqnarray|equation|xy|diagram/))
	) { $contents .= ";MSF=$MATH_SCALE_FACTOR" }

    if ($LATEX_FONT_SIZE =~ /([\d\.]+)pt/) {
	local($fsize) = $1;
	$contents .= ";LFS=$fsize" unless ($fsize ==10);
    }

    if (($EXTRA_IMAGE_SCALE)
	&&(($contents =~ /makeimage|inline|indisplay|entity|displaymath|eqnarray|equation|xy|diagram/)
	   ||($env =~ /makeimage|inline|indisplay|entity|displaymath|eqnarray|equation|xy|diagram/))
	) { $contents .= ";EIS=$EXTRA_IMAGE_SCALE" }

    if (($DISP_SCALE_FACTOR)
	&&(($contents =~ /indisplay|displaymath|eqnarray|equation/)
	   ||($env =~ /indisplay|displaymath|eqnarray|equation/))
	&&!(($contents =~ /makeimage/)||($env =~ /makeimage/))
	) { $contents .= ";DSF=$DISP_SCALE_FACTOR" }

    if (($EQN_TAGS)
	&&(($env =~ /eqnarray($|[^_\*])|equation/)
	   ||($contents =~ /eqnarray($|[^_\*])|equation/))
	&&!(($contents =~ /makeimage/)||($env =~ /makeimage/))
	) { $contents .= ";TAGS=$EQN_TAGS" }

    if (($FIGURE_SCALE_FACTOR)
	&&!(($contents =~ /makeimage/)||($env =~ /makeimage/))
	&&(($contents =~ /figure/)||($env =~ /figure/))
	) { $contents .= ";FSF=$FIGURE_SCALE_FACTOR"}

    if (($ANTI_ALIAS)
	&&(($contents =~ /figure/)||($env =~ /figure/))
	&&!(($contents =~ /makeimage/)||($env =~ /makeimage/))
	) { $contents .= ";AAF" }
    elsif ($ANTI_ALIAS_TEXT) { $contents .= ";AAT" }
    if (!$TRANSPARENT_FIGURES) { $contents .= ";NTR" }

    $contents;
}

sub process_undefined_environment {
    local($env, $id, $contents) = @_;
    if ($env =~ s/\*{2,}/*/) { print "\n*** $_[0] has too many \*s ***"};

    local($name,$cached,$raw_contents,$uucontents) = ("$env$id");
    $name =~ s/\*/star/;
    local($oldimg,$size,$fullcontents,$imgID);
    return if ($AUX_FILE);

    # catch \footnotemark within an image, especially if in math
    local(@foot_anchors,$foot_anchor);
    local($im_footnote,$im_mpfootnote) = ($global{'footnote'},$global{'mpfootnote'});
    @foot_anchors = &process_image_footnote($contents)
	if ($contents =~ /\\footnote(mark)?\b/s);
    if ((@foot_anchors)&&($eqno)) {
	# append the markers to the equation-numbers
	$eqno .= join(' ', ' ', @foot_anchors);
	@foot_anchors = ();
    }
    
    print STDOUT "\nUNDEF-IN {$env $id}:\n$contents\n" if ($VERBOSITY > 4);
    #RRM - LaTeX commands wrapped with this environment go directly into images.tex.
    if ($env =~ /tex2html_nowrap|^lrbox$/){ # leave off the wrapper, do not cache
	# totally ignore if in preamble...
	# ...since it will be put into  images.tex  anyway!!
	if (!($PREAMBLE)) {
	    $contents =~ s/^\n+|\n+$/\n/g;
	    local($lcontents) = join('', "\\begin{$env}", $contents , "\\end{$env}" );
	    $lcontents =~ s/\\(index|label)\s*(($O|$OP)\d+($C|$CP)).*\2//sg;
	    print STDOUT "pre-LATEX {$env}:\n$lcontents\n" if ($VERBOSITY > 3);
	    $raw_contents = &revert_to_raw_tex($lcontents);
	    print STDOUT "LATEX {$env}:\n$raw_contents\n" if ($VERBOSITY > 3);
	    $latex_body .= "\n$raw_contents"."%\n\n" ;
	}
	return("") if ($env =~ /^lrbox/);
	# ignore enclosed environments; e.g. in  \settolength  commands
#	$contents = &translate_environments($contents); # ignore environments
#	$contents = &translate_commands($contents);
	# ...but apply any Perl settings that may be defined
	$contents = &process_command($single_cmd_rx,$contents);
	print STDOUT "\nOUT {$env $id}:\n$contents\n" if ($VERBOSITY > 4);
	return("");
    }
    # catch pre-processor environments
    if ($PREPROCESS_IMAGES) {
	local($pre_env,$which, $done, $indic);
	while ($contents =~ /$pre_processor_env_rx/) {
	    $done .= $`; $pre_env = $5; $which =$1; $contents = $';
	    if (($which =~ /begin/)&&($pre_env =~ /indica/)) {
		if ($contents =~ s/^\[(\w+)]//o) { $done .= '#'.$1 }
	    } elsif (($which =~ /end/)&&($pre_env =~ /indica/)) {
		$done .= '#NIL';
	    } elsif (($which =~ /begin/)&&($pre_env =~ /itrans/)) {
		if ($contents =~ s/^\[(\w+)]/$indic=$1;''/e)
	            { $done .= "\#$indic" }
	    } elsif (($which =~ /end/)&&($pre_env =~ /itrans/)) {
		$done .= "\#end$indic";
	    } elsif ($which =~ /begin/) {
		$done .= (($which =~ /end/)? $end_preprocessor{$pre_env}
		          : $begin_preprocessor{$pre_env} )
	    }
	}
	$contents = $done . $contents;
    }
    $fullcontents =  $contents; # save for later \label search.
    # MRO: replaced $* with /m
    $contents =~ s/\n?$labels_rx(\%([^\n]+$|$EOL))?/\n/gm;

    local($tmp) = $contents;
    $tmp =~ s/^((\\par|\%)?\s*\n)+$//g;
    return( &do_labels($fullcontents, "\&nbsp;") ) unless $tmp;

    # just a comment as the contents of a cell in a math-display
    if ($tmp =~ /\$\\(display|text|(script)+)style\s*$comment_mark\d+\s*\$$/)
	{ return ( &do_labels($fullcontents, "\&nbsp;") ) };

    $contents = "\n% latex2html id marker $id\n$contents" if
	(!$PREAMBLE &&($contents =~ /$order_sensitive_rx/)
		&&(!($env =~ /makeimage/)));

    $env =~ s/displaymath/equation*/
	if ($contents =~ /\\begin\{(x+|fl)*align/);
    #RRM: include the inline-color, when applicable
    $contents = join(''
	    , (($inner_math =~ /in(display|line)/) ? '$' : '')
	    , "\\begin{$env}"
	    , ($color_env ? "\\bgroup\\$color_env" : '')
	    , $contents , ($color_env ? "\\egroup" : '')
	    , "\\end{$env}"
	    , (($inner_math =~ /in(display|line)/) ? '$' : '')
	) if ($contents);

    # append to the name of special environments found within math
    if ($inner_math) {
	local($ext) = $inner_math;
	if ($inner_math =~ /(display|line)/){ $ext = 'in'.$1;};
	$name =~ s/(\d+)$/_$ext$1/;
    }

    if (!($latex_body{$name} = $contents)) {
	print "\n *** code for $name is too long ***\n"}
    if ($contents =~ /$htmlimage_rx/) {
	$uucontents = &special_encoding($env,$2,$contents);
    } elsif ($contents =~ /$htmlimage_pr_rx/) {
	$uucontents = &special_encoding($env,$2,$contents);
    } else {
	$uucontents = &encode(&addto_encoding($env,$contents));
    }
    $cached = $cached_env_img{$uucontents};
    print STDOUT "\nCACHED: $uucontents:\n$cached\n" if ($VERBOSITY > 4);
    if ($NOLATEX) { 
	$id_map{$name} = "[$name]";
    } elsif (defined ($_ = $cached)) { # Is it in our cache?
	# Have we already used it?
	if (($oldimg) = /SRC="$PREFIX$img_rx\.$IMAGE_TYPE"/o) {
	    # No, check its size
	    local($eis) = 1;
	    # Does it have extra scaling ?
	    if ($uucontents =~ /EIS=(.*);/) { $eis = $1 }
	    ($size, $imgID) = &get_image_size("$PREFIX$oldimg.old", $eis);	
	    # Does it have extra scaling ?
#	    if ($uucontents =~ /EIS=(.*);/) {
#		local($eis) = $1; local($w,$h);
#		# quotes will not be there with HTML 2.0
#		$size =~ s/(WIDTH=\")(\d*)(\".*HEIGHT=\")(\d*)\"/
#		    $w = int($2\/$eis + .5); $h=int($4\/$eis + .5);
#		    "$1$w$3$h\""/e ; # insert the re-scaled size
#	    }
	    # quotes will not be there with HTML 2.0
	    $size =~ s/\"//g if ($HTML_VERSION < 2.2);
	    if ($size && /\s$size\s/) {
		# Size is OK; recycle it!
		++$global_page_num;
		$_ = $cached ;    # ...perhaps restoring the desired size.
		s/(${PREFIX}T?img)\d+\.($IMAGE_TYPE|html)/
			&rename_html($&,"$1$global_page_num.$2")/geo;
	    } else {
		if ($env =~ /equation/) { &extract_eqno($name,$cached) }
		$_ = "";				# The old Image has wrong size!
		undef($cached);			#  (or it doesn't exist)
	    }
	}
	s/(IMG\n)/$1$imgID/ if $imgID;

	s/$PREFIX$img_rx\.new/$PREFIX$1.$IMAGE_TYPE/go; # Point to the actual image file(s)
	$id_map{$name} = $_;
	s/$PREFIX$img_rx\.$IMAGE_TYPE/$PREFIX$1.new/go;	# But remember them as used.
	$cached_env_img{$uucontents} = $_;
    }

    if (! defined($cached)) {				# Must generate it anew.
	&clear_images_dbm_database
	    unless ($new_page_num ||($NO_SUBDIR && $FIXEDDIR));
	$new_id_map{$name} = $id_map{$name} = ++$global_page_num . "#" .
	    ++$new_page_num;
	$orig_name_map{$id_map{$name}} = $name;
	$cached_env_img{$uucontents} = $id_map{$name} if ($REUSE == 2);

	#RRM: this (old) code frequently crashes NDBM, so do it in 2 steps
#	$img_params{$name} = join('#', &extract_parameters($contents));

#<bo>
#print "Before extract params; $contents\n";
#</bo>
	local(@params) = &extract_parameters($contents);
	$img_params{$name} = join('#',@params); undef $params;
	print "\nIMAGE_PARAMS $name: ".$img_params{$name} if ($VERBOSITY > 3);

	$contents =~ s/\\(index|label)\s*(($O|$OP)\d+($C|$CP)).*\2//sg;
	print STDOUT "\nLATEX {$env}:\n$contents" if ($VERBOSITY > 3);
	$raw_contents = &revert_to_raw_tex($contents) unless ($contents =~ /^\s*$/) ;
	$raw_contents =~ s/\\pagebreak|\\newpage|\\clearpage/\\\\/go;
	print STDOUT "\nLATEX {$env}:\n$raw_contents\n" if ($VERBOSITY > 3);
	local($box_type) = '';
	if ($raw_contents =~ /\\special\s*\{/) { 
	    $tex_specials{$name} = "1";
	    &write_warnings("\nenvironment $name contains \\special commands");
	    print STDOUT "\n *** environment $name contains \\special commands ***\n"
		if ($VERBOSITY);
	} elsif (($env =~ /$inline_env_rx/)||($inner_math =~ /in(line|display)/)) {
	    # crop to the marks only... or shave a bit off the bottom
	    if (($env =~ /tex2html_[^w]/)||$inner_math) {
		# e.g. accents, indic  but not wrap
		$crop{$name} = "bl";
		$box_type = "i";		
	    } else {
	    # ...or shave a bit off the bottom as well
		$crop{$name} = "bls";
		$box_type = "h";
	    }
	} elsif (($env =~ /(eqnarray|equation)(\*|star)/)||($inner_math)) {
	    # crop to minimum size...
	    $crop{$name} = "blrl";
	    $box_type = "v";
	} elsif ($env =~ /(picture|tex2html_wrap)(\*|star)?/) {
	    # crop hbox to minimum size...
	    $crop{$name} = "";
	    $box_type = "p";
	} elsif ($env =~ /$display_env_rx/) {
	    # crop vbox to minimum size...
	    $crop{$name} = "blrl" ;
	    if ($env =~ /(equation|eqnarray)((s)?$|\d)/) {
		# ... unless equation numbers are included ...
		if ($3) { #  AMS {subequations}
		    $global{'eqn_number'}=$prev_eqn_number if $prev_eqn_number;
		    --$global{'eqn_number'};
		}
		$raw_contents = join('' ,
		    (($eqno{$name}||$global{'eqn_number'})?
		      &set_equation_counter($eqno{$name}) : '')
		    , $raw_contents);
		$crop{$name} = "bl" ;
	    } elsif ($HTML_VERSION < 2.2) {
		# ... HTML 2.0 cannot align images, so keep the full typeset width
		$crop{$name} = "bl" ;		
	    }
	    $box_type = "v";
	}
	
	#RRM: include the TeX-code for the appropriate type of box.
	eval "\$raw_contents = \&make_$box_type"."box($name, \$raw_contents);";

	# JCL(jcl-pag) - remember html text if debug is set.
	local($_);
	if ($DEBUG) {
	    $_ = $contents;
	    s/\n/ /g;
	    $_ = &revert_to_raw_tex($_);
	    # incomplete or long commented code can break pre-processors
	    if ($PREPROCESS_IMAGES) {
		$_ = ((/^(\\\w+)?\{[^\\\}\<]*\}?/)? $& : '').'...' ;
		$_ = '{ ... }' if ( length($_) > 100);
	    } elsif ( length($_) > 200) {
		    $_ = join('',substr($_,0,200),"...\}");
	    }
	    s/\\(begin|end)/$1/g; s/[\000-\020]//g;
	    $_ = join('',"% contents=",$_,"\n");
	}
	$raw_contents = '\setcounter{equation}{'.$prev_eqn_number."}\n".$raw_contents
	    if ($env =~ /subequations/);

# JCL(jcl-pag) - build the page entries for images.tex:  Each page is embraced to
# let most statements have only local effect. Each page must compile into a
# single dvi page to get proper image translation. Hence the invisible glue to
# get *at least* one page (raw_contents alone might not wield glue), and
# sufficing page length to get *exactly* one page.
#
	$latex_body .= "{\\newpage\\clearpage\n$_" .
#	    "$raw_contents\\hfill\\vglue1pt\\vfill}\n\n";
#	    "$raw_contents\\hfill\\vss}\n\n" if ($raw_contents);
#	    "$raw_contents\\hfill\\lthtmlcheckvsize\\clearpage}\n\n" if ($raw_contents);
	    "$raw_contents\\lthtmlcheckvsize\\clearpage}\n\n" if ($raw_contents);
    }
    print STDOUT "\nIMAGE_CODE:{$env $id}:\n$raw_contents\n" if ($VERBOSITY > 4);

    # Anchor the labels and put a marker in the text;
    local($img) = &do_labels($fullcontents,"$image_mark#$name#");
    print STDOUT "\nUNDEF_OUT {$env $id}:\n$img\n" if ($VERBOSITY > 4);
    return($img) unless (@foot_anchors);

    # use the image as source to the 1st footnote, unless it is already an anchor.
    if ($img =~ /<\/?A>/) {
	join(' ', $img, @foot_anchors);    	
    } elsif ($#foot_anchors ==0) {
	$foot_anchor = shift @foot_anchors;
	$foot_anchor =~ s/<SUP>.*<\/SUP>/$img/;
#	join(' ', $foot_anchor, @foot_anchors);    	
	$foot_anchor;
    } else {
	join(' ', $img, @foot_anchors);    	
    }
}

sub special_encoding { # locally sets $EXTRA_IMAGE_SCALE
    local($env,$_,$contents) = @_; 
    local($exscale) = /extrascale=([\.\d]*)/;
    local($EXTRA_IMAGE_SCALE) = $exscale if ($exscale);
    &encode(&addto_encoding($env,$contents));
}


sub extract_eqno{
    local($name,$contents) = @_;
    if ($contents =~ /<P ALIGN="\w+">\(([^<>])\)<\/P>$/) {
	if (($eqno{$name})&&!($eqno{$name} eq $1)) {
	    &write_warnings("\nequation number for $name may be wrong.")};
	$eqno{$name}="$1";
    }
}
sub set_equation_counter{
    if ( $global{'eqn_number'}) {
	"\\setcounter{equation}{". $global{'eqn_number'} ."}\n"
    } else { "\\setcounter{equation}{0}\n" }
}

# RRM: 3 different types of boxing, for image environments.

#	general environments --- crops to width & height
sub make_box {
    local($id,$contents) = @_;
    "\\lthtmlfigureA{". $id ."}%\n". $contents ."%\n\\lthtmlfigureZ\n";
}

#	inline math --- horizontal mode, captures height/depth + \mathsurround
sub make_hbox {
    local($id,$contents) = @_;
    if ($id =~ /indisplay/) {
	"\\lthtmlinlinemathA{". $id ."}%\n". $contents ."%\n\\lthtmlindisplaymathZ\n";
    } else {
	"\\lthtmlinlinemathA{". $id ."}%\n". $contents ."%\n\\lthtmlinlinemathZ\n";
    }
}

#	inline text-image (e.g. accents) --- horizontal mode, captures height/depth
sub make_ibox {
    local($id,$contents) = @_;
    "\\lthtmlinlineA{". $id ."}%\n". $contents ."%\n\\lthtmlinlineZ\n";
}

#	centered images (e.g. picture environments) --- horizontal mode
sub make_pbox {
    local($id,$contents) = @_;
    "\\lthtmlpictureA{". $id ."}%\n". $contents ."%\n\\lthtmlpictureZ\n";
}

#	displayed math --- vertical mode, captures height/depth + page-width
sub make_vbox {
    local($id,$contents) = @_;
    if (($HTML_VERSION >=3.2)&&($id =~/(equation|eqnarray)($|\d)/) &&! $failed ) {
	if ($contents =~ s/^\\setcounter\{equation\}\{\d+\}/$&%\n\\lthtmldisplayB\{$id\}%/)
	    { $contents ."%\n\\lthtmldisplayZ\n" }
	else { "\\lthtmldisplayB{$id}%\n". $contents ."%\n\\lthtmldisplayZ\n" }
    } else { "\\lthtmldisplayA{$id}%\n". $contents ."%\n\\lthtmldisplayZ\n"}
}

sub preprocess_images {
    do {
	print "\nWriting image.pre file ...\n";
	open(ENV,">.$dd${PREFIX}images.pre")
            || die "\nCannot write '${PREFIX}images.pre': $!\n";
	print ENV &make_latex($latex_body);
	print ENV "\n";
	close ENV;
	&copy_file($FILE, "bbl");
	&copy_file($FILE, "aux");
	local($num_cmds, $cnt, $this, @cmds);
	@cmds = (split ('\n', $preprocessor_cmds));
	$this_cmd = $num_cmds = 1+$#cmds;
	$cnt = $num_cmds; $preprocessor_cmds = '';
	while (@cmds) {
	    $this_cmd = shift @cmds; last unless ($this_cmd);
	    $this_cmd =~ s/.pre /.tex$cnt / if(($cnt)&&($cnt < $num_cmds));
	    $cnt--; $this_cmd .= $cnt if ($cnt);
	    $preprocessor_cmds .= $this_cmd."\n";
	    L2hos->syswait($this_cmd);
	}
	# save pre-processor commands in a file:  preproc
	open(CMDS,">.$dd${PREFIX}preproc")
            || die "\nCannot write '${PREFIX}preproc': $!\n";
	print CMDS $preprocessor_cmds ;
	close CMDS;

    } if ((%latex_body) && ($latex_body =~ /newpage/));
}
sub make_image_file {
    do {
	print "\nWriting image file ...\n";
	open(ENV,">.$dd${PREFIX}images.tex")
            || die "\nCannot write '${PREFIX}images.tex': $!\n";
	print ENV &make_latex($latex_body);
	print ENV "\n";
	close ENV;
	&copy_file($FILE, "bbl");
	&copy_file($FILE, "aux");
    } if ((%latex_body) && ($latex_body =~ /newpage/));
}

sub make_latex_images{
    &close_dbm_database if $DJGPP;
    local($dd) = $dd; $dd = '/' if ($dd eq "\\"); 
    local($latex_call) = "$LATEX .$dd${PREFIX}images.tex";
    print "$latex_call\n" if (($DEBUG)||($VERBOSITY > 1));
    L2hos->syswait($latex_call);
    &open_dbm_database if $DJGPP;
}

sub make_off_line_images {
    local($name, $page_num);
    if (!$NOLATEX && -f ".${dd}${PREFIX}images.tex") {
	&make_tmp_dir;	# sets  $TMPDIR  and  $DESTDIR
	$IMAGE_PREFIX =~ s/^_//o if ($TMPDIR);

	&make_latex_images();

	print "\nGenerating postscript images using dvips ...\n";
	&process_log_file(".$dd${PREFIX}images.log"); # Get eqn size info
	unless ($LaTeXERROR) {
	    local($dvips_call) = 
		"$DVIPS -S1 -i $DVIPSOPT -o$TMPDIR$dd${IMAGE_PREFIX} .${dd}${PREFIX}images.dvi";
	    print "$dvips_call\n" if (($DEBUG)||($VERBOSITY > 1));

	    &close_dbm_database if $DJGPP;
	    L2hos->syswait($dvips_call) && print "Error: $!\n";
	    undef $dvips_call;
	    &open_dbm_database if $DJGPP;

	    # add suffix .ps to the file-names for each image
	    if(opendir(DIR, $TMPDIR || '.')) {
                #  use list-context instead; thanks De-Wei Yin <yin@asc.on.ca>
	        my (@ALL_IMAGE_FILES) = grep /^$IMAGE_PREFIX\d+$/o, readdir(DIR);
	        foreach (@ALL_IMAGE_FILES) {
		        L2hos->Rename("$TMPDIR$dd$_", "$TMPDIR$dd$_.ps");
	        }
	        closedir(DIR);
            } else {
                print "\nError: Cannot read dir '$TMPDIR': $!\n";
            }
	}
    }
    if ($LaTeXERROR) {
        print "\n\n*** LaTeXERROR\n"; return();
    }

    while ( ($name, $page_num) = each %new_id_map) {
	# Extract the page, convert and save it
	&extract_image($page_num,$orig_name_map{$page_num});
    }
}

# Generate images for unknown environments, equations etc, and replace
# the markers in the main text with them.
# - $cached_env_img maps encoded contents to image URL's
# - $id_map maps $env$id to page numbers in the generated latex file and after
# the images are generated, maps page numbers to image URL's
# - $page_map maps page_numbers to image URL's (temporary map);
# Uses global variables $id_map and $cached_env_img,
# $new_page_num and $latex_body


sub make_images {
    local($name, $contents, $raw_contents, $uucontents, $page_num,
	  $uucontents, %page_map, $img);
    # It is necessary to run LaTeX this early because we need the log file
    # which contains information used to determine equation alignment
    if ( $latex_body =~ /newpage/) {
	print "\n";
	if ($LATEX_DUMP) {
	    # dump a pre-compiled format
	    if (!(-f "${PREFIX}images.fmt")) {
	        print "$INILATEX ./${PREFIX}images.tex\n" 
		    if (($DEBUG)||($VERBOSITY > 1));
	        print "dumping ${PREFIX}images.fmt\n"
		    unless ( L2hos->syswait("$INILATEX ./${PREFIX}images.tex"));
	    }
	    local ($img_fmt) = (-f "${PREFIX}images.fmt");
	    if ($img_fmt) {
                # use the pre-compiled format
	        print "$TEX \"&./${PREFIX}images\" ./${PREFIX}images.tex\n"
		    if (($DEBUG)||($VERBOSITY > 1));
	        L2hos->syswait("$TEX \"&./${PREFIX}images\" ./${PREFIX}images.tex");
	    } elsif (-f "${PREFIX}images.dvi") {
	        print "${PREFIX}images.fmt failed, proceeding anyway\n";
	    } else {
	        print "${PREFIX}images.fmt failed, trying without it\n";
		print "$LATEX ./${PREFIX}images.tex\n"
		    if (($DEBUG)||($VERBOSITY > 1));
		L2hos->syswait("$LATEX ./${PREFIX}images.tex");
	    }
	} else { &make_latex_images() }
#	    local($latex_call) = "$LATEX .$dd${PREFIX}images.tex";
#	    print "$latex_call\n" if (($DEBUG)||($VERBOSITY > 1));
#	    L2hos->syswait("$latex_call");
##	    print "$LATEX ./${PREFIX}images.tex\n" if (($DEBUG)||($VERBOSITY > 1));
##	    L2hos->syswait("$LATEX ./${PREFIX}images.tex");
##        }
	$LaTeXERROR = 0;
	&process_log_file("./${PREFIX}images.log"); # Get image size info
    }
    if ($NO_IMAGES) {
        my $img = "image.$IMAGE_TYPE";
	my $img_path = "$LATEX2HTMLDIR${dd}icons$dd$img";
	L2hos->Copy($img_path, ".$dd$img")
            if(-e $img_path && !-e $img);
    }
    elsif ((!$NOLATEX) && ($latex_body =~ /newpage/) && !($LaTeXERROR)) {
   	print "\nGenerating postscript images using dvips ...\n";
        &make_tmp_dir;  # sets  $TMPDIR  and  $DESTDIR
	$IMAGE_PREFIX =~ s/^_//o if ($TMPDIR);

	local($dvips_call) = 
		"$DVIPS -S1 -i $DVIPSOPT -o$TMPDIR$dd$IMAGE_PREFIX .${dd}${PREFIX}images.dvi\n";
	print $dvips_call if (($DEBUG)||($VERBOSITY > 1));
	
	if ((($PREFIX=~/\./)||($TMPDIR=~/\./)) && not($DVIPS_SAFE)) {
	    print " *** There is a '.' in $TMPDIR or $PREFIX filename;\n"
	    	. "  dvips  will fail, so image-generation is aborted ***\n";
	} else {
	    &close_dbm_database if $DJGPP;
	    L2hos->syswait($dvips_call) && print "Error: $!\n";
	    &open_dbm_database if $DJGPP;
	}

	# append .ps suffix to the filenames
	if(opendir(DIR, $TMPDIR || '.')) {
            # use list-context instead; thanks De-Wei Yin <yin@asc.on.ca>
	    my @ALL_IMAGE_FILES = grep /^$IMAGE_PREFIX\d+$/o, readdir(DIR);
	    foreach (@ALL_IMAGE_FILES) {
	        L2hos->Rename("$TMPDIR$dd$_", "$TMPDIR$dd$_.ps");
	    }
	    closedir(DIR);
        } else {
            print "\nError: Cannot read dir '$TMPDIR': $!\n";
        }
    }
    do {print "\n\n*** LaTeXERROR"; return()} if ($LaTeXERROR);
    return() if ($LaTeXERROR); # empty .dvi file
    L2hos->Unlink(".$dd${PREFIX}images.dvi") unless $DEBUG;

    print "\n *** updating image cache\n" if ($VERBOSITY > 1);
    while ( ($uucontents, $_) = each %cached_env_img) {
	delete $cached_env_img{$uucontents}
	    if ((/$PREFIX$img_rx\.$IMAGE_TYPE/o)&&!($DESTDIR&&$NO_SUBDIR));
	$cached_env_img{$uucontents} = $_
	    if (s/$PREFIX$img_rx\.new/$PREFIX$1.$IMAGE_TYPE/go);
    }
    print "\n *** removing unnecessary images ***\n" if ($VERBOSITY > 1);
    while ( ($name, $page_num) = each %id_map) {
	$contents = $latex_body{$name};
	if ($page_num =~ /^\d+\#\d+$/) { # If it is a page number
	    do {		# Extract the page, convert and save it
		$img = &extract_image($page_num,$orig_name_map{$page_num});
		if ($contents =~ /$htmlimage_rx/) {
		    $uucontents = &special_encoding($env,$2,$contents);
		} elsif ($contents =~ /$htmlimage_pr_rx/) {
		    $uucontents = &special_encoding($env,$2,$contents);
		} else {
		    $uucontents = &encode(&addto_encoding($contents,$contents));
		}
		if (($HTML_VERSION >=3.2)||!($contents=~/$order_sensitive_rx/)){
		    $cached_env_img{$uucontents} = $img;
		} else {
                    # Blow it away so it is not saved for next time
		    delete $cached_env_img{$uucontents};
		    print "\nimage $name not recycled, contents may change (e.g. numbering)";
		}
		$page_map{$page_num} = $img;
	    } unless ($img = $page_map{$page_num}); # unless we've just done it
	    $id_map{$name} = $img;
	} else {
	    $img = $page_num;	# it is already available from previous runs
	}
	print STDOUT " *** image done ***\n" if ($VERBOSITY > 2);
    }
    &write_warnings(
		    "\nOne of the images is more than one page long.\n".
		    "This may cause the rest of the images to get out of sync.\n\n")
	if (-f sprintf("%s%.3d%s", $IMAGE_PREFIX, ++$new_page_num, ".ps"));
    print "\n *** no more images ***\n"  if ($VERBOSITY > 1);
    # MRO: The following cleanup seems to be incorrect: The DBM is
    # still open at this stage, this causes a lot of unlink errors
    #
    #do { &cleanup; print "\n *** clean ***\n"  if ($VERBOSITY > 1);}
    #	unless $DJGPP;
}

# MRO: This copies the navigation icons from the distribution directory
# or an alternative specified in $ALTERNATIVE_ICONS
# to the document directory.

sub copy_icons {
    local($icon,$_);
    print "\nCopying navigation icons ...";
    foreach (keys %used_icons) {
	# each entry ends in gif or png
	if ($ALTERNATIVE_ICONS) {
	    L2hos->Copy("$ALTERNATIVE_ICONS$dd$_", ".$dd$_")
		if (-e "$ALTERNATIVE_ICONS$dd$_" && !-e $_);
	} elsif (/(gif|png)$/) {
	    L2hos->Copy("$LATEX2HTMLDIR${dd}icons$dd$_", ".$dd$_")
		if (-e "$LATEX2HTMLDIR${dd}icons$dd$_" && !-e $_);
	}
    }
}

sub process_log_file {
    local($logfile) = @_;
    local($name,$before,$lengthsfound);
    local($TeXpt)= 72/72.27;
    local($image_counter);
    open(LOG, "<$logfile") || die "\nCannot read logfile '$logfile': $!\n";
    while (<LOG>) {
        if (/Overfull/) { $before .= $_ }
        elsif (/latex2htmlLength ([a-zA-Z]+)=(\-?[\d\.]+)pt/) {
	    ${$1} = 0.0+$2; $lengthsfound = 1;
	} elsif (/latex2htmlSize|l2hSize/) {
	    /:([^:]*):/;
	    $name = $1; $name =~ s/\*//g;
	    ++$image_counter;
	    s/:([0-9.]*)pt/$height{$name} = $1*$TeXpt;''/e;
	    s/::([0-9.]*)pt/$depth{$name} = $1*$TeXpt;''/e;
	    s/::([0-9.]*)pt/$width{$name} = $1*$TeXpt;''/e;
	    s/\((.*)\)/$eqno{$name} = 1+$1;''/e;
	    if ($before) {
		local($tmp);
		if ($before =~ /hbox\s*\((\d+\.?\d*)pt/) {
		    $width{$name} = $width{$name}+$1*$TeXpt;
		}
		if ($before =~ /vbox\s*\((\d+\.?\d*)pt/) {
		    $height{$name} = $height{$name}+$1*$TeXpt;
		}
	        $before = '';
	    }
	}
    $LaTeXERROR = 1 if (/^No pages of output./);
    }

    if ($LaTeXERROR) {
	print STDERR "\n\n *** LaTeX produced no output ***\n"
	    . " *** no new images can be created\n"
	    . " *** Examine the  images.log  file.\n\n";
	return;
    }
    print STDOUT "\n *** processing $image_counter images ***\n";
    print STDOUT "\n *** LATEX LOG OK. ***\n" if ($VERBOSITY > 1);

    if ($lengthsfound) {
	$ODD_HMARGIN  = $hoffset + $oddsidemargin;
	$EVEN_HMARGIN = $hoffset + $evensidemargin;
	$VMARGIN = $voffset + $topmargin + $headheight + $headsep;
        if ($dvi_mag >0 && $dvi_mag != 1000) {
	    $ODD_HMARGIN = int($dvi_mag /1000 * $ODD_HMARGIN);
	    $EVEN_HMARGIN = int($dvi_mag /1000 * $EVEN_HMARGIN);
	    $VMARGIN = int($dvi_mag /1000 * $VMARGIN);
	}
    } else {
	$ODD_HMARGIN = 0;
	$EVEN_HMARGIN = 0;
	$VMARGIN = 0;
    }
    $ODD_HMARGIN  = int($ODD_HMARGIN*$TeXpt  + 72.5);
    $EVEN_HMARGIN = int($EVEN_HMARGIN*$TeXpt + 72.5);
    $VMARGIN = int($VMARGIN*$TeXpt + 72.5);
    close(LOG);
}


### Bo ###  Called for every image 
sub extract_image { # clean

    my ($page_num,$name) = @_;

    # The followin come out of %img_params
    my ($scale, $external, $thumbnail, $map, $psimage, $align, $usemap,
	  $flip, $aalias, $trans, $exscale, $alt, $exstr);

    my ($lwidth, $val) = (0, '');
    my ($custom_size,$color_depth,$height,$width,$croparg);

    print STDOUT "\nextracting $name as $page_num\n" if ($VERBOSITY > 1);
    # $global_num identifies this image in the original source file
    # $new_num identifies this image in images.tex
    my ($global_num, $new_num) = split(/#/, $page_num);
    $name =~ s/\*/star/;
    my ($env,$basename,$img) = ($name,"img$global_num",'');
    $env =~ s/\d+$//;
    $psname = sprintf("%s%.3d", "$TMPDIR$dd$IMAGE_PREFIX", $new_num);
    if ( $EXTERNAL_IMAGES && $PS_IMAGES ) {
	$img =  "$basename.ps";
	L2hos->Copy("$psname.ps", "${PREFIX}$img");
    } else {
	$img = "$basename.$IMAGE_TYPE";
	($scale, $external, $thumbnail, $map, $psimage, $align, $usemap, 
	    $flip, $aalias, $trans, $exscale, $alt, $exstr) =
            split('#', $img_params{$name});
	$lwidth = ($align =~ s/nojustify/middle/) ? 0 : $LINE_WIDTH;

#<bo>
#	print "name is: $name\n";
#</bo>

	$alt = "ALT=\"$name\"" unless $alt;
	$exscale = $EXTRA_IMAGE_SCALE unless($exscale);
	if ($NO_IMAGES) {
	    L2hos->Symlink("image.$IMAGE_TYPE", "${PREFIX}$img");
	    if ($thumbnail) {
		L2hos->Symlink("image.$IMAGE_TYPE", "${PREFIX}T$img");
		$thumbnail = "${PREFIX}T$img";
	    }
	} else {
	    # RRM: deal with size data
 	    if ($width{$name} < 0) {
		if ($exscale && $PK_GENERATION) {
	    	    $height = int(				
			$exscale*$height{$name}+	
			$exscale*$depth{$name} +.5);
		    $width = int($exscale*$width{$name}-.5);
		} else {
	    	    $height = int($height{$name}+$depth{$name}+.5);
		    $width = int($width{$name}-.5);
		}
		$custom_size = "${width}x$height";
	    } elsif ($width{$name}) {
		if ($exscale && $PK_GENERATION) {
		    $height = int( $height{$name} * $exscale +
			$depth{$name} * $exscale +.5);
		    $width = int($width{$name} * $exscale +.5);
		} else {
		    $height = int($height{$name}+$depth{$name}+.5);
		    $width = int($width{$name}+.5);
		}
		$custom_size = "${width}x$height";
            } else {
		$custom_size = '';
	    }
            # MRO: add first overall crop
	    $croparg = '-crop a' . ($crop{$name} || '') . ' ';
	    $page_num  =~ s/^\d+#//o;
	    $custom_size .= " -margins "
		. (($page_num % 2) ? $ODD_HMARGIN:$EVEN_HMARGIN)
		. ",$VMARGIN" if ($custom_size);

	    #RRM: \special commands may place ink outside the expected bounds:
	    $custom_size = '' if ($tex_specials{$name});

	    # MRO: Patches for image conversion with pstoimg
	    # RRM: ...with modifications and fixes
	    L2hos->Unlink("${PREFIX}$img");
	    &close_dbm_database if $DJGPP;

            print "Converting image #$new_num\n";

	    if ( ($name =~ /figure/) || $psimage || $scale || $thumbnail) {
		$scale = $FIGURE_SCALE_FACTOR unless ($scale);
		print "\nFIGURE: $name scaled $scale  $aalias\n" if ($VERBOSITY > 2);
		(L2hos->syswait( "$PSTOIMG -type $IMAGE_TYPE "
		. ($DEBUG ? '-debug ' : '-quiet ' )
		. ($TMPDIR ? "-tmp $TMPDIR " : '' )
		. (($DISCARD_PS && !$thumbnail && !$psimage)? "-discard " :'')
		. (($INTERLACE) ? "-interlace " : '' )
		. (((($ANTI_ALIAS)||($aalias))&&($aalias !~ /no|text/))? "-antialias ":'')
		. (($ANTI_ALIAS_TEXT||(($aalias =~/text/)&&($aalias !~/no/)))?
			"-aaliastext ":'') 
		. (($custom_size) ? "-geometry $custom_size ": '' )
		. $croparg
		. ($color_depth || '')
		. (($flip) ? "-flip $flip " : '' )
		. (($scale > 0) ? "-scale $scale " : '' )
		. (((($TRANSPARENT_FIGURES && ($env =~ /figure/o))||($trans))
		     &&(!($trans =~ /no/))) ? "-transparent " : '')
		. (($WHITE_BACKGROUND) ? "-white " : '' )
		. "-out ${PREFIX}$img $psname.ps"
		) ) # ||!(print "\nWriting image: ${PREFIX}$img"))
		    && print "\nError while converting image: $!\n";

		if ($thumbnail) { # $thumbnail contains the reduction factor
		    L2hos->Unlink("${PREFIX}T$img");
		    print "\nIMAGE thumbnail: $name" if ($VERBOSITY > 2);
		    (L2hos->syswait( "$PSTOIMG -type $IMAGE_TYPE "
		    . ($DEBUG ? '-debug ' : '-quiet ' )
		    . ($TMPDIR ? "-tmp $TMPDIR " : '' )
		    . (($DISCARD_PS && !$psimage) ? "-discard " : '' )
		    . (($INTERLACE) ? "-interlace " : '' )
		    . ((($ANTI_ALIAS||($aalias))&&(!($aalias =~/no/)))? "-antialias " :'')
		    . (($ANTI_ALIAS_TEXT||(($aalias =~/text/)&&($aalias !~/no/)))?
			"-aaliastext ":'') 
		    . (($custom_size) ? "-geometry $custom_size " : '' )
		    . ($color_depth || '')
		    . (($flip) ? "-flip $flip " : '' )
		    . (($thumbnail > 0) ? "-scale $thumbnail " : '' )
		    . ((($trans)&&(!($trans =~ /no/))) ? "-transparent " : '')
		    . (($WHITE_BACKGROUND) ? "-white " : '' )
		    . "-out ${PREFIX}T$img $psname.ps"
		    ) ) # ||!(print "\nWriting image: ${PREFIX}T$img"))
			&& print "\nError while converting thumbnail: $!\n";
		    $thumbnail = "${PREFIX}T$img";
		}
	    } elsif (($exscale &&(!$PK_GENERATION))&&($width{$name})) {
		my $under = '';
		my $mathscale = ($MATH_SCALE_FACTOR > 0) ? $MATH_SCALE_FACTOR : 1;
		if (($DISP_SCALE_FACTOR > 0) &&
		    ( $name =~ /equation|eqnarray|display/))
		        { $mathscale *= $DISP_SCALE_FACTOR; };
		if ($scale) {
		    $scale *= $exscale if ($name =~ /makeimage|tab/);
		} else {
		    $scale = $mathscale*$exscale;
		    $under = "d" if (($name =~/inline|indisplay/)&&($depth{$name}));
		}
		print "\nIMAGE: $name  scaled by $scale \n" if ($VERBOSITY > 2);
		(L2hos->syswait( "$PSTOIMG -type $IMAGE_TYPE "
		. ($DEBUG ? '-debug ' : '-quiet ' )
		. ($TMPDIR ? "-tmp $TMPDIR " : '' )
		. (($DISCARD_PS)? "-discard " : '' )
		. (($INTERLACE)? "-interlace " : '' )
		. ((($ANTI_ALIAS_TEXT||($aalias))&&($aalias !=~/no/))? 
		    "-antialias -depth 1 " :'')
		. (($custom_size)? "-geometry $custom_size " : '' )
                . $croparg
		. (($scale != 1)? "-scale $scale " : '' )
		. ((($exscale)&&($exscale != 1)&&
		    !($ANTI_ALIAS_TEXT &&($LATEX_COLOR)))? 
			"-shoreup $exscale$under " :'')
		. ((($TRANSPARENT_FIGURES ||($trans))
		     &&(!($trans =~ /no/)))? "-transparent " : '')
		. (($WHITE_BACKGROUND && !$TRANSPARENT_FIGURES) ? "-white " : '' )
		. "-out ${PREFIX}$img $psname.ps"
		) ) # ||!(print "\nWriting image: ${PREFIX}$img"))
		    && print "\nError while converting image: $!\n";
	    } else {
		print "\nIMAGE: $name\n" if ($VERBOSITY > 2);
		my $under = '';
		my $mathscale = ($MATH_SCALE_FACTOR > 0) ? $MATH_SCALE_FACTOR : 1;
		if (($DISP_SCALE_FACTOR > 0) &&
		    ( $name =~ /equation|eqnarray|display/))
		        { $mathscale *= $DISP_SCALE_FACTOR; };
		if (($scale)&&($exscale)) {
		    $scale *= $exscale if ($name =~ /makeimage|tab/);
		} elsif ($scale) {
		} elsif (($mathscale)&&($exscale)) {
		    $scale = $mathscale*$exscale;
		    $under = "d" if (($name =~/inline|indisplay/)&&($depth{$name}));
		} elsif ($mathscale) { $scale = $mathscale; }

		(L2hos->syswait("$PSTOIMG -type $IMAGE_TYPE "
		. ($DEBUG ? '-debug ' : '-quiet ' )
		. ($TMPDIR ? "-tmp $TMPDIR " : '' )
		. (($DISCARD_PS) ? "-discard " : '' )
		. (($INTERLACE) ? "-interlace " : '' )
		. ((($ANTI_ALIAS_TEXT||($aalias))&&(!($aalias =~ /no/)))?
		    "-antialias -depth 1 " :'')
		. ((($exscale)&&($exscale != 1)&&
		    !($ANTI_ALIAS_TEXT &&($LATEX_COLOR)))? 
			"-shoreup $exscale " :'')
		. (($scale ne 1) ? "-scale $scale " : '' )
		. (($custom_size) ? "-geometry $custom_size " : '' )
                . $croparg
#		.  (($name =~ /(equation|eqnarray)/) ? "-rightjustify $lwidth " : '')
#		.  (($name =~ /displaymath/) ? "-center $lwidth " : '')
		. (($name =~ /inline|indisplay/ && (!($custom_size))&&$depth{$name}!= 0) ?
		    do {$val=($height{$name}-$depth{$name})/($height{$name}+$depth{$name});
			"-topjustify x$val "} : '')
		. ((($TRANSPARENT_FIGURES||($trans))
		    &&(!($trans =~ /no/))) ? "-transparent " : '')
		. (($WHITE_BACKGROUND && !$TRANSPARENT_FIGURES) ? "-white " : '' )
		. "-out ${PREFIX}$img $psname.ps")
		) #|| !(print "\nWriting image: ${PREFIX}$img"))
		    && print "\nError while converting image\n";
	    }
	    if (! -r "${PREFIX}$img") {
		&write_warnings("\nFailed to convert image $psname.ps")
	    } else { } #L2hos->Unlink("$psname.ps") unless $DEBUG }
	    &open_dbm_database if $DJGPP;
	}
    }
    print "\nextracted $name as $page_num\n" if ($VERBOSITY > 1);
    &embed_image("${PREFIX}$img", $name, $external, $alt, $thumbnail, $map,
        $align, $usemap, $exscale, $exstr);
}

sub extract_parameters {
    local($contents) = @_;
    local($_, $scale, $external, $thumbnail, $map, $psimage, $align,
	  $usemap, $flip, $aalias, $trans, $pagecolor, $alt, $exscale,
	  $cdepth, $htmlparams);

    #remove the \htmlimage commands and arguments before...
    $contents =~ s/$htmlimage_rx/$_ = $2;''/ego;
    $contents =~ s/$htmlimage_pr_rx/$_ .= $2;''/ego;

    # code adapted from original idea by Stephen Gildea:
    # If the document specifies the ALT tag explicitly
    # with \htmlimage{alt=some text} then use it.
    s!alt=([^,]+)!$alt = $1;
        $alt =~ s/^\s+|\s+$//g; $alt =~ s/"//g;
        $alt="ALT=\"$alt\"";
    ''!ie;
  if (!$alt) {
    #...catching all the code for the ALT text.
    local($keep_gt)=1;
   $alt = &flatten_math($contents); undef $keep_gt;
    #RRM: too long strings upset the DBM. Truncate to <= 165 chars.

#<bo>
# This causes the incomplete formula problem

#    if ( length($alt) > 163 ) {
#	local($start,$end);
#	$start = substr($alt,0,80);
#	$end = substr($alt,length($alt)-80,80);
#	$alt = join('',$start,"...\n ...",$end);
#    }

#</bo>

    s/ALT\s*=\"([\w\W]*)\"/$alt=$1;''/ie;
    if ($alt) {
	if ($alt =~ /\#/) {
	    $alt =~ s/^(\\vbox\{)?\#[A-Za-z]*\s*//;
	    $alt =~ s/\n?\#[A-Za-z]*\s*\}?$//s;
	    if ($alt =~ /\#/) { $alt = $` . " ... " };
	}
	$alt =~ s/\`\`/\\lq\\lq /g; $alt =~ s/\`/\\lq /g;
	$alt =~ s/(^\s*|\s*$)//mg;
	$alt = "ALT=\"$alt\"" if ($alt);
    } else { $alt = 'ALT="image"' }
  }

    $psimage++ if ($contents =~ /\.ps/);
#    $contents =~ s/\s//g;	# Remove spaces   Why ?
    s/extrascale=([\.\d]*)/$exscale=$1;''/ie;
    s/\bscale=([\.\d]*)/$scale=$1;''/ie;
    s/(^|,\s*)external/$external=1;''/ie;
    s/(^|,\s*)((no)?_?anti)alias(_?(text))?/$aalias = $2.$4;''/ie;
    s/(^|,\s*)((no)?_?trans)parent/$trans = $2;''/ie;
    s/thumbnail=([\.\d]*)/$thumbnail=$1;''/ie;
    s/usemap=([^\s,]+)/$usemap=$1;''/ie;
    s/map=([^\s,]+)/;$map=$1;''/ie;
    s/align=([^\s,]+)/$align=$1;''/ie;
    s/flip=([^\s,]+)/$flip=$1;''/ie;
    s/color_?(depth)?=([^\s,]+)/$cdepth=$2;''/ie;
    ($scale,$external,$thumbnail,$map,$psimage,$align
     ,$usemap,$flip,$aalias,$trans,$exscale,$alt,$_);
}


# RRM: Put the raw \TeX code into the ALT tag
# replacing artificial environments and awkward characters
sub flatten_math {
    local ($_) = @_;
    $_ = &revert_to_raw_tex($_);
    s/[ \t]+/ /g;
    # MRO: replaced $* with /m
    s/$tex2html_wrap_rx//gm;
    s/(\\begin\s*\{[^\}]*\})(\s*(\[[^]]*\]))?[ \t]*/$1$3/gm;
    s/(\\end\{[^\}]*\})\n?/$1/gm;
    s/>(\w)?/($1)?"\\gt $1":"\\gt"/eg unless ($keep_gt); # replace > by \gt
    s/\\\|(\w)?/($1)?"\\Vert $1":"\\Vert"/eg; 	# replace \| by \Vert
    s/\|(\w)?/($1)?"\\vert $1":"\\vert"/eg; 	# replace | by \vert
    s/\\\\/\\\\ /g; 	# insert space after \\ 
    s/\\"/\\uml /g;	# screen umlaut accents...
    s/"/\'\'/g;		# replace " by ''
    s/\\\#/\\char93 /g;	# replace \# by \char93 else caching fails
#    s/"(\w)?/($1)?"\\rq\\rq $1":"\'\'"/eg;	# replace " by \rq\rq
#    s/\&\\uml /\\\"/g;	# ...reinstate umlauts
    $_;
}

sub scaled_image_size {
    local($exscale,$_) = @_;
    local($width,$height) = ('','');
    /WIDTH=\"?(\d*)\"?\s*HEIGHT=\"?(\d*)\"?$/o;
    $width=int($1/$exscale + .5);
    $height=int($2/$exscale + .5);
    "WIDTH=\"$width\" HEIGHT=\"$height\""
}

sub process_in_latex {
    # This is just a wrapper for process_undefined_environment.
    # @[0] = contents
    $global{'max_id'}++;
    &process_undefined_environment('tex2html_wrap',$global{'max_id'},$_[0]);
}

# MRO: cp deprecated, replaced by L2hos->Copy

# Marcus Hennecke  6/3/96
# MRO: test for existance
sub copy_file {
    local($file, $ext) = @_;
    $file =  &fulltexpath("$FILE.$ext");
    if(-r $file) {
        print "\nNote: Copying '$file' for image generation\n"
            if($VERBOSITY > 2);
        L2hos->Copy($file, ".$dd${PREFIX}images.$ext");
    }
}

sub rename_image_files {
    local($_, $old_name, $prefix);
    if ($PREFIX) {
	foreach (<${PREFIX}*img*.$IMAGE_TYPE>) {
	    $old_name = $_;
	    s/\.$IMAGE_TYPE$/\.old/o;
	    L2hos->Rename($old_name, $_);
	    }
	}
    else {
	foreach (<img*.$IMAGE_TYPE>) {
	    $old_name = $_;
	    s/\.$IMAGE_TYPE$/\.old/o;
	    L2hos->Rename($old_name, $_);
	}
	foreach (<Timg*.$IMAGE_TYPE>) {
	    $old_name = $_;
	    s/\.$IMAGE_TYPE$/\.old/o;
	    L2hos->Rename($old_name, $_);
	}
    }
}


############################ Processing Commands ##########################

sub ignore_translate_commands {
    local ($_) = @_;
#   print "\nTranslating commands ...";

    local(@processedC);
    &replace_strange_accents;
    local($before, $contents, $br_id, $after, $pattern, $end_cmd_rx);
    s/$begin_cmd_rx/&replace_macro_expansion($`, $1, $&, $')/eg;
}

sub replace_macro_expansion {
    push(@processedC,$_[1]);
    $end_cmd_rx = &make_end_cmd_rx($_[2]);
    $pattern = $_[3];
    $_ = join('',$_[3],$_[4]);
    $after = $_[4];
    if (($before)&&(!($before =~ /$begin_cmd_rx/))) {
	push(@processedC,$before);
	    $_ = join('',$pattern,$after); $before = '';
	}
	local($end_cmd_rx) = &make_end_cmd_rx($br_id);
    
}

sub translate_aux_commands {
    s/^(.*)$/&translate_commands($1)/s;
}

sub translate_commands {
    local ($_) = @_;
#   print "\nTranslating commands ...";

    local(@processedC);
    &replace_strange_accents;
    for (;;) {			# For each opening bracket ...
	last unless ($_ =~ /$begin_cmd_rx/);
	local($before, $contents, $br_id, $after, $pattern);
	($before, $br_id, $after, $pattern) = ($`, $1, $', $&);
	if (($before)&&(!($before =~ /$begin_cmd_rx/))) {
	    push(@processedC,$before);
	    $_ = join('',$pattern,$after); $before = '';
	}
	local($end_cmd_rx) = &make_end_cmd_rx($br_id);
	if ($after =~ /$end_cmd_rx/) { # ... find the the matching closing one
	    $NESTING_LEVEL++;
	    ($contents, $after) = ($`, $');
	    do {
		local(@save_open_tags) = @$open_tags_R;
		local($open_tags_R) = [ @save_open_tags ];
		print STDOUT "\nIN::{$br_id}" if ($VERBOSITY > 4);
		print STDOUT "\n:$contents\n" if ($VERBOSITY > 7);
		undef $_;
		$contents = &translate_commands($contents)
		    if ($contents =~ /$match_br_rx/o);
                # Modifies $contents
		&process_command($single_cmd_rx,$contents)
		    if ($contents =~ /\\/o);

		$contents .= &balance_tags();
	    };

	    print STDOUT "\nOUT: {$br_id}" if ($VERBOSITY > 4);
	    print STDOUT "\n:$contents\n" if ($VERBOSITY > 7);
	    # THIS MARKS THE OPEN-CLOSE DELIMITERS AS PROCESSED
	    $_ = join("", $before,"$OP$br_id$CP", $contents,"$OP$br_id$CP", $after);
	    $NESTING_LEVEL--;
	}
	else {
	    $pattern = &escape_rx_chars($pattern);
	    s/$pattern//;
	    print "\nCannot find matching bracket for $br_id" unless $AUX_FILE;
	}
	last unless ($_ =~ /$begin_cmd_rx/o);
    }
    $_ = join('',@processedC) . $_;
    # Now do any top level commands that are not inside any brackets
    # MODIFIES $_
    print $_ if ($VERBOSITY > 8);
    &process_command($single_cmd_rx,$_);
}

#RRM: based on earlier work of Marcus Hennecke
# makes sure the $open_tags_R at the end of an environment
# is the same as @save_open_tags from the start,
# ensuring that the HTML page indeed has balanced tags
sub balance_tags {
    local($tag_cmd, $tags, $save_tags, $open_tags, @reopen_tags);
    $save_tags = join(',',@save_open_tags) if (@save_open_tags);
    $open_tags = join(',',@$open_tags_R) if (@$open_tags_R);
    if ($open_tags eq $save_tags) { return(); }
    if ($save_tags =~ s/^$open_tags//) {
	@reopen_tags = split (',',$');
    } else {
	@reopen_tags = @save_open_tags;
	while (@$open_tags_R) {
	    $tag_cmd = pop (@$open_tags_R);
	    print STDOUT "\n</$tag_cmd>" if $VERBOSITY > 2;
	    $declarations{$tag_cmd} =~ m|</.*$|;
	    $tags .= $& unless ($` =~ /^<>$/);
	    $open_tags = join(',',@$open_tags_R) if (@$open_tags_R);
	    last if ( $save_tags =~ s/^$open_tags/
		     @reopen_tags = split (',',$');''/e);
	}
    }
    while (@reopen_tags) {
	$tag_cmd = shift @reopen_tags;
	if ($tag_cmd) {
	    push (@$open_tags_R, $tag_cmd) if ($tag_cmd);
	    print STDOUT "\n<$tag_cmd>" if $VERBOSITY > 2;
	    $declarations{$tag_cmd} =~ m|</.*$|;
	    $tags .= $` unless ($` =~ /^<>$/);
	}
    }
    $tags;
}

sub close_all_tags {
    return() if (!@$open_tags_R);
    local($tags,$tag_cmd);
    while (@$open_tags_R) {
	$tag_cmd = pop (@$open_tags_R);
	print STDOUT "\n</$tag_cmd>" if $VERBOSITY > 2;
	$declarations{$tag_cmd} =~ m|</.*$|;
	$tags .= $& unless ($` =~ /^<>$/);
    }
    $tags;
}

sub preserve_open_tags {
    local(@save_open_tags) = @$open_tags_R;
    local($open_tags_R) = [ @save_open_tags ];
    # provides the markup to close and reopen the current tags
    (&close_all_tags(), &balance_tags());
}

sub preserve_open_block_tags {
    local($tag_cmd,$tags_open,$tags_close,$pre,$post,@tags);
    while (@$open_tags_R) {
	$tag_cmd = pop (@$open_tags_R);
	print STDOUT "\n</$tag_cmd>" if $VERBOSITY > 2;
	$declarations{$tag_cmd} =~ m|</.*$|;
	($pre,$post) = ($`,$&);
	if ($post =~ /$block_close_rx/) {
	    # put it back and exit
	    push(@$open_tags_R,$tag_cmd);
	    last;
	} else {
	    # leave it closed, collecting tags for it
	    $tags_close .= $post;
	    $tags_open = $pre . $tags_open;
	    unshift(@tags,$tag_cmd);
	}
    }
    ($tags_close , $tags_open, @tags);  
}

sub minimize_open_tags {
    local($this_tag, $close_only) = @_;
    local($pre,$post,$decl);
    $decl = $declarations{$this_tag};
    if ($decl) {
    # if it is a declaration, get the corresponding tags...
	$decl =~ m|</.*$|;
	($pre,$post) = ($`,$&) unless ($` =~ /^<>$/);
	if (!@$open_tags_R) { # when nothing else is open...
            # pushing the style, when appropriate
	    push (@$open_tags_R, $this_tag)
		unless ($close_only ||($post =~ /$block_close_rx/));
	    print STDOUT "\n<$this_tag>" if $VERBOSITY > 2;
            # and return the tags
	    return($pre,$post) unless ($USING_STYLES);
	    local($env_id) = '' if ($env_id =~/^\w+$/);
	    $pre =~ s/>$/ $env_id>/ if ($env_id);
	    return($pre,$post);
	}
    } else { # ...else record the argument as $pre
	$pre = $this_tag unless $close_only;
    }
    local($env_id) = '' if ($env_id =~/^\w+$/);
    $pre =~ s/>$/ ID="$env_id">/ if ($USING_STYLES &&($env_id));

    # return the tags, if nothing is already open
    if (!@$open_tags_R) { 
	return($pre,$post);
    }
#    elsif ($close_only) { push (@$open_tags_R, $this_tag) }

    local($tags,$tag_cmd,$tag_open);
    local($closures,$reopens,@tags);
    local($tag_close,$tag_open);
    local($size_cmd,$size_open);
    local($font_cmd,$font_open);
    local($fontwt_cmd,$fontwt_open);
    local($color_cmd,$color_open);
     if ($decl) {
	if ($this_tag =~ /$sizechange_rx/) { 
	    $size_cmd = $this_tag;
	} else {
	    if ($this_tag =~ /$fontchange_rx/) { 
	        $font_cmd = $this_tag }
	    if ($this_tag =~ /$fontweight_rx/) { 
		$fontwt_cmd = $this_tag }
	}
    }
    while (@$open_tags_R) {
	($tag_close,$tag_open) = ('','');
	$tag_cmd = pop (@$open_tags_R);
	print STDOUT "\n</$tag_cmd>" if $VERBOSITY > 2;
	$declarations{$tag_cmd} =~ m|</.*$|;
	($tag_close,$tag_open) = ($&,$`) unless ($` =~ /<>/);
	$closures .= $tag_close;

	if ((!$size_cmd)&&($tag_cmd =~ /$sizechange_rx/)) {
	    $size_cmd = $tag_cmd;
	    $size_open = $tag_open;
	}
	elsif ((!$font_cmd)&&($tag_cmd =~ /$fontchange_rx/)) {
	    $font_cmd = $tag_cmd;
	    $font_open = $tag_open;
	}
	elsif ((!$fontwt_cmd)&&($tag_cmd =~ /$fontweight_rx/)) {
	    $fontwt_cmd = $tag_cmd;
	    $fontwt_open = $tag_open;
	}
	elsif ((!$color_cmd)&&($tag_cmd =~ /$colorchange_rx/)) {
	    $color_cmd = $tag_cmd;
	    $color_open = $tag_open;
	} 
	elsif ($tag_cmd =~ 
	     /$sizechange_rx|$fontchange_rx|$fontweight_rx|$colorchange_rx/) {
	} else {
	    unshift (@tags, $tag_cmd);
	    print STDOUT "\n<<$tag_cmd>" if $VERBOSITY > 2;
	    $reopens = $tag_open . $reopens;
	}
    }
    if ($USING_STYLES) {
	local($TAG) = "DIV";
	if ($pre =~ /^<(DIV|SPAN|PRE)/) { $TAG = $1 };
	if (($pre =~ /^<$TAG/)&&($env_id =~ /^\s+(CLASS|ID)/)) {
	    $pre =~ s/<$TAG/<$TAG$env_id/;
	} elsif ($pre =~ /<P>/) {
	    $TAG = 'P';
	} else {
	}
#	$post .= "</$TAG>";
    }
    push (@$open_tags_R, @tags);
    $tags .= $pre if ($pre && $post =~ /$block_close_rx/);
    if ($font_cmd && !($font_cmd eq $this_tag)) {
	push (@$open_tags_R,$font_cmd);
	print STDOUT "\n<$font_cmd>" if $VERBOSITY > 2;
	$tags .= $font_open;
    }
    if ($fontwt_cmd && !($fontwt_cmd eq $this_tag)) {
	push (@$open_tags_R,$fontwt_cmd);
	print STDOUT "\n<$fontwt_cmd>" if $VERBOSITY > 2;
	$tags .= $fontwt_open;
    }
    if ($size_cmd && !($size_cmd eq $this_tag)) {
	push (@$open_tags_R,$size_cmd);
	print STDOUT "\n<$size_cmd>" if $VERBOSITY > 2;
	$tags .= $size_open;
    }
    if ($color_cmd && !($color_cmd eq $this_tag)) {
	push (@$open_tags_R,$color_cmd);
	print STDOUT "\n<$color_cmd>" if $VERBOSITY > 2;
	$tags .= $color_open;
    }
    $tags .= $pre unless ($pre && $post =~ /$block_close_rx/);
    push (@$open_tags_R, $this_tag)
	if ($decl &&!($post =~ /$block_close_rx|$all_close_rx/));
    print STDOUT "\n<$this_tag>" if $VERBOSITY > 2;
    ($closures.$reopens.$tags , $post );
}


sub declared_env {
    local($decl, $_, $deferred) = @_;
    local($after_cell,$pre,$post);
    local($decls) = $declarations{$decl};
    $decls =~ m|</.*$|;
    ($pre,$post) = ($`,$&);
    if ($USING_STYLES) {
	$env_style{$decl} = " " unless ($env_style{$decl});
	$pre =~ s/>$/$env_id>/ if ($env_id);
    }
    local($closing_tag) = 1 if ($pre =~ /^<>$/);
    $pre = $post = '' if $closing_tag;
    local($closures,$reopens);

    local(@save_open_tags) = @$open_tags_R
	unless ($closing_tag || $deferred);
    local($open_tags_R) = [ @save_open_tags ]
	unless ($closing_tag || $deferred );

    if ($post =~ /$block_close_rx/) {
	local($last_tag) = pop (@$open_tags_R);
	local($ldecl) = $declarations{$last_tag};
	if ($ldecl =~ m|</.*$|) { $ldecl = $& }
	if (($last_tag)&&!($ldecl =~ /$block_close_rx/)) {
	    # need to close tags, for re-opening inside
	    push (@$open_tags_R, $last_tag);
	    ($closures,$reopens) = &preserve_open_tags();
	    $pre = join('', $closures, "\n", $pre, $reopens);
	    $post = join('', $closures, $post, $reopens);
	} elsif ($last_tag) {
	    $pre = "\n".$pre;
	    push (@$open_tags_R, $last_tag);
	    undef $ldecl;
	} else {
	}

	if ($deferred) {
	    if (defined $ldecl) {
		print STDOUT "\n<<$decl>" if $VERBOSITY > 2;
		unshift(@$open_tags_R, $decl);
	    } else {
		print STDOUT "\n<$decl>" if $VERBOSITY > 2;
		push(@$open_tags_R, $decl);
	    }
	    return ( $pre . $_ );
	} else {
	    if (defined $ldecl) {
		print STDOUT "\n<<$decl>" if $VERBOSITY > 2;
		unshift(@$open_tags_R, $decl);
	    } else {
		print STDOUT "\n<$decl>" if $VERBOSITY > 2;
		push(@$open_tags_R, $decl);
	    }
	}
    } elsif ($post =~/$all_close_rx/) {
	($closures,$reopens) = &preserve_open_tags();
	($pre,$post) = &minimize_open_tags($decl,1);
	$pre = join('', $closures, $pre);
    } elsif ($closing_tag) {
	$prev_open = $pre;
	($pre,$post) = &minimize_open_tags($decl,1);
	$pre =~ s/<\/?>//g; $post =~ s/<\/?>//;
    } else {
	($pre,$post) = &minimize_open_tags($decl); 
    }
    $_ =~ s/^\s+//s; #RRM:28/4/99 remove spaces at the beginning
    $_ = &translate_environments($_);
    $_ = &translate_commands($_) if (/\\/);
    if ($post =~ /$block_close_rx/) {
	s/^\n?/\n/o; 
	if (defined $ldecl) {
	    $post = &close_all_tags();
	} else {
	    $post = "\n";
	}
    } elsif ($post =~/$all_close_rx/) {
    } else { $post = '' };

    join('', $pre, $_, $post
	   , ($closing_tag ? '' : &balance_tags()) );
}

sub do_cmd_centering{&declared_env('center',$_[0],$tex2html_deferred)}
sub do_cmd_raggedright{&declared_env('flushleft',$_[0],$tex2html_deferred)}
sub do_cmd_raggedleft{&declared_env('flushright',$_[0],$tex2html_deferred)}

sub do_env_verse { &declared_env('verse',@_) }
sub do_env_quote { &declared_env('quote', @_) }
sub do_env_quotation { &declared_env('quote', @_) }
sub do_env_tex2html_preform { &declared_env('preform', @_) }
sub do_env_tex2html_ord { &declared_env('ord', @_) }
sub do_env_tex2html_unord { &declared_env('unord', @_) }
sub do_env_tex2html_desc { &declared_env('desc', @_) }


# Modifies $contents
sub process_command {
    # MRO: modified to use $_[1]
    # local ($cmd_rx, *ref_contents) = @_;
    local ($cmd_rx) = @_;
    local($ref_before, $cmd , $pc_after);
    local($cmd_sub, $cmd_msub, $cmd_trans, $mathentity);
    local (@open_font_tags,@open_size_tags);
    $_[1] = &convert_iso_latin_chars($_[1])
	unless (($cmd =~ /(Make)?([Uu]pp|[Ll]ow)ercase/)||
	    ((!$cmd)&&($_[1] =~ /^\\(Make)?([Uu]pp|[Ll]ow)ercase/s)));

    local(@ref_processed);
    for (;;) {			# Do NOT use the o option
	last unless ($_[1] =~ /$cmd_rx/ );
	print ".";
	#JCL(jcl-del) - use new regexp form which handles white space
	($ref_before, $cmd, $pc_after) = ($`, $1.$2, $4.$');
	push(@ref_processed,$ref_before);
#print "\nAFTER:$1.$2:".$4."\n" if ($cmd_rx eq $single_cmd_rx);
	print STDOUT "$cmd" if ($VERBOSITY > 2);
	print STDOUT "\nIN: $_[1]\n" if ($VERBOSITY > 6);
	#
	if ( $cmd = &normalize($cmd,$pc_after) ) {
	    ($cmd_sub, $cmd_msub, $cmd_trans, $mathentity) =
		("do_cmd_$cmd", "do_math_cmd_$cmd"
		, $declarations{$cmd}, $mathentities{$cmd});
	    if ($new_command{$cmd}||$renew_command{$cmd}) { 
                # e.g. some \the$counter 
		local($argn, $body, $opt) = split(/:!:/, $new_command{$cmd});
		&make_unique($body) if ($body =~ /$O/);
		if ($argn) {
		    do { 
			local($before) = '';
			local($_) = "\\$cmd ".$pc_after;
			# &substitute_newcmd  may need what comes after the $cmd
			# from the value of $after 
			#RRM: maybe best to pass it as a parameter ?
			my $keep_after = $after;
			$after = $pc_after;
			$pc_after = &substitute_newcmd;   # may change $after
			$pc_after =~ s/\\\@#\@\@/\\/o ;
			$pc_after .= $after;
			$after = $keep_after;
		    }
		} else {
		    $pc_after = $body . $pc_after;
		}
	    } elsif (defined &$cmd_sub) {
		# $ref_before may also be modified ...
		if ($cmd =~ /$sizechange_rx/o) {
		    $pc_after = &$cmd_sub($pc_after, $open_tags_R);
		} else {
		    $pc_after = &$cmd_sub($pc_after, $open_tags_R);
		};
	    } elsif ((defined &$cmd_msub)&&!$NO_SIMPLE_MATH) {
#print "\nMCMD:$cmd_msub :  ";
		# $ref_before may also be modified ...
		$pc_after = &$cmd_msub($pc_after, $open_tags_R);
		if ( !$math_mode ) {
		    $pc_after = "<MATH>" . $pc_after . "</MATH>";
		    ++$commands_outside_math{$cmd};
		};
	    } elsif ($cmd_trans) { # One to one transform
#print "\nCMD-DECL: $inside_tabular : $cmd_trans". join(',',@$open_tags_R);
		if ($inside_tabular) {
		    push (@ref_processed , "\\$cmd ")
		} else {
		    $cmd_trans =~ m|</.*$|;
		    $pc_after = $` . $pc_after unless ($` =~ /^<>/);
		    push(@$open_tags_R, $cmd)
			if ($cmd =~ /$fontchange_rx|$fontweight_rx|$sizechange_rx/o);
		}
	    } elsif ($mathentity) {
#print "\nM-ENT:$mathentity :  ";
		if ( $math_mode ) {
		    $pc_after = "&$mathentity#$cmd;" . $pc_after;
		} elsif ($NO_SIMPLE_MATH) {
		    $pc_after = "&$mathentity#$cmd;" . $pc_after;
#		    ++$commands_outside_math{$cmd};
		} else {
		    $pc_after = "<MATH>&$mathentity#$cmd;</MATH>" . $pc_after;
		    ++$commands_outside_math{$cmd};
		}
	    } elsif ($ignore{$cmd}) { # Ignored command
		print "\nignoring \\$cmd" if $VERBOSITY > 5;
		$pc_after = join('', " ", $pc_after) if ($cmd eq " "); # catches `\ '
		$pc_after = join(''," ", $pc_after)
		    if (($cmd eq ',')&&($pc_after =~ /^\-/s)&&($ref_before =~/\-$/s));
	    } elsif ($cmd =~ /^the(.+)$/){
		$counter = $1;
		local($tmp)="do_cmd_$cmd";
		if (defined &$tmp) { # Counter
		    $pc_after = &do_cmd_thecounter($pc_after);
		} else {
		    if (defined $failed) {
			$failed = 1;
#			$ref_before .= "$cmd";
			push(@ref_processed,$cmd);  # $ref_before .= "$cmd";
		    } else {  &declare_unknown_cmd($cmd) }
#		    $ref_before .= "$cmd" if ($failed);
		}
	    } elsif ($cmd eq "\n") { push(@ref_processed," ");  # $ref_before .= " "; 
	    } else {
		# Do not add if reading an auxiliary file
		if (defined $failed) { 
		    $failed = 1;
		} else { &declare_unknown_cmd($cmd) }
	    }
	} else {
	    # &normalize should have already handled it adequately
	    # '\ ' (space) gets thru to here. Perhaps some others too ?
#	    print "\n ?? This should not happen: \\$cmd ??\n";
	}
#	$_[1] = join('', $ref_before, $pc_after);
	$_[1] = $pc_after;
	print STDOUT "\n-> $ref_before\n" if ($VERBOSITY > 6);
    }
    $_[1] = join('',@ref_processed).$_[1];
}

sub declare_unknown_cmd {
    local($this_cmd) = @_;
    local($tmp) = "wrap_cmd_$cmd";
    do { ++$unknown_commands{$cmd};
	print STDOUT "\n*** Unknown command[1]: \\$cmd *** \n" 
	    if ($VERBOSITY > 2);
    } unless ($AUX_FILE||(defined &$tmp)||($image_switch_rx=~/\b\Q$cmd\E\b/));
}


# This makes images from the code for math-entities,
# when $NO_SIMPLE_MATH is set and the  math  extension is loaded.
#
sub replace_math_constructions {
    local($math_mode) = @_;
    &make_math_box_images($math_mode) if (/<BOX>/);
    &make_math_entity_images($math_mode) if (/\&\w+#\w+;/);
}

sub make_math_box_images {
    local($math_mode) = @_;
    local($pre,$this,$post,$tmp) = ('','','');
    local($slevel,$blevel) = 0;

    while (/<BOX>/) {
	$pre .= $`; $tmp = $`; $this = ''; $post = $';	
	# compute the super/sub-scripting level for each entity
	$tmp =~ s/<(\/?)SU[BP]>/
	    if ($1) { $slevel--} else { $slevel++};''/eog;

	$tmp = $post;
	if ($tmp =~ /<(\/?)BOX>/o ) {
	    if ($1) { $this = $`; $post = $' }
	    else { $failed = 1 } # nested box, too complicated !
	} else {
	    &write_warnings("\nLost end of a <BOX> ?");
	    $failed = 1;
	}
	last if ($failed);

	($this,$_) = &process_box_in_latex(
		    $math_mode, $slevel, $this, $post);
	$_ =~ s/^\s*//; # remove any leading spaces
	$pre .= $this ."\001"; 
    }
    return  if ($failed);
    $_ = $pre . $_;
}

sub make_math_entity_images {
    local($math_mode) = @_;
    local($pre,$this,$post,$tmp) = ('','','');
    local($slevel) = 0;
    # compute the super/sub-scripting level for each entity
    while (/\&\w+#(\w+);/) {
	$pre .= $`; $tmp = $`; $this = $1; $post = $';
	$tmp =~ s/<(\/?)SU[BP]>/
	    if ($1) { $slevel--} else { $slevel++};''/eog; 
	($this,$_) = &process_entity_in_latex(
		$math_mode, $slevel, $this, $post);
	$_ =~ s/^\s*//; # remove any leading spaces
	$pre .= $this ."\001"; 
    }
    $_ = $pre . $_;
}


#RRM:  Revert a math-entity to create image using LaTeX, together with
# any super/sub-scripts (possibly nested or with \limits ).
# Must also get the correct  \display/text/(script)script  style.
#
sub process_entity_in_latex {
    local($mode,$level,$entity,$after) = @_;
    local($math_style,$supsub,$rest) = ('','','');
    $level++ if ($mode =~/box/); # for top/bottom of inline fractions, etc.

    if ($level) {
	$math_style = "\\". (($level > 1) ? "script" : "")."scriptstyle"
    } else {
	$math_style = "\\displaystyle" unless ($mode =~ /inline/);
    }
    while ($after =~ s/^\s*((\\limits|\&limits;)?\s*<SU(P|B)>)\s*/$supsub .= $1;''/eo) {
	local($slevel) = 1;
	local($aftersupb) = '';
	while ($slevel) {
	    $after =~ s/(<(\/)SU(B|P)>)/($2)? $slevel-- : $slevel++;''/oe;
	    $supsub .= $`.$&;
	    $aftersupb = $';
	}
	$after = $aftersupb;
    }

    local($latex_code) = "\$$math_style\\$entity$supsub\$";

    $global{'max_id'}++;
    ( &process_undefined_environment('tex2html_wrap_inline'
	     ,$global{'max_id'}, $latex_code ) , $after);
}

sub process_box_in_latex {
    local($mode,$level,$inside,$after) = @_;
    local($math_style,$which,$pre,$post,$tmp) = ('','',"\{","\}");
    
    if ($level) {
	$math_style = "\\". (($level > 1) ? "script" : "")."scriptstyle"
    } else {
	$math_style = "\\displaystyle" unless ($mode =~ /inline/);
    }

    if ($inside =~ /<((LEFT)|(RIGHT))>/ ) {
	$pre = "\\left"; $post = "\\right";
	if ($2) { 
	    $tmp = $`; $inside = $';
	    $pre .= (($tmp) ? $tmp : ".") . "\{";
	    if ( $inside =~ /<RIGHT>/ ) {
		$tmp = $';
		$inside = $`;
		$post = "\}". (($tmp) ? $tmp : ".");
	    }
	} else {
	    $pre .= ".\{"; $tmp = $'; $inside = $`;
	    $post = "\}". (($tmp) ? $tmp : ".");
	}
    }
    if ( $inside =~ /<((OVER)|(ATOP)|(CHOOSE))>/ ) {
	$pre .= $`;
	$post = $' . $post ;
	if ($2) { $which = "over " }
	elsif ($3) { $which = "atop " }
	elsif ($4) { $which = "atopwithdelims\(\)" }
    }

    local($latex_code) = join('', "\$" , $math_style , " ", $pre 
	  , (($which)? "\\$which" : "") , $post , "\$" );

    if ($after =~ s/<SUP ALIGN=\"CENTER\">([^<]*)<\/SUP>/
	$tmp =$1;''/eo ) {
	$latex_code = join('', "\\stackrel" , $latex_code
			   , "\{" , $tmp , "\}" );
    }
    
    $global{'max_id'}++;
    ( &process_undefined_environment('tex2html_wrap_inline'
	     ,$global{'max_id'}, $latex_code ) , $after);
}

####################### Processing Meta Commands ############################
# This is a specialised version of process_command above.
# The special commands (newcommand, newenvironment etc.)
# must be processed before translating their arguments,
# and before we cut up the document into sections
# (there might be sectioning commands in the new definitions etc.).
# \newtheorem commands are treated during normal processing by
# generating code for the environments they define.

sub substitute_meta_cmds {
    local ($next_def);
    local ($cmd, $arg, $argn, $opt, $body, $before, $xafter);
    local ($new_cmd_no_delim_rx, $new_cmd_rx, $new_env_rx, $new_cmd_or_env_rx);
    local ($new_end_env_rx);
    &tokenize($meta_cmd_rx);	#JCL(jcl-del) - put delimiter after meta command
    print "\nProcessing macros ..." if (%new_command || %new_environment);
    # First complete any replacement left-over from the previous part.
    if ($UNFINISHED_ENV) { 
	s/$UNFINISHED_ENV/$REPLACE_END_ENV/;
	$UNFINISHED_ENV = '';
	$REPLACE_END_ENV = '';
    }

    local(@processed);
    local($processed, $before, $after)=('', '', $_);
    while ($after =~ /$meta_cmd_rx$EOL/o) {	# ... and uses the delimiter
	($cmd, $after) = ($1.$2, $');
	$before .= $`;
#	$next_def = '';
	if (!($before =~ /$meta_cmd_rx$EOL/)) {
	    push(@processed, $before); $before = '';
	}
		 
	print ",";
#	$next_def = "\\$cmd" unless (($cmd =~ /renewcommand/));
	local($cmd_sub) = "get_body_$cmd";
	if (defined &$cmd_sub) {
#	    $processed = &$cmd_sub(*after);
	    $processed = &$cmd_sub(\$after);
#	    if ($processed) { $after = $before . $processed; }
#	    $next_def = '' 
#		if (($PREAMBLE > 1)&&($cmd =~ /(re)?newcommand/));
#	    &add_to_preamble($cmd, $next_def)
#		unless ($next_def =~ /^\s*$/);
### new style of handling meta-commands
	    if ($processed) { push(@processed, "\\".$processed) }
	}
	elsif ($before) {
	    # this shouldn't happen !!
	    print STDERR "\nCannot handle \\$cmd , since there is no $cmd_sub ";
	    $after = $before . $cmd . $after;
	    $before = '';
	} else { 
	    push(@processed, "\\$cmd ") if $cmd;
	}
    }
    print "\nmeta-commands: ". (0+@processed) ." found "
	if ((@processed)&&($VERBOSITY > 1));
    $_ = join('',@processed, $after); undef @processed;
    if ($PREAMBLE) {
	# MRO: replaced $* with /m
        s/((\n$comment_mark\d*)+\n)//gm;
        s/(\\par\b\s*\n?)+/\\par\n/gm;
        s/(\\par\b\n?)+/\\par\n/gm;
    }

    # hard-code the new-command replacements for these
    $new_command{'begingroup'} = "0:!:\\begin<<0>>tex2html_begingroup<<0>>:!:}";
    $new_command{'endgroup'} = "0:!:\\end<<0>>tex2html_begingroup<<0>>:!:}";
    $new_command{'bgroup'} = "0:!:\\begin<<0>>tex2html_bgroup<<0>>:!:}";
    $new_command{'egroup'} = "0:!:\\end<<0>>tex2html_bgroup<<0>>:!:}";

    # All the definitions have now moved to the $preamble and their bodies
    # are stored in %new_command and %new_environment
    #
    # Now substitute the new commands and environments:
    # (must do them all together because of cross definitions)
    $new_cmd_rx = &make_new_cmd_rx(keys %new_command);
    $new_cmd_no_delim_rx = &make_new_cmd_no_delim_rx(keys %new_command);
    $new_env_rx = &make_new_env_rx;
    $new_end_env_rx = &make_new_end_env_rx;
#    $new_cnt_rx = &make_new_cnt_rx(keys %new_counter);
    $new_cmd_or_env_rx = join("|", $new_cmd_no_delim_rx." ", $new_env_rx);
#    $new_cmd_or_env_rx = join("|", $new_cmd_no_delim_rx." ", $new_env_rx, " ".$new_cnt_rx);
    $new_cmd_or_env_rx =~ s/^ \||\|$//;

    print STDOUT "\nnew commands:\n" if ($VERBOSITY > 2);
    while (($cmd, $body) = each %new_command) {
	unless ($expanded{"CMD$cmd"}++) {
	    print STDOUT ".$cmd " if ($VERBOSITY > 2);
	    $new_command{$cmd} = &expand_body;
	    print STDOUT " ".$new_command{$cmd}."\n" if ($VERBOSITY > 4);
	    &write_mydb("new_command", $cmd, $new_command{$cmd});
	}
    }

    print STDOUT "\nnew environments:\n" if ($VERBOSITY > 2);
    while (($cmd, $body) = each %new_environment) {
	unless ($expanded{"ENV$cmd"}++) {
	    print STDOUT ".$cmd" if ($VERBOSITY > 2);
	    $new_environment{$cmd} = &expand_body;
	    &write_mydb("new_environment", $cmd, $new_environment{$cmd});
	}
    }

    print STDOUT "\nnew counters and dependencies:\n" if ($VERBOSITY > 2);
    &clear_mydb("dependent") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %dependent) {
	print STDOUT ".($cmd,$body)" if ($VERBOSITY > 2);
        &write_mydb("dependent", $cmd, $dependent{$cmd});
    }
    &clear_mydb("img_style") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %img_style) {
        &write_mydb("img_style", $cmd, $img_style{$cmd});
    }

    &clear_mydb("depends_on") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %depends_on) {
	print STDOUT ".($cmd,$body)" if ($VERBOSITY > 2);
        &write_mydb("depends_on", $cmd, $depends_on{$cmd});
    }


    &clear_mydb("styleID") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %styleID) {
        &write_mydb("styleID", $cmd, $styleID{$cmd});
    }

    &clear_mydb("env_style") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %env_style) {
        &write_mydb("env_style", $cmd, $env_style{$cmd});
    }
    &clear_mydb("txt_style") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %txt_style) {
        &write_mydb("txt_style", $cmd, $txt_style{$cmd});
    }

    print STDOUT "\ntheorem counters:\n" if ($VERBOSITY > 2);
    &clear_mydb("new_theorem") if ($DEBUG);     #avoids appending to a previous version
    while (($cmd, $body) = each %new_theorem) {
	print STDOUT ".($cmd,$body)" if ($VERBOSITY > 2);
        &write_mydb("new_theorem", $cmd, $new_theorem{$cmd});
    }


    print "+";
    if (length($new_env_rx)) {
	local(@pieces);
        print STDOUT "\nsubstituting new environments: $new_env_rx\n" if ($VERBOSITY > 3);
#	while (/\n?$new_env_rx/ && (($before, $cmd, $after) = ($`, $2, $'))) {
	while (/$new_env_rx/ && (($before, $cmd, $after) = ($`, $2, $'))) {
	    print STDOUT ",";
	    print STDOUT "{$cmd}" if ($VERBOSITY > 1);
	    if (!($before =~ /$new_env_rx/)) {
		push (@pieces, $before); $before = ''; print "{}";
	    }
	    $_ = join('',$before, &substitute_newenv);
	}
	print "\n ".(0+@pieces). " new environments replaced\n" if (@pieces);
	$_ = join('', @pieces, $_); undef @pieces;	
    }


    print "+";
    if (length($new_cmd_rx)) {
	print STDOUT "\ntokenizing: $new_cmd_rx\n" if ($VERBOSITY > 2);
	&tokenize($new_cmd_rx); # Put delimiter after the new commands

	# and use the delimiter.
	print STDOUT "\nsubstituting new commands: $new_cmd_rx\n" if ($VERBOSITY > 2);
	print STDOUT "\ninitial size: ".length($after) if ($VERBOSITY > 1);
	# store processed pieces in an array
	local($this_cmd, @pieces);
	# speed-up processing of long files by splitting into smaller segments
	# but don't split within the preamble, else \newenvironment may break
	local($pre_segment,@segments); &make_sections_rx;
	local($within_preamble,$this_section) = 1 if ($PREAMBLE>1);
	while (/$sections_rx/) {
	    $pre_segment .= $`; $_ = $'; $this_section = $&;
	    do {
		push(@segments,$pre_segment);
		$pre_segment = '';
	    } unless ($within_preamble);
	    $within_preamble = 0 if ($within_preamble && ($pre_segment =~ 
		    /\\(startdocument|begin\s*($O\d+${C})\s*document\s*\2)/));
	    $pre_segment .= $this_section;
	}
	push(@segments,$pre_segment.$_);
	local($replacements,$seg) ; $before = ''; # count the segments
	local($within_preamble) = 1 if ($PREAMBLE>1);
	foreach $after (@segments) {
	  while ($after =~ /(\\(expandafter|noexpand)\b\s*)?$new_cmd_no_delim_rx\b\s?/) {
	    ($before, $xafter, $cmd, $after) = ($`, $2, $3, $');
	    $within_preamble = 0
		if ($before =~ /\\(startdocument|begin\s*($O\d+${C})\s*document\s*\2)/);
	    push(@pieces, $before);
	    print "."; ++$replacements;
	    print STDOUT "$cmd" if ($VERBOSITY > 2);
	    if ($xafter =~ /no/) { $this_cmd = "\\\@#\@\@".$cmd  }
	    elsif (($xafter =~ /after/)&&($after =~ /^\s*\\/)) {
		local($delayed) = $cmd;
		local($nextcmd);
		$after =~ s/^\s*\\([a-zA-Z]+|.)/$nextcmd = $1;''/eo;
		($cmd,$nextcmd) = ($nextcmd, "do_cmd_$nextcmd");
		if (defined &$nextcmd) { $after = &$nextcmd($after); }
		elsif ($new_command{$cmd}) { 
		    local($argn, $body, $opt) = split(/:!:/, $new_command{$cmd});
		    &make_unique($body) if ($body =~ /$O/);
		    if ($argn) {
			do { 
			    local($before) = '';
			    $after = join('',&substitute_newcmd, $after);
			    $after =~ s/\\\@#\@\@/\\/o ;
			};
		    } else { $after = $body . $after; }
		} else { print "\nUNKNOWN COMMAND: $cmd "; }
		$cmd = $delayed;
		if ($new_command{$cmd}) {
		    if ($renew_command{$cmd}) {
#			# must wrap it in a deferred environment
#			$this_cmd = join('', &make_deferred_wrapper(1)
#				,"\\$cmd".(($cmd =~ /\w$/)? " ":'')
#				, &make_deferred_wrapper(0));
#			push(@pieces, $this_cmd); $this_cmd = '';
			push(@pieces, "\\$cmd".(($cmd =~ /\w$/)? " ":''));
			$this_cmd = '';
		    } elsif ($provide_command{$cmd}&&$within_preamble) {
			# leave it alone
			push(@pieces, "\\$cmd".(($cmd =~ /\w$/)? " ":''));
			$this_cmd = '';
		    } else {
			# do the substitution
			$this_cmd = &substitute_newcmd;
		    }
		}
	    } elsif ($renew_command{$cmd}) {
		# leave it alone
		push(@pieces, "\\$cmd".(($cmd =~ /\w$/)? " ":''));
		$this_cmd = '';
	    } elsif (($provide_command{$cmd})&&($within_preamble)) {
		# leave it alone
		push(@pieces, "\\$cmd".(($cmd =~ /\w$/)? " ":''));
		$this_cmd = '';
	    } else {
		# do the substitution
		$this_cmd = &substitute_newcmd if ($new_command{$cmd});
	    }
	    if ($this_cmd =~ /(\\(expandafter|noexpand)\s*)?$new_cmd_no_delim_rx\b\s?/)
	        { $after = $this_cmd . $after }
	    elsif ($this_cmd) { push(@pieces, $this_cmd) }
	  }
	  push(@pieces, $after);
	}
	print " $replacements new-command replacements\n"
	    if (($VERBOSITY>1) && $replacements);
	# recombine the processed pieces
	$_ = join('', @pieces); undef @pieces;
        print STDOUT ", resulting size: ".length($_)." " if ($VERBOSITY > 1);
	$_ =~ s/\\\@#\@\@/\\/go;
    }

    print STDOUT "\n *** substituting metacommands done ***\n" if ($VERBOSITY > 3);
}

sub insert_command_expansion {
    ($xafter, $cmd) = @_;
#   push(@pieces, $_[1]);
    print ".$cmd";
    print STDOUT "$_[3]" if ($VERBOSITY > 2);
#   $xafter = $_[2];
#   $cmd = $_[3];
    if ($xafter =~ /no/) { $this_cmd = "\\\@#\@\@".$cmd }
    elsif (($xafter =~ /after/)&&($after =~ /^\s*\\/)) {
	local($delayed,$nextcmd) = ($_[3],'');

	$after =~ s/^\s*\\([a-zA-Z]+|.)/$nextcmd = $1;''/eo;
	($cmd,$nextcmd) = ($nextcmd, "do_cmd_$nextcmd");
	if (defined &$nextcmd) { $after = &$nextcmd($after); }
	elsif ($new_command{$cmd}) { 
	    local($argn, $body, $opt) = split(/:!:/, $new_command{$cmd});
	    &make_unique($body) if ($body =~ /$O/);
	    if ($argn) {
		do { 
		    local($before) = '';
		    $after = join('',&substitute_newcmd, $after);
		    $after =~ s/\\\@#\@\@/\\/o ;
		};
	    } else { $after = $body . $after; }
	} else { print "\nUNKNOWN COMMAND: $cmd "; }
	$cmd = $delayed;
	$this_cmd = &substitute_newcmd if ($new_command{$cmd});		
    } else {
	$this_cmd = &substitute_newcmd if ($new_command{$cmd});
    }
#   if ($this_cmd =~ /(\\(expandafter|noexpand)\s*)?$new_cmd_no_delim_rx\s?/){
#	$after = $this_cmd . $after
#   } else { push(@pieces, $this_cmd); }
    $this_cmd;
}


sub expand_body {
    return unless length($new_cmd_or_env_rx);
    local($_) = $body;
    local($cmd,$saveafter,$avoid_looping);
    # Uses $before, $body, $arg, etc. of the caller, but not $cmd.
    # Uses $new_cmd_rx (resp. $new_cmd_no_delim_rx) and $new_env_rx
    # set in the caller, of which one might be empty.

    # Puts delimiter after the new commands ...
    &tokenize($new_cmd_rx) if length($new_cmd_rx);

    while (/$new_cmd_or_env_rx/) {
	# $new_cmd_rx binds $1, and $new_env_rx binds $3.
	($before,$cmd,$after,$saveafter) = ($`,$1.$3,$',$');
	if (length($new_command{$cmd})) { # We have a command
	    # this tokenizes again
	    local($replace) = &substitute_newcmd; # sets $_, changes $after
	    if (!($replace)) {
		# protect name of unexpanded macro
		$_ = join('', $before ,"\\@#@@", $cmd, $saveafter );
	    } else {
		$_ = join('', $before , $replace, $after );
	    }
	} elsif (length($new_environment{$cmd})) {
	    $_ = join('',$before, &substitute_newenv);
	}
	last if $avoid_looping;
    }
    # remove protection from unreplaced macro names
    s/\\\@#\@\@/\\/go;

    # remove trivial comments
    s/(\\\w+)$comment_mark\d*\n[ \t]*/$1 /go;
    s/$comment_mark\d*\n[ \t]*//go;
#    s/($O\d+$C)?($comment_mark\n)[ \t]*/($1 ? $1.$2 : '')/eg;

    $_;
}


sub substitute_newcmd {
    # Modifies $after in the caller
    # Get the body from the new_command array
    local($tmp,$cnt,$saved, $arg, $isword) = ('',0,$cmd);
    local($argn, $_, $opt) = split(/:!:/, $new_command{$cmd});
    $avoid_looping = 1 if ($new_command{$cmd} =~ /\\$cmd\b/);

    &tokenize($new_cmd_rx); # must do it again for newly inserted cmd bodies
    print STDOUT "\nNEW:$cmd:$_" if ($VERBOSITY > 5);
    foreach $i (1..$argn) {
	$arg = $isword = '';
	if ($i == 1 && $opt ne '}') {
	    $arg = ($after =~ s/$optional_arg_rx//o) ? $1 : $opt;
	}
	else {
	    # Get the next argument, if not in braces, get next character
	    #RRM: allow also for processed braces, in case substitution
	    #     was delayed; e.g. by \renewcommand
	    if (!(($after =~ s/$next_pair_rx/$arg = $2;''/e)
		  ||($after =~ s/$next_pair_pr_rx/$arg = $2;''/e))) {
		$after =~ s/^\s*(\\[a-zA-Z]+|.)/$arg = $1;''/e;
	    }
	    if ($arg eq '#') { 
		&write_warnings("\nSubstitution of arg to $cmd delayed."); 
		$_ = "\\\@#\@\@$saved";
		return ();
	    };
	}
	$arg =~ s/(^|\G|[^\\])\\\#/$1$hash_mark/gs;
	$arg =~ s/\#/$param_mark/gs;

	#RRM: Substitute the arguments in the body one at a time
	#     else multiple instances would fail in  &make_unique

	# First protect ## parameters in TeX-like substitutions
	# suggested by Dirk Pleiter (Berlin)
	s/((^|[^\\])(\\\\)*)\#\#$i/$1$protected_hash/gs;
	$tmp = $_;
	$cnt = $tmp =~ s/\#$i//g ;
	$isword = 1 if ($arg =~ /^\w/);
	if ($cnt > 1 ) {
	    $tmp = $_;
	    while ($cnt > 1) {
		if ( s/(\\\w+)?\#$i/(($1&&$isword)? $1.' ': '').$arg/e) { 
		    &make_unique($_) if ($arg =~ /$O/ ); 
		    &make_unique_p($_) if ($arg =~ /$OP/ );
		}
		$cnt--;
	    }
	    $tmp = $_;
	}
#	s/(\\\w+)?\#$i/(($1&&$isword)? $1.' ': '').$arg/e ;
	s/(\\\w+)?\#$i/$1.(($1&&$isword)? ' ': '').$arg/e ;
	print "\n *** substitution: $arg \nfor \#$i in \\$cmd did not take ***\n"
	   if (/\#$i/);
	&write_warnings("incomplete substitution in a \\$cmd command:\n$_") if (/\#$i/);
	s/$protected_hash/\#$i/g;
    }
    s/$param_mark/\#/g;
    s/$hash_mark/\\\#/g;
    s/(\\\w+)$/$1 /s;

    # Make the body unique (give unique id's to the brackets),
    # translate, and return it
    &make_unique($_);
    if ($avoid_looping) {
	s/\\$cmd\b/\\csname $cmd\\endcsname/g;
	print STDERR "\n *** possible looping with new-command \\$cmd ***\n";
	&write_warnings("\npossible looping with new-command \\$cmd ");
    }
    print STDOUT "\nOUT:$cmd:$_" if ($VERBOSITY > 5);

# Insert a space to prevent letters from clashing together with a
# letter command. Consider this:
# New command substitution is restricted to commands introduced by
# \newcommand etc. (so-called meta commands), but it is not done
# for already defined commands, eg. \large.
# But new command, as well as new environment, substitution is done
# prior to any other substitution.
# So \newcommand{\this}{...} {\large\this b} will get expanded the
# following way:
# 1. \newcommand{\this}{...}
#    is handled by &substitute_meta_cmds, it gets the definition
#    of \this and stores it within a table, %new_command.
#    After all new commands are recognized, &expand_body is called
#    to expand one command body from each other. That's O(n*n)!
# 2. A regular expression $new_cmd_rx is built containing a pattern
#    that matches all occurrences of a properly delimited \this
#    macro. When matching, ensuing white space gets lost.
#    (But only for letter commands, see also &make_new_cmd_rx.)
#    Another regular expression called $new_cmd_no_delim_rx is built
#    which matches exact the \this, and would also match the prefix
#    of \thisx.
# 3. The *whole* text is tokenized using $new_cmd_rx, with separates
#    \this from the ensuing text by one white space.
# 4. Then $new_cmd_no_delim_rx together with the delimiting space
#    is used to substitute \this with its body.
# 5. The following situations may occur:
#  a) ... is some text (no macros) => {\large<text>yyy}
#     Then we must prevent that the text clashes into \large.
#     This is only dangerous when <text> begins with a letter.
#  b) ... contains another, not expanded new command.
#     This happens during &expand_body.
#     In this case, make sure to &tokenize the body before giving
#     the result to the caller. Also take care that leading letters
#     of the body cannot clash into \large.
#  e) ... contains a macro not known as new command:
#     Make sure that the macro cannot clash with the ensuing yyy.
#  f) ... is empty:
#     Make sure that \large cannot clash with yyy.
# 6. We prevent clashing by inserting a delimiting blank.
#    Out of the scetched situation, there are three conditions to
#    take care of:
#  a) empty body, left a letter command, right a letter => blank
#  b) body starts with letter, left a letter command    => blank
#  c) body ends with letter command, right a letter     => blank
#  d) else => no blank, clash all together, it will work.
# 7. With this rules, the expansion should work quite well,
#    concerning letter/non-letter commands and white space
#    handling.
# 8. Deficiencies:
# 8.1 Consider \this<CR>that. It's handled this way:
#  a) The \this swallows the <CR> in LaTeX, but what LaTeX2HTML does
#     is to &tokenize the expression into \this <CR>that.
#  b) If ... is some text, it results in <text><CR>that.
#  c) If ... is a macro (or command, or control sequence, these
#     terms are often mixed up, but effectively mean the same),
#     then if the macro later takes at least one argument, the <CR>
#     might get swallowed, this depends on the grace of $next_pair_rx
#     resp. $next_pair_pr_rx.
#     If the macro takes no arguments, the <CR> remains in the text.
#  d) If ... ends in another new command, the problem repeats.
# 8.2 The new commands are substituted in a very insensitive way.
#     If \this occurs within an environment which sees \this
#     totally different, there's no chance to substitute \this in
#     a different way.
# 8.3 In relation to 8.2 a similar problem arises when the meta
#     command, or several meta commands redefining \this, occur
#     amongst several \this macros.
# 8.4 In raw TeX like environments it is not possible to revert the
#     expansion of \this, but \this probably *must* occur in its
#     raw form.

# Handle the cases as depicted in the description of new command
# substitution.
    local($befdel,$aftdel);
    $befdel = ' '
	if ($before=~/(^|[^\\])\\[a-zA-Z]+$/ && /^$/ && $after=~/^[a-zA-Z]/) ||
	    ($before=~/(^|[^\\])\\[a-zA-Z]+$/ && /^[a-zA-Z]/);
    $aftdel = ' '
	if /(^|[^\\])\\[a-zA-Z]+$/s && $after=~/^[a-zA-Z]/;
    join('', $befdel, $_, $aftdel);
}

#RRM:  use this to test whether a specific command is substituting correctly
sub trace_cmd {
    local($this) = @_;
    if ($cmd eq $this) { print "\n$1=>$id:$2::"}
}

# Make the text unique (give unique id's to the brackets).
# The text shouldn't contain processed brackets.
sub make_unique {
    # MRO: Change to references $_[0]
    # local(*_) = @_;
    my $id = $global{'max_id'};
    # MRO: replaced $* by /m
    # this looks quite funny but is optimized
    1 while($_[0] =~ s/$O(\d+)$C([\w\W]*)$O\1$C/$id++;"\000$id $2\000$id "/geom);
    $_[0] =~ s/\000(\d+) /$O$1$C/gom;
    $global{'max_id'} = $id;
}

#RRM: this shouldn't be needed, but just in case...
sub make_unique_p {
    # MRO: Change to references $_[0]
    my $id = $global{'max_id'};
    # MRO: replaced $* by /m
    # this looks quite funny but is optimized
    1 while($_[0] =~ s/$OP(\d+)$CP([\w\W]*)$OP\1$CP/$id++;"\000$id $2\000$id "/geom);
    $_[0] =~ s/\000(\d+) /$OP$1$CP/gom;
    $global{'max_id'} = $id;
}


sub substitute_newenv {
    # Modifies $cmd and $after in the caller
    # Get the body from the new_environment array
    local($argn, $begdef, $enddef, $opt) = split(/:!:/, $new_environment{$cmd});
    local($arg,$new_def_rx,$tmp,$cnt);

    # Note that latex allows argument substitution only in the
    # \begin part of the new definition
    foreach $i (1..$argn) {	# Process the arguments
	if (($i == 1) && ($opt ne '}')) {
	    $after =~ s/$optional_arg_rx/$arg = $1;''/eo;
	    $arg = $opt unless $arg;
	}
	else {
	    $after =~ s/$next_pair_rx/$arg = $2;''/eo;
	}
	$arg =~ s/(^|[^\\])\\\#/$1$hash_mark/g;
	$arg =~ s/\#/$param_mark/g;

        #RRM: multiple instances can fail later in  &make_unique
#       s/\#$i/$arg/g;          # Substitute the arguments in the body
        #RRM: ...so do one at a time and  &make_unique_p
        $tmp = $begdef;
        $cnt = $tmp =~ s/\#$i//g ;
        if ($cnt > 1) {
            $tmp = $begdef;
            while ($cnt > 1) {
		if ( $begdef =~ s/\#$i/$arg/) { 
		    &make_unique($begdef) if ($arg =~ /$O/ ); 
		    &make_unique_p($begdef) if ($arg =~ /$OP/ );
		}
                $cnt--;
            }
            $tmp = $_;
        }
        $begdef =~ s/\#$i/$arg/ ;
        print "\n *** substitution: $arg \nfor \#$i in {$cmd} did not take ***\n"
           if ($begdef =~ /\#$i/);
	&write_warnings("incomplete substitution in a {$cmd} environment:\n$begdef")
	    if ($begdef =~ /\#$i/);
    }
    $begdef =~ s/$param_mark/\#/g;
    $begdef =~ s/$hash_mark/\\\#/g;
    $begdef =~ s/(\\\w+)$/$1 /s;

    # Make the body unique (Give unique id's to the brackets),
    # translate, and return it
#RRM: when are these needed ?
#    $_ = &revert_to_raw_tex($_);
#    &pre_process;

    &make_unique($begdef);		# Make bracket IDs unique   
    print STDOUT "\nBEGIN:$cmd:$begdef" if ($VERBOSITY > 4);

    # Now substitute the \end part:
#RRM: when are these needed ?
#    $_ = &revert_to_raw_tex($enddef);
#    &pre_process;

    &make_unique($enddef);		# Make bracket IDs unique
    print STDOUT "\nEND:$cmd:$enddef" if (($enddef)&&($VERBOSITY > 4));
    $enddef =~ s/(\\\w+)$/$1 /s;

    local($new_end_def_rx) = &make_end_env_rx($cmd);
    if (($enddef)&&!($after =~ s/\n?$new_end_def_rx/$enddef/ )) {
        $UNFINISHED_ENV = $new_end_def_rx;
        $REPLACE_END_ENV = $enddef;
    };
    join('',$begdef,$after);
}

sub substitute_pars {
    s/((\%|$comment_mark\d*)|.)(\r*\n[ \t]*){2,}[ \t]*/$1\n\\par \n/og;
#    s/((\%|$comment_mark\d*)|\d|.)[\r\n\015]{2,}/print "\nPAR:".$`.$&;"$1\n\\par \n"/egs;
}

sub do_cmd_end { #RRM:  catches the end of any unclosed environments
    local($_) = @_;
    &missing_braces unless (
	(s/$next_pair_pr_rx//o)||(s/$next_pair_rx//o));
    s/^\n//;
    $_;
}

# Removes the definition from the input string, 
# adds to the preamble unless it is part of the preamble already
# and stores the body in %new_command;
sub get_body_newcommand {
    local($newed, $n_after) = &process_body_newcommand(0,@_);
    (($PREAMBLE)? "newed".$newed : '');
}

sub process_body_newcommand {
#    local($renewed,*_) = @_;
    local($renewed,$after_R) = @_;
    local($_) = $$after_R;
    local($no_change) = $_;
    local($argn,$newcmd,$cmd_br,$body,$body_br,$tmp,$tmp1,$opt,$pat);
    local($new_cmd) = 'command';
    if ($renewed =~ /provide/||$renewed == 2) {
	# $newcmd = &missing_braces unless (
	($newcmd,$pat) = &get_next(1) unless (
	        (s/$next_pair_pr_rx/$pat=$&;$newcmd=$2;''/e)
	        ||(s/$next_pair_rx/$pat=$&;$newcmd=$2;''/e));
	if (!$pat) {
	    local($br_id) = ++$global{'max_id'};
	    $pat = "$O$br_id$C".$newcmd."$O$br_id$C";
	}
    } else {
	($newcmd,$pat) = &get_next(1); # Get command name
    }
    $pat =~ s/\\//; $new_cmd .= $pat;
    $newcmd =~ s/^\s*\\//;
    ($argn,$pat) = &get_next(0);	# Get optional no. of args
    $argn = 0 unless $argn; $new_cmd .= $pat if $argn;
    local($cmd) = $newcmd;

    # Get the body of the code and store it with the name and number of args
    # UNLESS THE COMMAND IS ALREADY DEFINED
    # ...in which case $ALLOW_REDEFINE must also have been set.  # RRM
    # (This is the mechanism with which raw html can be ignored in a Latex document
    # but be recognised as such by the translator).
    $opt = '}';			# Flag for no optional arg
    local($bodyA) = '';
    if (/^\[/) {
	($opt,$pat) = &get_next(0);
	$new_cmd .= $pat;
	$bodyA .= "\n".'($dummy, $pat) = &get_next_optional_argument;' .
                    "\n". '$args .= $pat;';
    }
    local($nargs) = $argn;
    while ($nargs > 0) { $nargs--;
	$bodyA .=
	    "\n".'$args .= $`.$& if ((s/$next_pair_pr_rx//o)||(s/$next_pair_rx//o));';
    }
    if ($renewed =~ /provide/||$renewed == 2 ) {
        $body = &missing_braces unless (
	        (s/$next_pair_pr_rx/$pat=$&;$body=$2;''/e)
	        ||(s/$next_pair_rx/$pat=$&;$body=$2;''/e));
	$new_cmd .= $pat;
    } else {
	($body,$pat) = &get_next(4);  #get the body
	$new_cmd .= $pat;
    }

    local($thisone);
#    $thisone = 1 if ($cmd =~ /div|vec/);  # for debugging

    $tmp = "do_cmd_$cmd";
    local($wtmp) = "wrap_cmd_$cmd";
    if ((defined &$tmp)||(defined &$wtmp)){
	# command already exists, so \providecommand  does nothing
	# but may still be needed in  images.tex
	$$after_R = $_;
	return ($new_cmd) if ($renewed =~ /provide/);

	print "\n*** redefining \\$cmd ***\n";
	&write_warnings("\nredefining command \\$cmd ");
	if (!$ALLOW_REDEFINE) {
	    print "*** overriding previous meaning ***\n";
	    &write_warnings("\nprevious meaning of \\$cmd will be lost");
	}
#	local($code) = "undef \&$tmp"; eval ($code);
#	if ($@) {print "\n*** undef \&$cmd failed \n"}
	if ((!$PREAMBLE)||($renewed>1)) {
	    $new_command{$cmd} = join(':!:',$argn,$body,$opt);
#	    local($code) = "sub $tmp\{\&replace_new_command(\"$cmd\");\}";
#	    eval $code;
#	    print STDERR "\n*** sub do_cmd_$cmd failed:\nPERL: $@\n" if ($@);
#	    &replace_new_command($cmd);
	}

	$renew_command{$cmd} = 1;
	&write_mydb("renew_command", $cmd, $renew_command{$cmd});
        local($padding) = " ";
        $padding = '' if (($cmd =~ /\W$/)||(!$args)||($args =~ /^\W/));
        # Generate a new subroutine
        local($codeA) = "sub wrap_cmd_$cmd {" . "\n"
            .'local($cmd, $_) = @_; local ($args, $dummy, $pat) = "";'
            . $bodyA
	    . (($thisone)? "\nprint \"\\nwrap $cmd:\".\$args.\"\\n\";" : '')
            . "\n".'(&make_deferred_wrapper(1).$cmd.'
            . "\"$padding\"".'.$args.&make_deferred_wrapper(0),$_)}'
            . "\n";
        print "\nWRAP_CMD: $codeA " if ($thisone); # for debugging
        eval $codeA;
        print STDERR "\n\n*** sub wrap_cmd_$cmd  failed: $@\n" if ($@);
	$raw_arg_cmds{$cmd} = 1;

    } elsif (($ALLOW_REDEFINE)&&($PREAMBLE < 2)) {
	print "\n*** redefining \\$cmd ***\n";
	&write_warnings("\ncommand \\$cmd had no previous definition")
	    if (!($new_command{$cmd}));
    }
    if ($renewed && ($PREAMBLE > 1) &&($new_command{$cmd})) {
	$raw_arg_cmds{$cmd} = 1 ;
	$renew_command{$cmd} = 1;
        local($padding) = " ";
        $padding = '' if (($cmd =~ /\W$/)||(!$args)||($args =~ /^\W/));
        # Generate a new subroutine
        local($codeA) = "sub wrap_cmd_$cmd {" . "\n"
            .'local($cmd, $_) = @_; local ($args, $dummy, $pat) = "";'
            . $bodyA
	    . (($thisone)? "\nprint \"\\nwrap $cmd:\".\$args.\"\\n\";" : '')
            . "\n".'(&make_deferred_wrapper(1).$cmd.'
	    . "\"$padding\"".'.$args.&make_deferred_wrapper(0),$_)}'
            . "\n";
        print "\nWRAP_CMD: $codeA " if ($thisone); # for debugging
        eval $codeA;
        print STDERR "\n\n*** sub wrap_cmd_$cmd  failed: $@\n" if ($@);

	&write_mydb("renew_command", $cmd, $renew_command{$cmd});
    } elsif ($renewed) {
        $new_command{$cmd} = join(':!:',$argn,$body,$opt);
    } else {
	$new_command{$cmd} = join(':!:',$argn,$body,$opt)
	    unless (($PREAMBLE > 1)&&($renew_command{$cmd}));
    }

    local($this_cmd);
    $this_cmd = join(''
	, "command{\\$cmd}"
	, ($argn ? "[$argn]" :'') 
	, (($opt =~ /^}$/) ? '' : "[$opt]" )
	, "{", $body , "}" );
    $this_cmd = &revert_to_raw_tex($this_cmd);
    if ($renewed) {
	if ($renewed=~/provide/){
	    $provide_command{$cmd} = 1;
	    &write_mydb("provide_command", $cmd, $provide_command{$cmd});
#	} else {
#	    print "\n ** marking $cmd as renewed **";
#	    $renew_command{$cmd} = 1;
	};
	if ((!$PREAMBLE)&&($renewed>1)) {
#	    local($this_cmd) = join(''
#		, "\n\\renewcommand{\\$cmd}"
#		, ($argn ? "[$argn]" :'') 
#		, (($opt =~ /^}$/) ? '' : "[$opt]" )
#		, "{", $body , "}\n" );
#	    $latex_body .= &revert_to_raw_tex($this_cmd);
	    $latex_body .= "\n\\renew". $this_cmd."\n";
	} else {
##	    &add_to_preamble('command',"\\" . $this_cmd);
	}
    } else {
	&add_to_preamble('command',"\\new" . $this_cmd)
	    unless ($PREAMBLE);
    }
    undef $body;
    if ($renewed == 2) {
	# there is no output to return
	$$after_R = $_;
	return();
    } 

    if (!$PREAMBLE) {
	$$after_R = $_;
	return ($new_cmd) if ($renewed);
#	    $cmd_br =~ s/\\//;
#	( join ('', &make_deferred_wrapper(1)
#	    , "\\". ($renewed ? (($renewed =~ /provide/)? 'provid' : 'renew')
#		: 'new')."edcommand"
#	    , $cmd_br , ($argn ? "[$argn]" :'') 
#	    , ( ($opt =~ /^\}$/ ) ? '' : "[$opt]" ) , $body_br
#	    , &make_deferred_wrapper(0)) , $_ );
	$new_cmd = join('', "command{\\$cmd}"
			 , ($argn ? "[$argn]" :'') 
			 , (($opt =~ /^\}$/) ? '' : "[$opt]" )
			 , "{", $body , "}" );
	$new_cmd = &revert_to_raw_tex($new_cmd);
	&add_to_preamble('command', "\\provide".$new_cmd );
	$$after_R = $_;
	return();
    }
    $new_cmd =~ s/\\$cmd([\d\W]|$)/$cmd$1/s;
    $$after_R = $_;
    $new_cmd;
}

sub replace_new_command {
    local($cmd) = @_;
    local($argn, $body, $opt) = split(/:!:/, $new_command{$cmd});
    do { ### local($_) = $body;
	 &make_unique($body);
	 } if ($body =~ /$O/);
    $body =~ s/(^|[^\\])\~/$1\\nobreakspace /g;
    if ($argn) {
	do { 
	    local($before) = '';
	    local($after) = "\\$cmd ".$_;
	    $after = &substitute_newcmd;   # may change $after
	    $after =~ s/\\\@#\@\@/\\/o ;
	};
    } elsif ($body =~ /\\/) {
	$body = &translate_commands($body);  # ???
	$_ = $body . $_;
    } else { $_ = $body . $_; }
    $_;
}

sub get_body_let {
#    local(*_) = @_;
    local($_) = @_;
    local($cmd,$body,$replace,$tmp,$pat);
    ($cmd,$body) = &get_next_tex_cmd;
    s/^\s*=?\s*/$body .= $&;''/e;
    ($replace,$pat) = &get_next_tex_cmd;
#    return() if ($replace eq $cmd);
    $body .= $pat;
    $body = &revert_to_raw_tex($body);
    &add_to_preamble('', "\\let ".$body );
    $_[0] = $_;
    if (($replace eq $cmd)||($cmd="\\")||($cmd =~/(style|size)$/)) {
	"let ".$body
    } else {
	$new_command{$cmd} = join(':!:','',"\\$replace ",'}');
	'';
    }
}


#  do not remove the \renewcommand code, since it may be needed
#  within images. Instead replace it with \renewedcommand;
#  This will be reverted in &revert_to_raw_tex
sub get_body_renewcommand {
    local($ALLOW_REDEFINE) = 1;
    local($renew, $n_after) = &process_body_newcommand(1,@_);
    ($renew ? 'renewed' . $renew : '');
}

sub do_cmd_renewedcommand {
    local($_) = @_;
    local($ALLOW_REDEFINE) = 1;
    &process_body_newcommand(2,\$_);
    $_ ;
}

sub get_body_providecommand {
    local($provide, $n_after) = &process_body_newcommand('provide',@_);
    (($PREAMBLE && $provide) ? 'provided'.$provide : '');
}

sub do_cmd_providedcommand{ &do_cmd_renewedcommand(@_) }

sub get_body_DeclareRobustCommand {
    local($provide, $n_after) = &process_body_newcommand('provide',@_);
    (($PREAMBLE && $provide) ? 'provided'.$provide : '');
}

sub get_body_DeclareMathOperator {
    local($after_R) = @_;
    local($_) = $$after_R;
    my $star;
    s/^\\DeclareMathOperator\s*(\*|star)/$star = $1;''/s;
    my ($mcmd,$patA) = &get_next(1);
    my ($mop,$patB) = &get_next(1);
    if ($star) {
	$patA .= "${O}0$C\\mathop${O}1$C\\mathrm${patB}${O}1$C${O}0$C".$_;
    } else {
	$patA .= "${O}0$C${O}1$C\\mathrm${patB}${O}1$C${O}0$C".$_;
    }
    local($provide, $n_after) = &process_body_newcommand('provide',\$patA);
    $$after_R = $patA;
    (($PREAMBLE && $provide) ? 'provided'.$provide : '');
}

sub get_body_DeclareMathOperatorstar {
    local($after_R) = @_;
    local($_) = $$after_R;
    my $star;
    s/^\\DeclareMathOperator\s*(\*|star)/$star = $1;''/s;
    my ($mcmd,$patA) = &get_next(1);
    my ($mop,$patB) = &get_next(1);
    $patA .= "${O}0$C\\mathop${O}1$C\\mathrm${patB}${O}1$C${O}0$C".$_;
    local($provide, $n_after) = &process_body_newcommand('provide',\$patA);
    $$after_R = $patA;
    (($PREAMBLE && $provide) ? 'provided'.$provide : '');
}


# Removes the definition from the input string, adds to the preamble
# and stores the body in %new_environment;
sub get_body_newenvironment {
    local($newed,$after) = &process_body_newenvironment(0,@_);
    ( $PREAMBLE ? "newed".$newed : '');
}

sub process_body_newenvironment {
#    local($renew,*_) = @_;
    local($renew,$after_R) = @_;
    local($_) = $$after_R;
    local($no_change) = $_;
    local($argn,$env,$begin,$end,$tmp,$opt,$pat);
    local($new_env) = 'environment';
    if ($renew == 2) {
        $env = &missing_braces unless (
	        (s/$next_pair_pr_rx/$pat=$&;$env=$2;''/e)
	        ||(s/$next_pair_rx/$pat=$&;$env=$2;''/e));
	$new_env .= $pat;
    } else {
	($env,$pat) = &get_next(1);	# Get the environment name
	$env =~ s/^\s*\\//; $new_env .= $pat;
    }
    ($argn,$pat) = &get_next(0);	# Get optional no. of args
    $argn = 0 unless $argn; $new_env .= $pat if $argn;

    # Get the body of the code and store it with the name and number of args
    # UNLESS THE COMMAND IS ALREADY DEFINED (see get_body_newcommand)
    # ...in which case $ALLOW_REDEFINE must also have been set.  # RRM
    $opt = '}';			# Flag for no optional arg
    if (/^\[/) {
	($opt,$pat) = &get_next(0);
	$new_env .= $pat;
    }
    $tmp = "do_env_$env";

    if ($renewed == 2 ) {
        $begin = &missing_braces unless (
	        (s/$next_pair_pr_rx/$pat=$&;$begin=$2;''/e)
	        ||(s/$next_pair_rx/$pat=$&;$begin=$2;''/e));
	$new_env .= $pat;
	$end = &missing_braces unless (
	        (s/$next_pair_pr_rx/$pat=$&;$end=$2;''/e)
	        ||(s/$next_pair_rx/$pat=$&;$end=$2;''/e));
	$new_env .= $pat;
    } else {
	($begin,$pat) = &get_next(1); $new_env .= $pat;
	($end,$pat) = &get_next(1); $new_env .= $pat;
    }
    if ((defined &$tmp)&&($ALLOW_REDEFINE)) {
	print STDOUT "\n*** redefining environment {$env} ***\n";
	&write_warnings("\nredefined environment {$env} ");
    }
    $new_environment{$env} = join(':!:', $argn, $begin, $end, $opt)
	unless ((defined &$tmp)&&(! $ALLOW_REDEFINE));

    if (!$PREAMBLE) {
	$new_env = join ('', 
	    , "environment{$env}" 
	    , ($argn ? "[$argn]" : '')
	    , (($opt ne '}')? "[$opt]" : '')
	    , "{$begin}{$end}"
	    );
	&revert_to_raw_tex($new_env);
	if ($renew == 2) {
	    $latex_body .= "\n\\".($renew ? 're':'').'new'.$new_env."\n";
	} else {
	    &add_to_preamble ('environment'
		, "\\".($renew ? 're':'').'new'.$new_env );
	}
	$$after_R = $_;
	return();
    }
    if ($new_env =~ /$sections_rx/) {
    	$new_env = join('', $`,'\csname ',$2,'\endcsname',$3,$');
    }
    $new_env =~ s/$par_rx/\\par /g;
    $$after_R = $_;
    $new_env;
}

sub get_body_renewenvironment {
    local($ALLOW_REDEFINE) = 1;
    local($renewed, $after) = &process_body_newenvironment(1,@_);
    'renewed'.$renewed;
}

sub do_cmd_renewedenvironment {
    local($ALLOW_REDEFINE) = 1;
    local($_) = @_;
    &process_body_newenvironment(2,\$_);
    $_;
}

# Instead of substituting as with newcommand and newenvironment,
# or generating code to handle each new theorem environment,
# it now does nothing. This forces theorem environments to be passed
# to latex. Although it would be possible to handle theorem
# formatting in HTML as it was done previously it is impossible
# to keep the theorem counters in step with other counters (e.g. equations)
# to which only latex has access to. Sad...
sub get_body_newtheorem {
#    local(*_) = @_;
    local($after_R) = @_;
    local($_) = $$after_R;
    my ($orig, $body) = ($_, '');
    my ($title, $env, $ctr, $within, $cmd, $tmp, $begin, $end, $pat);
    my ($new_thm) = 'theorem';
    # Just chop off the arguments and append to $next_def
    ($env,$pat) = &get_next(1); $new_thm .= $pat;
    ($ctr,$pat) = &get_next(0); $new_thm .= $pat;
    ($title,$pat) = &get_next(1); $new_thm .= $pat;
    ($within,$pat) = &get_next(0); $new_thm .= $pat;

    #check the style parameters
    my ($hfont,$bfont,$thm_style);
    my ($before_thm) = join('',@processed);
    my ($which,$cmds);
    while ($before_thm =~ /$theorem_cmd_rx/) {
	$which = $1;
	$before_thm = $';
	$before_thm =~ s/$next_pair_rx/$cmds = $2;''/e;
	$cmds =~ s/\\/\|/g;  # escape any backslash
	if ($which =~ /style/) { $thm_style = $cmds }
	elsif ($which =~ /header/) { $hfont = $cmds }
	elsif ($which =~ /body/)   { $bfont = $cmds }
    }
    $hfont = '['.$hfont.']';
    $bfont = '['.$bfont.']';
    $thm_style = '['.$thm_style.']';
    undef $before_thm;

    if (!($ctr)) {
	# define the new counter
	$ctr = $env;
	do {
###	    local($_) = "\\arabic<<1>>$ctr<<1>>";
###	    $_ = join('',"\\the$within", "." , $_) if ($within);
	    $body = "\\arabic<<1>>$ctr<<1>>";
	    $body = join('',"\\the$within", "." , $body) if ($within);
	    &make_unique($body);
	    $cmd = "the$ctr";
	    $tmp = "do_cmd_$cmd";
	    do {
                $new_command{$cmd} = join(':!:',0,$body,'}') 
	    } unless (defined &$tmp);
	    &write_mydb("new_command", $cmd, $new_command{$cmd});
	    eval "sub do_cmd_$cmd {\n"
		. 'local($_,$ot) = @_;'."\n"
		. 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R;'."\n"
		. '&translate_commands(' . "\"$body\"" . ");\n}\n";
	    print STDERR "\n*** sub $tmp failed:\n$@\n" if ($@);
	    $raw_arg_cmds{$cmd} = 1;
	    undef $body;
	};
	&do_body_newcounter($ctr);
    } else {
	do {
###	    local($_) = "\\arabic<<1>>$ctr<<1>>";
	    $body = "\\arabic<<1>>$ctr<<1>>";
	    &make_unique($body);
	    $cmd = "the$env";
	    $tmp = "do_cmd_$cmd";
	    do {
                $new_command{$cmd} = join(':!:',0,$body,'}') 
	    } unless (defined &$tmp);
	    &write_mydb("new_command", $cmd, $new_command{$cmd});
	    eval "sub do_cmd_$cmd {\n"
		. 'local($_,$ot) = @_;'
		. 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R;'
		. '&translate_commands(' . "\"$body\"" . ");\n}\n";
	    print STDERR "\n*** sub $tmp failed:\n$@\n" if ($@);
	    $raw_arg_cmds{$cmd} = 1;
	    undef $body;
	};
    }

    # record the counter dependency
    &addto_dependents($within,$ctr) if ($within);

    # save the text-label in the %new_theorem hash
    $new_theorem{$env} = $title;

    # define a new environment
    my ($id) = ++$global{'max_id'};
    $begin = "\\begin<<$id>>theorem_type<<$id>>"
	. "[$env][$ctr][$within]$thm_style$hfont$bfont\n";
    $id = ++$global{'max_id'};
    $end = "\\end<<$id>>theorem_type<<$id>>\n";
    $tmp = "do_env_$env";
    if ((defined &$tmp)&&($ALLOW_REDEFINE)) {
	print STDOUT "\n*** redefining theorem environment {$env} ***\n";
    }
    $new_environment{$env} = join(':!:', '', $begin, $end, '')
	unless ((defined &$tmp)&&(! $ALLOW_REDEFINE));

    if (!$PREAMBLE) {
	my ($new_cmd) = join(''
	    , 'theorem{}' );
	&add_to_preamble('theorem', "\\new".$new_cmd );
	$$after_R = $_;
	return();
    }
    $$after_R = $_;
    'newed'.$new_thm;
}

sub do_cmd_theoremstyle {
    local($_) = @_;
    local($thm_type);
    $thm_type = &missing_braces unless (
	(s/$next_pair_pr_rx/$thm_type=$2;''/e)
	||(s/$next_pair_rx/$thm_type=$2;''/e));
#   $THM_STYLE = $thm_type;
    $_;
}
sub do_cmd_theoremheaderfont {
    local($_) = @_;
    local($thm_type);
    $thm_type = &missing_braces unless (
	(s/$next_pair_pr_rx/$thm_type=$2;''/e)
	||(s/$next_pair_rx/$thm_type=$2;''/e));
#   $THM_HFONT = $thm_type;
    $_;
}
sub do_cmd_theorembodyfont {
    local($_) = @_;
    local($thm_type);
    $thm_type = &missing_braces unless (
	(s/$next_pair_pr_rx/$thm_type=$2;''/e)
	||(s/$next_pair_rx/$thm_type=$2;''/e));
#   $THM_BFONT = $thm_type;
    $_;
}

sub do_env_theorem_type {
    local($_) = @_;
    local($dum,$env,$ctr,$within, $label, $name, $title, $text, $index);
    ($env, $dum) = &get_next_optional_argument;
    ($ctr, $dum) = &get_next_optional_argument;
    ($within, $dum) = &get_next_optional_argument;

    local($thm_num, $thm_style);
    # defaults for plain theorem-style
    my ($hfont,$bfont) = ('','');

    ($thm_style, $dum) = &get_next_optional_argument;
    ($hfont, $dum) = &get_next_optional_argument;
    $hfont =~ s/\|/\\/og;
    ($bfont, $dum) = &get_next_optional_argument;
    $bfont =~ s/\|/\\/og;

    # the pre-defined alternative theorem-styles
    if ($thm_style =~ /definition/) {
	$bfont = '\normalfont' unless $bfont;
    } elsif ($thm_style =~ /remark/) {
	$hfont = '\itshape' unless $hfont;
	$bfont = '\normalfont' unless $bfont;
    }

    # defaults for plain theorem-style
    $hfont = '\bfseries' unless $hfont;
    $bfont = '\itshape' unless $bfont;

    ($name, $dum) = &get_next_optional_argument;
    $name = &translate_environments("${O}0$C".$name."${O}0$C") if $name;
    $name = &translate_commands($name) if ($name =~ /\\/);

    $index = $section_commands{$ctr};
    if ($index) { 
	# environment actually starts a new (sub-)section
	$curr_sec_id[$index]++;
	local($this) = &translate_commands("\\the$ctr");
	local($hash) = &sanitize($name." $this");
	local($section_tag) = join('', @curr_sec_id);
	$encoded_section_number{$hash} = join($;, $section_tag);
	&reset_dependents($ctr) if ($dependent{$ctr});
	$thm_num = &translate_commands("\\the$ctr");
	$thm_num =~ s/(\w)\.(\.\w)/$1$2/g;

	# construct the sectioning title from the counter values
	$title = join( '', $new_theorem{$env}, " "
	    , &translate_commands("\\the$ctr") );
	$toc_section_info{join(' ',@curr_sec_id)} = \
	    "$current_depth$delim$CURRENT_FILE$delim$title"
		if ($current_depth <= $MAX_SPLIT_DEPTH + $MAX_LINK_DEPTH);
	$section_info{join(' ',@curr_sec_id)} = \
	    "$current_depth$delim$CURRENT_FILE$delim$title$delim";
	$title = join('',"<A NAME=\"SECTION$section_tag\"><B>"
		      , $title , "</B></A>" );
    } else {
	if ($ctr) {
	    print STDOUT "\nSTP:$ctr:+1" if ($VERBOSITY > 3);
	    $global{$ctr}++;
	    print STDOUT "=".$global{$ctr}." " if ($VERBOSITY > 3);
	    &reset_dependents($ctr) if ($dependent{$ctr});
	    $thm_num = "\\the$ctr ";
	} else { $thm_num = ''; }

	# construct the full title from the counter values
	$title = $new_theorem{$env};
	if (($thm_style =~ /margin/)&&($HTML_VERSION > 2.1)) {
	    # don't use the number yet
	} elsif ($thm_style =~ /change/) {
	    $title = join(' ', $thm_num, "\\space", $title)
	} else {
	    $title = join(' ', $title, "\\space", $thm_num);
	}

	if ($hfont) {
	    $title = join('',$O,++$global{'max_id'},$C,$hfont," "
		      , $title, $O,++$global{'max_id'},$C);
	    $title = &translate_environments($title);
	    $title = &translate_commands($title);
	} else {
	    $title = join('',"<B>",&translate_commands($title),"</B>");
	}
	$title =~ s/(\w)\.(\.\w)/$1$2/g;
    }
    # extract any name or label that may occur at the start
    s/^\s*(\\label(($O|$OP)\d+($C|$CP))([^<]*)\2)?\s*(\(([^\)]*)\))?/
	$label=$1; $text=$5; $name=$7 if ($7); ''/eo;
    if ($label) {
	$label = &anchor_label($text,$CURRENT_FILE,'');
	$label =~ s/$anchor_mark/$title/;
	$title = $label;
    }
    if ($name) {
	$name =~ s/^\s*|\s*$//g; 
	$name = join('', " (", $name, ") ") if $name;
    }
    local($attribs, $border);
    if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }

    $_ = join('', $O,++$global{'max_id'},$C, $bfont
	    , " ", $_ ,$O,++$global{'max_id'},$C) if ($bfont);

    my($cmd) = 'do_thm_'.$env;
    if (defined &$cmd) {
	$_ = &$cmd($ctr, $title, $_);
    } else {
	$_ = &translate_environments($_);
	$_ = &translate_commands($_);
    }

    if ($thm_style =~ /margin/) {
	local($valign);
	$valign = ($NETSCAPE_HTML ? ' VALIGN="BASELINE"':'');
	if ($hfont) {
	    $thm_num = join('',$O,++$global{'max_id'},$C,$hfont," "
		      , $thm_num, $O,++$global{'max_id'},$C);
	    $thm_num = &translate_environments($thm_num);
	    $thm_num = &translate_commands($thm_num);
	} else {
	    $thm_num = join('',"<B>",&translate_commands($thm_num),"</B>");
	}
	$thm_num =~ s/(\w)\.(\.\w)/$1$2/g;

	# code copied from  &make_table
	local($Tattribs);
	if ($attribs) {
	    if (!($attribs =~ /=/)) {
		$Tattribs = &parse_valuesonly($attribs,"TABLE");
	    } else {
		$Tattribs = &parse_keyvalues($attribs,"TABLE");
	    }
	    $Tattribs = ' '.$Tattribs if ($Tattribs);
	}
	$_ = join ('', "\n<P><DIV$env_id><TABLE"
		, (($border) ? " BORDER=\"$border\"" : '')
		, $Tattribs , ">\n<TR VALIGN=\"TOP\">"
		, "<TD$valign>", &translate_commands($thm_num)
		, "</TD>\n<TD>", $title, $name
		, (($thm_style =~ /break/)? "\n<BR>":" \&nbsp; \n")
		, $_ , "\n</TD></TR></TABLE></DIV>");
    } else {
	$_ = join('', "<P><DIV$env_id>"
		, $title, $name
		, (($thm_style =~ /break/)? "\n<BR>":" \&nbsp; \n")
		, $_
		,"</DIV><P></P>\n");
	if (($border||($attribs))&&($HTML_VERSION > 2.1 )) { 
	    &make_table( $border, $attribs, '', '', '', $_ ) 
	} else { $_ }
    }
}

# Modifies $_ in the caller and as a side-effect it modifies $next_def
# which is local to substitute_meta_cmds
sub get_next {
    local($what) = @_;
    local($next, $pat, $tmp);
    if ($what == 1) {
	($next, $tmp, $pat) = &get_next_argument;
    }
    elsif ($what == 2) {
	($next, $pat) = &get_next_tex_cmd;
    }
    elsif ($what == 3) {
	($next, $pat) = &get_next_def_arg;
    }
    elsif ($what == 4) {
	($next, $tmp, $pat) = &get_next_argument;
    }
    else {
	($next, $pat) =  &get_next_optional_argument;
    }
    do {
	$next_def .= &revert_to_raw_tex($pat) if $pat;
    } unless ($renewed); # don't add \renewcommand to preamble
#    $next =~ s/(^\s*)|(\s*$)//g unless ($what == 4); #don't lose white space on body
    $next =~ s/(^\s*)|(\s*$)//g unless ($what =~ /[14]/); #retain white space in body
    ($next, $pat);
}

# The following get_next_<something> ARE ALL DESTRUCTIVE.
sub get_next_argument {
    local($next, $br_id, $pat);
    if (!(s/$next_pair_rx/$br_id=$1;$next=$2;$pat=$&;''/seo)) {
	print " *** Could not find argument for command \\$cmd ***\n";
	print "$_\n";
    };
    ($next, $br_id, $pat);
}

sub get_next_pair_or_char_pr {
    local($next, $br_id, $pat, $epat);
    if ( /^\{([^\}]*)\}/o && (! $`)) {
	($next, $pat) = ($1, $&);
    } elsif ( (/^\s*([^\s\\<])/o && (! $`))) {
	($next, $pat) = ($1, $&);
    } elsif ( /$next_pair_pr_rx/o && (! $`)) {
	($next, $br_id, $pat) = ($2, $1, $&);
    };
    $epat = &escape_rx_chars($pat);
    s/$epat// if $pat;
    ($next, $br_id, $pat);
}

sub get_next_optional_argument {
    local($next, $pat);
    s/$optional_arg_rx/$next=$1;$pat=$&;''/eo
	if (/\s*[[]/ && (! $`)); # if the first character is a [
    #remove trailing spaces and/or comments
    s/^($comment_mark(\d+\n?)?|$EOL)//gos;

    # if  nested inside {}s  we need to get more tokens  
    if ($pat) {
	# check for \item, indicating something has gone wrong
	if ($pat =~ /\\item\b/ ) {
	    print "\n*** optional argument badly formed:\n" . $pat . "\n\n";
	    $_ = $pat . $_;
	    return('','');
	}
	# check for being nested inside {}s
	local($found) = $pat;
	while ($found =~ s/$O(\d+)$C[\s\S]*$O\1$C//g) {
	    if ($found =~ /$O(\d+)$C/) {
		local($br_id) = $1;
		if (s/$O$br_id$C//) {
		    $found .= $`.$&;
		    $pat .= "]".$`.$&;
		    $next .= "]".$`.$&;
		    $_ = $';
		    s/^([^]]*)\]/$next.=$1;$pat.=$&;''/e;
		    $found .= $&;
		} else { last } # give up if no closing brace
	    }
	}
    } else {
	s/^\s*\[\]/$pat=$&;''/e; # This is not picked by $optional_arg_rx
    }
    ($next, $pat);
}

#JCL(jcl-del) - use new form of $single_cmd_rx.
sub get_next_tex_cmd {
    local($next, $pat);
    s/^\s*\=?\s*$single_cmd_rx/$4/;
    ($next, $pat) = ($1.$2,"\\".$1.$2);
}

sub get_next_def_arg {
    local($next, $pat);

    # Sets is_simple_def for caller.  Start by turning it off, then
    # turn it on if we find one of the "simple" patterns.

    # This has got to be hit-or-miss to an extent, given the
    # thoroughly incestuous relationship between the TeX macroprocessor
    # ('mouth') and typesetting back-end ('stomach').  Anything which
    # even does catcode hacking is going to lose BAD.

    s/^\s*//so;			# Remove whitespace

    $is_simple_def = 0;

    # no arguments

    if (/^$O/ && (! $`)) { $next=0; $pat=''; $is_simple_def=1; }

    # 'simple' arguments

    if (! $is_simple_def && /$tex_def_arg_rx/o && (! $`)) {
	s/$tex_def_arg_rx/$next=$1; $pat=$&; $is_simple_def=1; $2/seo; }

    # MESSY arguments

    if (! $is_simple_def) {
 	print "Arguments to $cmd are too complex ...\n";
	print "It will not be processed unless used in another environment\n";
	print "which is passed to LaTeX whole for processing.\n";

	s/^[^<]*(<[^<]+)*<</$next=''; $pat=$&; $O/seo;
    }

    $pat =~ s/$O$//so;

    ($next, $pat);
}

#### Key-value parsing added by RRM
#
#   This cleans-up the key-value pairs for a given tag, 
#   by removing unnecessary spaces and commas, inserting quotes
#   around the value and puts a preceding space.
#   The key becomes upper-case, while the value becomes lower-case.
#   If specific `tags' are provided, then checking is done to verify 
#   that the keys and values are valid for these tags, eliminating
#   any that are not; unmatched keys or values are handled as well.
#   If no tags are provided, then just a list of pairs is returned.
#
sub parse_keyvalues {
    local($_,@tags) = @_;
    local($key,$KEY,$attribs,$atts,%attributes)=('','','','');

    # beware active " in german
    local($is_german);
    if (s/\&#34;/'/g) { 
	$is_german=1;
	s/(^|[\s,=])(\&\#\d\d\d;)/$1'$2/g
    }
    local($saved) = &revert_to_raw_tex(&translate_commands($_));
    print "\nATTRIBS: $saved\n" if ($VERBOSITY > 6);

    $saved =~ s/$percent_mark/%/g;
    $saved =~ s/((^|[\s,=])')\\\W{(\w)}/$1$3/g
	if $is_german;  #unwanted accents, from active "
    if (@tags) {
	foreach $tag (@tags) {
	    $_ = $saved;
	    local($name)= $tag."_attribs";
	    $taglist = $$name;
	    $name .= "_rx_list";
	    $taglist .= $$name;
	    $taglist =~ s/,,/,/;
#	    s/(^|,)\s*([a-zA-Z]+)\s*\=\s*"?([\#\%\w\d]+)"?\s*/$attributes{$2}="$3";''/eg;
#	    s/(^|,)\s*([a-zA-Z]+)\s*\=\s*(\"([^"]*)\"|\'([^\']*)\'|([#%\w\d]*))\s*/
#	    s/(^|,)\s*([a-zA-Z]+)\s*\=\s*(\"([^"]*)\"|\'([^\']*)\'|([#%&@;:+-\/\w\d]*))\s*/
	    s/(^|,)\s*([a-zA-Z]+)\s*\=\s*(\"([^"]*)\"|\'([^\']*)\'|([^<>,=\s]*))\s*/
		$attributes{$2}=($4?$4:($5?$5:$6));' '/eg;
	    foreach $key (keys %attributes){ 
		$KEY = $key;
		$KEY =~ tr/a-z/A-Z/;
		if ($taglist =~ /,$KEY,/i) {	        
		    local($keyname) = $tag."__".$KEY; 
		    local($keyvalues) = '';
		    if ($$keyname) {
			$keyvalues = $$keyname;
			$atts = $attributes{$key};
			if ($keyvalues =~ /\,$atts\,/i ) {
#			    $atts =~ tr/A-Z/a-z/;
			    $attribs .= " $KEY=\"$atts\"";
			    print "\n$KEY=$atts " if ($VERBOSITY > 3);
			} else { &invalid_tag($tag,$KEY,$atts); }
		    } else {	# test for a regular expression
		        $keyname = $keyname."_rx";
			if ($$keyname) {
			    $keyvalues = $$keyname;
			    $atts = $attributes{$key};
			    if ($atts =~ /$keyvalues/) {
#				$atts =~ tr/A-Z/a-z/;
				$attribs .= " $KEY=\"$atts\"";				
				print "\n$KEY=$atts " if ($VERBOSITY > 3);
			    } else { &invalid_tag($tag,$KEY,$atts) }
			} else {
			    $atts = $attributes{$key};
#			    $atts =~ tr/A-Z/a-z/;
			    $attribs .= " $KEY=\"$atts\"";
			    print "\n$KEY=$atts " if ($VERBOSITY > 3);
			}
		    }
		} else {
		    print "\n$key not in $taglist for $tag" if ($VERBOSITY > 3);
		}
	    }
	}
        s/(^|\s,)\'([^\s,]*)\'(\s|$)/$1$2 /g if $is_german;
	$attribs .= &parse_valuesonly($_,@tags);
    } else {
	# with no tags provided, just list the key-value pairs
	$_ = $saved;
	s/\s*(\w+)\s*=\s*\"?(\w+)\"?\s*,?/$attributes{$1}=$2;''/eg;
	foreach $key (keys %attributes){ 
	    $KEY = $key;
	    $KEY =~ tr/a-z/A-Z/;
	    $atts = $attributes{$key};
	    $atts =~ tr/A-Z/a-z/;
	    $attribs .= " $KEY=\"$atts\"";
	}
    }
    $attribs;
}

sub invalid_tag {
    local($tag,$key,$value) = @_;
    &write_warnings("$key=$value is an invalid value in the <$tag> tag\n");
}

# RRM
#   This creates key-value pairs from values only, 
#   by checking whether the data matches any key to the provided tags.
#   Only the first match found is retained.
#   Attributes with no values are also recognised here.
#
sub parse_valuesonly {
    local($values,@tags) = @_;
    local($i,$tag,$key,$KEY,$attribs,$atts)=(0,'','','','','');
    local($saved) = &revert_to_raw_tex(&translate_commands($values));
    $saved =~ s/$percent_mark/%/g;
    foreach $tag (@tags) {
	local($name)= $tag."_attribs";
	$taglist = $$name;
	$values = $saved;
        $values =~ s/\s*\"?([^,\s\"]+)\"?\s*,?/$i++;$attributes{$i}=$1;''/eg;
        local($j) = 0;
	while ($j < $i) {
	    $j++;
	    $key = $attributes{$j};
	    if ($taglist =~ /,$key,/i) {
		$KEY = $key;
		$KEY =~ tr/a-z/A-Z/;
		$attribs .= " $KEY";
		print " $KEY" if ($VERBOSITY > 3);
	    } else {
		$atts = $attributes{$j};
		$key = &find_attribute($key,$tag);
	        if ($key) {
		    $KEY = $key;
		    $KEY =~ tr/a-z/A-Z/;
		    $atts =~ tr/A-Z/a-z/;
	            $attribs .= " $KEY=\"$atts\"";
		    print " $KEY = $atts" if ($VERBOSITY > 3);
		} else { }
	    }
	}
    }
    $attribs;
}

# RRM
#   Extracts key-value pairs using a supplied (comma-separated) list.
#   When no list is given, it checks for a pre-defined list for the tag.
#   
sub extract_attributes {
    local($tag,$taglist,$_) = @_;
    local($key,$attribs,$unused,%attributes);
    if (! ($taglist)) {
	local($name) = "$tag"."_attribs";
	if ($$name) { $taglist = $$name }
    }
    s/\s*(\w+)\s*=\s*\"?(\w+)\"?\s*,?/$attributes{$1}=$2;''/eg;
    foreach $key (keys %attributes){ 
	if ($taglist =~ /\,$key\,/) {
	    $attribs .= " $key=\"$attributes{$key}\"";
	    &write_warnings("valid attribute $key for $tag\n");
	} else {
	    &write_warnings("unknown attribute $key for $tag\n");
	    $unused .= " $key=\"$attributes{$key}\"";
	}
    }
    ($attribs,$unused);
}

# RRM
#   Finds the attribute of a given tag, for which a given value is valid.
#   Requires variables: <tag>_<key> to be a comma-separated list of keys.
#   So far it cannot recognise data-types, only names.
#
sub find_attribute {
    local($key,$attrib,$tag) = ('',@_);
    local($name) = $tag."_attribs";
    local($attrib_list)=$$name;
    if ($attrib_list) {
	$attrib_list =~ s/^\,//o;
	$attrib_list =~ s/\,$//o;
	local(@keys) = split(',',$attrib_list);
	local($attrib_vals) = '';
	foreach $key (@keys) {
	    $name = $tag."__".$key;
	    $attrib_vals = $$name;
	    return ($key) if ($attrib_vals =~ /\,$attrib\,/i ); 
	}
    }
    $name = $tag."_attribs_rx_list";
    $attrib_list=$$name;
    if (!($attrib_list)) { return(); }
    $attrib_list =~ s/^\,//o;
    $attrib_list =~ s/\,$//o;
    @keys = split(',',$attrib_list);
    foreach $key (@keys) {
	next if ($attribs =~ / $key=/);
	$name = $tag."__".$key."_rx";
	$attrib_vals = $$name;
	if ( $attrib =~ /^$attrib_vals$/ ) { 
	    return ($key);
	}
    }
    0;
}

# in case \HTML is defined differently in packages
sub do_cmd_HTML { &do_cmd_HTMLcode(@_) }

sub do_cmd_HTMLcode {
    local($_) = @_;
    local($tag,$attribs,$dum);
    local($attribs, $dum) = &get_next_optional_argument;
    $tag = &missing_braces unless (
	(s/$next_pair_pr_rx/$tag = $2;''/eo)
	||(s/$next_pair_rx/$tag = $2;''/eo));
    $tag = &translate_commands($tag) if ($tag =~ /\\/);
    if (! $tag) {
	print "*** no tag given with \\HTML command, ignoring it";
	return($_);
    }
    local($afterHTML) = $_;
    local($value,$TAGattribs,$etag);
    if (defined $unclosed_tags_list{$tag}) {
    } elsif (defined $closed_tags_list{$tag}) {
	$value = &missing_braces unless (
	    (s/$next_pair_pr_rx/$value = $2;''/eo)
	    ||(s/$next_pair_rx/$value = $2;''/eo));
	$etag = "</$tag>";
	$afterHTML = $_;
    } else {
	print "\n*** <$tag> is not a valid tag for HTML $HTML_VERSION";
	print "\n rejecting: \\HTML".(($attribs)? "[$attribs]" : '')."{$tag}";
	return $_ ;
    }
    if ($dum) {
	$attribs = &translate_commands($attribs) if ($attribs=~/\\/);
        if ($attribs) {
            if (!($attribs =~ /=/)) {
                $TAGattribs = &parse_valuesonly($attribs,$tag);
            } else {
                $TAGattribs = &parse_keyvalues($attribs,$tag);
            }
        }
    } else { }  # default if no [...]
    local($needed) = join(','
	    , $closed_tags_list{$tag},$unclosed_tags_list{$tag});
    $needed =~ s/,,/,/g; $needed =~ s/^,|,$//g;
    if ($TAGattribs) {
	if ($needed) {
	    $needed =~ s/,,/,/g;
	    local($this, @needed);
	    (@needed) = split(',',$needed);
	    foreach $this (@needed) {
		next unless ($this);
		next if ($TAGattribs =~ /\b$this\b/);
		print "\n*** attribute $this required for <$tag> ***";
		print "\n rejecting: \\HTML".(($attribs)? "[$attribs]" : '')."{$tag}";
		return($value.$afterHTML);
	    }
	}
	$value = &translate_environments($value);
	$value = &translate_commands($value) if ($value =~ /\\/);
	$_ = join('', "<$tag", $TAGattribs, ">", $value, $etag);
   } elsif ($needed) {
	print STDOUT "\n*** attributes $needed are required for <$tag> ***";
	return($value.$after);
    } elsif ($value) {
	$value = &translate_environments($value);
	$value = &translate_commands($value) if ($value =~ /\\/);
	$_ = join('', "<$tag>", $value, $etag);
    } else {
	$_ = join('', "<$tag>", $etag);
    }
    $_.$afterHTML; 
}

sub do_cmd_HTMLget {
    local($_) = @_;
    local($which,$value,$hash,$dummy);
    local($hash, $dummy) = &get_next_optional_argument;
    $which = &missing_braces unless (
	(s/$next_pair_pr_rx/$which = $2;''/eo)
	||(s/$next_pair_rx/$which = $2;''/eo));
    if ($hash) {
	local($tmp) = "\%$hash";
	if (eval "defined \%{$hash}") { $! = '';
	    $value = ${$hash}{'$which'};
	} else { print "\nhash: \%$hash not defined" }
    } elsif ($which) {
	$value = ${$which};
    }
    $value.$_;
}

sub do_cmd_HTMLset {
    local($_) = @_;
    local($which,$value,$hash,$dummy);
    local($hash, $dummy) = &get_next_optional_argument;
    $which = &missing_braces unless (
	(s/$next_pair_pr_rx/$which = $2;''/eo)
	||(s/$next_pair_rx/$which = $2;''/eo));
    $value = &missing_braces unless (
	(s/$next_pair_pr_rx/$value = $2;''/eo)
	||(s/$next_pair_rx/$value = $2;''/eo));
    if ($hash) {
	local($tmp) = "\%$hash";
	if (eval "defined \%{$hash}") { $! = '';
#	    eval "\$$hash{'$which'} = \"$value\";";
	    ${$hash}{'$which'} = $value;
	    print "\nHTMLset failed: $! " if ($!);
	} else { print "\nhash: \%$hash not defined" }
    } elsif ($which) { $! = '';
	eval "\${$which} = \"$value\";";
	print "\nHTMLset failed: $! " if ($!);
    }
    $_;
}

sub do_cmd_HTMLsetenv { &do_cmd_HTMLset(@_) }

####


# Appends $next_def to the preamble if it is not already there.
sub add_to_preamble {
    local($type, $next_def) = @_;
    local($name);
    if ($type =~ /def|include|special|graphicspath/) {
        local($pat) = &escape_rx_chars ($next_def);
#	$preamble .= $next_def . "\n" unless ($preamble =~ /$pat/);
	push(@preamble, $pat); 
    } 
    elsif ($type =~ /command|environment|theorem|counter/) {
	push(@preamble, $next_def ); 
    }
    else {
	($name) = $next_def =~ /$marker\s*({[^}]+})/; # matches type{name}
	$name = &escape_rx_chars($name);
#	$preamble .= $next_def . "\n" unless ($preamble =~ /$marker\s*$name/);
	push(@preamble, $name ); 
    }
}

sub make_latex{
# This is the environment in which to process constructs that cannot be
# translated to HTML.
# The environment tex2html_wrap will be wrapped around any shorthand
# environments (e.g. $, \(, \[).
# The tex2html_wrap environment will be treated as an unrecognised
# evironment by the translator and its contents (i.e. the 'shorthand'
# environment) will be passed to latex for processing as usual.
    local($contents) = @_;
    local($preamble) = $preamble;
    local($aux_preamble) = $aux_preamble;
    while ($preamble =~ s/^(\@.*\n)/$prelatex .= $1;''/e) {}
    print "\nPRE-LATEX: $prelatex" if (($prelatex)&&($VERBOSITY > 1));

    %newed_commands =
	 ( 'newedcommand' , 'newcommand'
	 , 'renewedcommand' , 'renewcommand'
	 , 'providedcommand' , 'providecommand'
	 , 'newedenvironment' , 'newenvironment'
	 , 'newedboolean' , 'newboolean'
	 , 'newedcounter' , 'newcounter'
	 , 'newedtheorem' , 'newtheorem'
	 , 'newedfont' , 'newfont' , 'newedif', 'newif'
	 );
		     

    # Make the @ character a normal letter ...
    $preamble =~ s/\\par([^A-Za-z]|$)/\n$1/g;
    $preamble =~ s/(\\document(class|style)(\[[^\]]+\])?\{\w+\})/$1\n/;
    $preamble =~ s/(\\document(class|style)(\[[^\]]+\])?\{\w+\})/$1\n\\RequirePackage{ifthen}\n/
			 unless ($preamble =~/\{ifthen\}/);
#    $preamble =~ s/(\\document(class|style)(\[[^\]]+\])?\{\w+\})/$1\n\\makeatletter/;
    # ... and make it special again after the preamble
    # remove the  \begin/\end  for  tex2html_nowrap and tex2html_deferred environments
    $preamble =~s/\\(begin|end)\s*\{(tex2html_(nowrap|deferred|nomath|preform)[_a-z]*|imagesonly)\}//g;
    $preamble =~s/\n?\s?<tex2html_(end)?file>\#[^#]*\#//mg;

    $preamble = "\\documentclass\{article\}%\n\\usepackage{html}\n\\usepackage[dvips]{color}\n"
	unless ($preamble);
    if (($LATEX_DUMP)&&(!($preamble =~ /\\usepackage\{ldump\}/))) {
	# MRO: replaced $* with /m
	$preamble =~ s/(\\document(class|style)[^\n]*\n)/$1\\usepackage\{ldump\}\n/m;
    }
    if ($preamble =~ /pstricks/) {
	if ($LOAD_LATEX_COLOR) {
	    $LOAD_LATEX_COLOR =~ s/\{color\}/\{pstcol\}/ ;
	} else {
	    $LOAD_LATEX_COLOR = "\n\\usepackage[dvips]{pstcol}\n";
	}
    } else {
	$LOAD_LATEX_COLOR = "\n\\usepackage[dvips]{color}";
    }
    $LATEX_COLOR = "\\pagecolor[gray]{.85}\\nobreak " unless $LATEX_COLOR;
    if ($preamble =~ /(^|\s*[^%])\s*\\documentstyle/) {
	# \usepackage is invalid in LaTeX 2.09 and LaTeX-2e compatibility mode
	$LATEX_COLOR = ''; $LOAD_LATEX_COLOR = '';
	# ... so is \providecommand 
	$preamble =~ s/\\documentstyle[^{]*{[^}]*}\n?/
		$&."\n\\let\\providecommand\\newcommand\n"/eo;
    }

    $preamble .= $LOAD_LATEX_COLOR."\n" unless ($preamble =~ /[,\{]color[,\}]/);
    $preamble .= "\n\n".$LATEX_COLOR."\n" unless ($preamble =~ /\\pagecolor/);
    do {
	if ($ISOLATIN_CHARS) { $INPUTENC = $INPUTENC || 'latin1' };
	$preamble .= "\n\\usepackage[".$INPUTENC."]\{inputenc\}\n";
	} unless ($preamble =~ /\\inputenc/);

    $aux_preamble = '' unless (($aux_preamble)&&($contents =~ /\\(hyper)?(ref|cite)/));

    $preamble =~ s/\\((provide|(re)?new)ed(command|counter|if|theorem|environment|font))\b/
			 "%\n\\".$newed_commands{$1}/eg;
    $preamble =~ s/(\\(re)?newcommand)\s*(\{(\\?)(\}|[^\}]+)\})/
		$1.(($4)? $3 : "{\\".$5.'}' )/eg;

    $preamble =~s/$verbatim_mark(imagesonly)(\d+)#/$verbatim{$2}/eg; # for images.tex only

#    local($key);
#    foreach $key (keys %newed_commands) {
#	$preamble .= "\n\\let\\$key\\".$newed_commands{$key}
#    }
    $preamble .= "\n";

    local($paperwidth) = '';
    if ($PAPERSIZE) { $paperwidth = &adjust_textwidth($PAPERSIZE); }
    else { $paperwidth = &adjust_textwidth("a5"); }
    local($kern) = ($EXTRA_IMAGE_SCALE ? $EXTRA_IMAGE_SCALE/2 : ".5" );
    $kern = $kern * $MATH_SCALE_FACTOR;
    $prelatex . ($DEBUG ? "\\nonstopmode" : "\\batchmode") .
    "\n$preamble\n\n\\makeatletter\n$aux_preamble\n" .
    "\\makeatletter\n\\count\@=\\the\\catcode`\\_ \\catcode`\\_=8 \n" .
    "\\newenvironment{tex2html_wrap}{}{}%\n" .
    "\\catcode`\\<=12\\catcode`\\_=\\count\@\n" .
    "\\newcommand{\\providedcommand}[1]{\\expandafter\\providecommand\\csname #1\\endcsname}%\n" .
    "\\newcommand{\\renewedcommand}[1]{\\expandafter\\providecommand\\csname #1\\endcsname{}%\n" .
    "  \\expandafter\\renewcommand\\csname #1\\endcsname}%\n" .
    "\\newcommand{\\newedenvironment}[1]{\\newenvironment{#1}{}{}\\renewenvironment{#1}}%\n" .
    "\\let\\newedcommand\\renewedcommand\n" .
    "\\let\\renewedenvironment\\newedenvironment\n" .
    "\\makeatother\n" .
    "\\let\\mathon=\$\n\\let\\mathoff=\$\n" .
    "\\ifx\\AtBeginDocument\\undefined \\newcommand{\\AtBeginDocument}[1]{}\\fi\n" .
    "\\newbox\\sizebox\n" . "$paperwidth" .
    "\\newwrite\\lthtmlwrite\n" . "\\makeatletter\n" .
    "\\let\\realnormalsize=\\normalsize\n\\global\\topskip=2sp\n\\def\\preveqno{}" .
    "\\let\\real\@float=\\\@float \\let\\realend\@float=\\end\@float\n" .
    "\\def\\\@float{\\let\\\@savefreelist\\\@freelist\\real\@float}\n" .
#    "\\def\\\@float{\\\@dbflt}\n" .
    "\\def\\liih\@math{\\ifmmode\$\\else\\bad\@math\\fi}\n" .
    "\\def\\end\@float{\\realend\@float\\global\\let\\\@freelist\\\@savefreelist}\n" . 
    "\\let\\real\@dbflt=\\\@dbflt \\let\\end\@dblfloat=\\end\@float\n" .
    "\\let\\\@largefloatcheck=\\relax\n" .
    "\\let\\if\@boxedmulticols=\\iftrue\n" .
    "\\def\\\@dbflt{\\let\\\@savefreelist\\\@freelist\\real\@dbflt}\n" .
    "\\def\\adjustnormalsize{\\def\\normalsize{\\mathsurround=0pt \\realnormalsize\n" .
    " \\parindent=0pt\\abovedisplayskip=0pt\\belowdisplayskip=0pt}%\n" .
    " \\def\\phantompar{\\csname par\\endcsname}\\normalsize}%\n" .
    "\\def\\lthtmltypeout#1{{\\let\\protect\\string \\immediate\\write\\lthtmlwrite{#1}}}%\n" .
    "\\newcommand\\lthtmlhboxmathA{\\adjustnormalsize\\setbox\\sizebox=\\hbox\\bgroup\\kern.05em }%\n" .
    "\\newcommand\\lthtmlhboxmathB{\\adjustnormalsize\\setbox\\sizebox=\\hbox to\\hsize\\bgroup\\hfill }%\n" .
    "\\newcommand\\lthtmlvboxmathA{\\adjustnormalsize\\setbox\\sizebox=\\vbox\\bgroup %\n".
    " \\let\\ifinner=\\iffalse \\let\\)\\liih\@math }%\n" .
    "\\newcommand\\lthtmlboxmathZ{\\\@next\\next\\\@currlist{}{\\def\\next{\\voidb\@x}}%\n" .
#    " \\expandafter\\box\\next\\edef\\next{\\egroup\\def\\noexpand\\thiseqn{\\theequation}}\\next}%\n" .
    " \\expandafter\\box\\next\\egroup}%\n" .
    "\\newcommand\\lthtmlmathtype[1]{\\gdef\\lthtmlmathenv{#1}}%\n" .
    "\\newcommand\\lthtmllogmath{\\dimen0\\ht\\sizebox \\advance\\dimen0\\dp\\sizebox\n" .
    "  \\ifdim\\dimen0>.95\\vsize\n" .  "   \\lthtmltypeout{%\n" .
    "*** image for \\lthtmlmathenv\\space is too tall at \\the\\dimen0, reducing to .95 vsize ***}%\n" .
    "   \\ht\\sizebox.95\\vsize \\dp\\sizebox\\z\@ \\fi\n" .  "  \\lthtmltypeout{l2hSize %\n" .
    ":\\lthtmlmathenv:\\the\\ht\\sizebox::\\the\\dp\\sizebox::\\the\\wd\\sizebox.\\preveqno}}%\n" .
    "\\newcommand\\lthtmlfigureA[1]{\\let\\\@savefreelist\\\@freelist
       \\lthtmlmathtype{#1}\\lthtmlvboxmathA}%\n" .
    "\\newcommand\\lthtmlpictureA{\\bgroup\\catcode`\\_=8 \\lthtmlpictureB}%\n" . 
    "\\newcommand\\lthtmlpictureB[1]{\\lthtmlmathtype{#1}\\egroup
       \\let\\\@savefreelist\\\@freelist \\lthtmlhboxmathB}%\n" .
    "\\newcommand\\lthtmlpictureZ[1]{\\hfill\\lthtmlfigureZ}%\n" .
    "\\newcommand\\lthtmlfigureZ{\\lthtmlboxmathZ\\lthtmllogmath\\copy\\sizebox
       \\global\\let\\\@freelist\\\@savefreelist}%\n" .
    "\\newcommand\\lthtmldisplayA{\\bgroup\\catcode`\\_=8 \\lthtmldisplayAi}%\n" .
    "\\newcommand\\lthtmldisplayAi[1]{\\lthtmlmathtype{#1}\\egroup\\lthtmlvboxmathA}%\n" .
    "\\newcommand\\lthtmldisplayB[1]{\\edef\\preveqno{(\\theequation)}%\n" .
    "  \\lthtmldisplayA{#1}\\let\\\@eqnnum\\relax}%\n" .
    "\\newcommand\\lthtmldisplayZ{\\lthtmlboxmathZ\\lthtmllogmath\\lthtmlsetmath}%\n" .
    "\\newcommand\\lthtmlinlinemathA{\\bgroup\\catcode`\\_=8 \\lthtmlinlinemathB}\n" .
    "\\newcommand\\lthtmlinlinemathB[1]{\\lthtmlmathtype{#1}\\egroup\\lthtmlhboxmathA\n" .
    "  \\vrule height1.5ex width0pt }%\n" .
    "\\newcommand\\lthtmlinlineA{\\bgroup\\catcode`\\_=8 \\lthtmlinlineB}%\n" .
    "\\newcommand\\lthtmlinlineB[1]{\\lthtmlmathtype{#1}\\egroup\\lthtmlhboxmathA}%\n" .
    "\\newcommand\\lthtmlinlineZ{\\egroup\\expandafter\\ifdim\\dp\\sizebox>0pt %\n" .
    "  \\expandafter\\centerinlinemath\\fi\\lthtmllogmath\\lthtmlsetinline}\n" .
    "\\newcommand\\lthtmlinlinemathZ{\\egroup\\expandafter\\ifdim\\dp\\sizebox>0pt %\n" .
    "  \\expandafter\\centerinlinemath\\fi\\lthtmllogmath\\lthtmlsetmath}\n" .
    "\\newcommand\\lthtmlindisplaymathZ{\\egroup %\n" .
    "  \\centerinlinemath\\lthtmllogmath\\lthtmlsetmath}\n" .
    "\\def\\lthtmlsetinline{\\hbox{\\vrule width.1em \\vtop{\\vbox{%\n" .
    "  \\kern.1em\\copy\\sizebox}\\ifdim\\dp\\sizebox>0pt\\kern.1em\\else\\kern.3pt\\fi\n" .
    "  \\ifdim\\hsize>\\wd\\sizebox \\hrule depth1pt\\fi}}}\n" .
    "\\def\\lthtmlsetmath{\\hbox{\\vrule width.1em\\kern-.05em\\vtop{\\vbox{%\n" .
    "  \\kern.1em\\kern$kern pt\\hbox{\\hglue.17em\\copy\\sizebox\\hglue$kern pt}}\\kern.3pt%\n" .
    "  \\ifdim\\dp\\sizebox>0pt\\kern.1em\\fi \\kern$kern pt%\n" .
    "  \\ifdim\\hsize>\\wd\\sizebox \\hrule depth1pt\\fi}}}\n" .
    "\\def\\centerinlinemath{%\n" . 
    "  \\dimen1=\\ifdim\\ht\\sizebox<\\dp\\sizebox \\dp\\sizebox\\else\\ht\\sizebox\\fi\n" .
    "  \\advance\\dimen1by.5pt \\vrule width0pt height\\dimen1 depth\\dimen1 \n".
    " \\dp\\sizebox=\\dimen1\\ht\\sizebox=\\dimen1\\relax}\n\n" .
    "\\def\\lthtmlcheckvsize{\\ifdim\\ht\\sizebox<\\vsize \n" .
    "  \\ifdim\\wd\\sizebox<\\hsize\\expandafter\\hfill\\fi \\expandafter\\vfill\n" .
    "  \\else\\expandafter\\vss\\fi}%\n" .
    "\\providecommand{\\selectlanguage}[1]{}%\n" .
#    "\\def\\\@enddocumenthook{\\ifnum\\count0>1 \\ifvoid\\\@cclv\\penalty-\\\@MM\\fi\\fi}\n" .
    "\\makeatletter \\tracingstats = 1 \n"
    . ($itrans_loaded ? $itrans_tex_mod : '')
    . $LaTeXmacros . "\n"  # macros defined in extension files
#    "\\usepackage{lthimages}\n" .
    . (($LATEX_DUMP)? "\\latexdump\n" : '')
    . "\n\\begin{document}\n" .
    "\\pagestyle{empty}\\thispagestyle{empty}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength hsize=\\the\\hsize}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength vsize=\\the\\vsize}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength hoffset=\\the\\hoffset}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength voffset=\\the\\voffset}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength topmargin=\\the\\topmargin}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength topskip=\\the\\topskip}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength headheight=\\the\\headheight}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength headsep=\\the\\headsep}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength parskip=\\the\\parskip}\\lthtmltypeout{}%\n" .
    "\\lthtmltypeout{latex2htmlLength oddsidemargin=\\the\\oddsidemargin}\\lthtmltypeout{}%\n" .
    "\\makeatletter\n" .
    "\\if\@twoside\\lthtmltypeout{latex2htmlLength evensidemargin=\\the\\evensidemargin}%\n" .
    "\\else\\lthtmltypeout{latex2htmlLength evensidemargin=\\the\\oddsidemargin}\\fi%\n" .
    "\\lthtmltypeout{}%\n" .
    "\\makeatother\n\\setcounter{page}{1}\n\\onecolumn\n\n% !!! IMAGES START HERE !!!\n\n"
    . "$contents\n"
#    "\\clearpage\n" .
    . "\\end{document}";
}

sub adjust_textwidth {
    local($_) = @_;
    local($width,$length) = ('','');
    if (/a4/) {$width = 595; $length= 842; }
    elsif (/letter/) {$width = 612; $length= 792; }
    elsif (/legal/) {$width = 612; $length= 1008; }
    elsif (/note/) {$width = 540; $length= 720; }
    elsif (/b5/) {$width = 501; $length= 709; }
    elsif (/a5/) {$width = 421; $length= 595; }
    elsif (/a6/) {$width = 297; $length= 421; }
    elsif (/a7/) {$width = 210; $length= 297; }
    elsif (/a8/) {$width = 148; $length= 210; }
    elsif (/a9/) {$width = 105; $length= 148; }
    elsif (/a10/) {$width = 74; $length= 105; }
    elsif (/b4/) {$width = 709; $length= 1002; }
    elsif (/a3/) {$width = 842; $length= 1190; }
    elsif (/b3/) {$width = 1002; $length= 1418; }
    elsif (/a2/) {$width = 1190; $length= 1684; }
    elsif (/b2/) {$width = 1418; $length= 2004; }
    elsif (/a1/) {$width = 1684; $length= 2380; }
    elsif (/b1/) {$width = 2004; $length= 2836; }
    elsif (/a0/) {$width = 2380; $length= 3368; }
    elsif (/b0/) {$width = 2836; $length= 4013; }
    else {
	&write_warnings("\nPAPERSIZE: $_ unknown, using LaTeX's size.");
	return();
     }
    if ($width > 500) { $width = $width - 144; $length = $length - 288; }
    elsif ($width > 250) { $width = $width - 72; $length = $length - 144; }
    elsif ($width > 125) { $width = $width - 36; $length = $length - 72; }
#    "\\setlength{\\oddsidemargin}{0pt}\n" .
#    "\\setlength{\\evensidemargin}{0pt}\n" .
#    "\\setlength{\\parskip}{0pt}\\setlength{\\topskip}{0pt}\n" .
    "\\setlength{\\hoffset}{0pt}\\setlength{\\voffset}{0pt}\n" .
    "\\addtolength{\\textheight}{\\footskip}\\setlength{\\footskip}{0pt}\n" .
    "\\addtolength{\\textheight}{\\topmargin}\\setlength{\\topmargin}{0pt}\n" .
    "\\addtolength{\\textheight}{\\headheight}\\setlength{\\headheight}{0pt}\n" .
    "\\addtolength{\\textheight}{\\headsep}\\setlength{\\headsep}{0pt}\n" .
    "\\setlength{\\textwidth}{${width}pt}\n"
    . (($length > 500) ? "\\setlength{\\textheight}{${length}pt}\n" : '')
}

# Given the depth of the current sectioning declaration and the current
# section numbers it returns the new section numbers.
# It increments the $depth-ieth element of the @curr_sec_id list and
# 0's the elements after the $depth-ieth element.
sub new_level {
    local($depth, @curr_sec_id) = @_;
    $depth = $section_commands{$outermost_level} unless $depth;
    local($i) = 0;
    grep( do { if ($i == $depth) {$_++ ;}
	       elsif ($i > $depth) {$_ = 0 ;};
	       $i++;
	       0;
	   },
	 @curr_sec_id);
    @curr_sec_id;
}

sub make_head_and_body {
    local($title,$body,$before_body) = @_;
    local($DTDcomment) = '';
    local($version,$isolanguage) = ($HTML_VERSION, 'EN');
    local(%isolanguages) = (  'english',  'EN'   , 'USenglish', 'EN-US'
			    , 'original', 'EN'   , 'german'   , 'DE'
			    , 'austrian', 'DE-AT', 'french'   , 'FR'
			    , 'spanish',  'ES'
			    , %isolanguages );
#    $isolanguage = $isolanguages{$default_language};  # DTD is in EN
    $isolanguage = 'EN' unless $isolanguage;
#JCL(jcl-tcl)
# clean title as necessary
# the first words ... is a kludge, but reasonable (or not?) 
#RRM: why bother? --- as long as it is pure text.
    $title = &purify($title,1);
    eval("\$title = ". $default_title ) unless ($title);
#    $title = &get_first_words($title, $WORDS_IN_NAVIGATION_PANEL_TITLES);

    # allow user-modification of the <TITLE> tag; thanks Dan Young
    if (defined &custom_TITLE_hook) {
	$title = &custom_TITLE_hook($title, $toc_sec_title);
    }

    if ($DOCTYPE =~ /\/\/[\w\.]+\s*$/) { # language spec included
	$DTDcomment = '<!DOCTYPE HTML PUBLIC "'. $DOCTYPE .'"';
    } else {
	$DTDcomment = '<!DOCTYPE HTML PUBLIC "'. $DOCTYPE .'//'
	    . ($ISO_LANGUAGE ? $ISO_LANGUAGE : $isolanguage) . '"'
    }
    $DTDcomment .= ($PUBLIC_REF ? "\n  \"".$PUBLIC_REF.'"' : '' ) . '>'."\n";

    $STYLESHEET = $FILE.".css" unless defined($STYLESHEET);

    my ($this_charset) = $charset;
    if ($USE_UTF) { $charset = $utf8_str; $NO_UTF = ''; }
    if (!$charset && $CHARSET) {
	$this_charset = $CHARSET;
	$this_charset =~ s/_/\-/go;
    }
    if ($NO_UTF && $charset =~/utf/) {
	$this_charset = $PREV_CHARSET||$CHARSET; 
	$this_charset =~ s/_/\-/go;
    }

    join("\n", (($DOCTYPE)? $DTDcomment : '' )
	,"<!--Converted with LaTeX2HTML $TEX2HTMLVERSION"
	, "original version by:  Nikos Drakos, CBLU, University of Leeds"
	, "* revised and updated by:  Marcus Hennecke, Ross Moore, Herb Swan"
	, "* with significant contributions from:"
	, "  Jens Lippmann, Marek Rouchal, Martin Wilck and others"
	    . " -->\n<HTML>\n<HEAD>\n<TITLE>".$title."</TITLE>"
	, &meta_information($title)
	,  ($CHARSET && $HTML_VERSION ge "2.1" ? 
	      "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=$this_charset\">" 
	      : "" )
	, $LATEX2HTML_META
	, ($BASE ? "<BASE HREF=\"$BASE\">" : "" )
	, $STYLESHEET_CASCADE
	, ($STYLESHEET ? "<LINK REL=\"STYLESHEET\" HREF=\"$STYLESHEET\">" : '' )
	, $more_links_mark
	, "</HEAD>" , ($before_body? $before_body : '')
	, "<BODY $body>", '');
}


sub style_sheet {
    local($env,$id,$style);
    #AXR:  don't overwrite existing .css
    #MRO: This is supposed to be $FILE.css, no?
    #RRM: only by default, others can be specified as well, via $EXTERNAL_STYLESHEET
    #return if (-f $EXTERNAL_STYLESHEET);
    return if (-r "$FILE.css" && -s _ && !$REFRESH_STYLES );

    unless(open(STYLESHEET, ">$FILE.css")) {
        print "\nError: Cannot write '$FILE.css': $!\n";
        return;
    }
    if ( -f $EXTERNAL_STYLESHEET ) {
        if(open(EXT_STYLES, "<$EXTERNAL_STYLESHEET")) {
            while (<EXT_STYLES>) { print STYLESHEET $_; }
            close(EXT_STYLES);
        } else {
            print "\nError: Cannot read '$EXTERNAL_STYLESHEET': $!\n";
        }
    } else {
	print STYLESHEET <<"EOF"
/* Century Schoolbook font is very similar to Computer Modern Math: cmmi */
.MATH    { font-family: \"Century Schoolbook\", serif; }
.MATH I  { font-family: \"Century Schoolbook\", serif; font-style: italic }
.BOLDMATH { font-family: \"Century Schoolbook\", serif; font-weight: bold }

/* implement both fixed-size and relative sizes */
SMALL.XTINY		{ font-size : xx-small }
SMALL.TINY		{ font-size : x-small  }
SMALL.SCRIPTSIZE	{ font-size : smaller  }
SMALL.FOOTNOTESIZE	{ font-size : small    }
SMALL.SMALL		{  }
BIG.LARGE		{  }
BIG.XLARGE		{ font-size : large    }
BIG.XXLARGE		{ font-size : x-large  }
BIG.HUGE		{ font-size : larger   }
BIG.XHUGE		{ font-size : xx-large }

/* heading styles */
H1		{  }
H2		{  }
H3		{  }
H4		{  }
H5		{  }

/* mathematics styles */
DIV.displaymath		{ }	/* math displays */
TD.eqno			{ }	/* equation-number cells */


/* document-specific styles come next */
EOF
    }
    print "\n *** Adding document-specific styles *** ";
    while (($env,$style) = each %env_style) {
        if ($env =~ /\./) {
            $env =~ s/\.$//;
            print STYLESHEET "$env\t\t{ $style }\n";
        } elsif ($env =~ /inline|^(text|math)?((tt|rm|sf)(family)?|(up|it|sl|sc)(shape)?|(bf|md)(series)?|normal(font)?)$/) {
            print STYLESHEET "SPAN.$env\t\t{ $style }\n";
        } elsif ($env =~ /\./) {
            print STYLESHEET "$env\t\t{ $style }\n";
        } elsif ($env =~ /^(preform|\w*[Vv]erbatim(star)?)$/) {
            print STYLESHEET "PRE.$env\t\t{ $style }\n";
        } elsif ($env =~ /figure|table|tabular|equation|$array_env_rx/) {
            print STYLESHEET "TABLE.$env\t\t{ $style }\n";
        } else {
            print STYLESHEET "DIV.$env\t\t{ $style }\n";
        }
    }
    while (($env,$style) = each %txt_style) {
        print STYLESHEET "SPAN.$env\t\t{ $style }\n";
    }
    while (($env,$style) = each %img_style) {
        print STYLESHEET "IMG.$env\t\t{ $style }\n";
    }

    my ($style);
    foreach $id (sort(keys  %styleID)) {
        $style =  $styleID{$id};
        $style =~ s/font-(color)/$1/;
        print STYLESHEET "\#$id\t\t{ $style }\n"
            if ($styleID{$id} ne '');
    }
    close(STYLESHEET);
}

sub clear_styleID {
    return unless ($USING_STYLES);
    local($env_id,$id) = ("grp", @_); 
    undef $styleID{$env_id} if ($id =~ /^\d+$/);
}

sub make_address { 
    local($addr) = &make_real_address(@_);
    $addr .= "\n</BODY>\n</HTML>\n";
    &lowercase_tags($addr) if $LOWER_CASE_TAGS;
    $addr;
}

sub make_real_address {
    local($addr) = $ADDRESS;
    if ((defined &custom_address)&&($addr)) {
	&custom_address($addr)
    } elsif ($addr) {
	"<ADDRESS>\n$addr\n</ADDRESS>";
    } else { '' }
}

sub purify_caption {
    local($_) = @_;
    local($text) = &recover_image_code($_);
    $text =~ s/\\protect|ALT\=|%EQNO:\d+//g;
    $text =~ s/[\\\#\'\"\`]//g;
    $text;
}

sub recover_image_code {
    local($key) = @_;
    local($text) = $img_params{$key};
    if (!$text) {
	if ($text = $id_map{$key}) {
	    if ($orig_name_map{$text}) {
		$text = $img_params{$orig_name_map{$text}}
	    }
	} elsif ($cached_env_img{$key}) {
	    $text = $img_params{$cached_env_img{$key}};
	}
	if ($text =~ /\#*ALT="([^"]+)"(>|#)/s) { $text = $1 }
    }
    $text =~ s/\\protect|%EQNO:\d+//g;
    $text =~ s/&(gt|lt|amp|quot);/&special_html_inv($1)/eg;
    $text;
}

sub encode_title {
    local($_) = @_;
    $_ = &encode($_);
    while (/(<[^<>]*>)/o) {s/$1//g}; # Remove HTML tags
    s/#[^#]*#//g;               # Remove #-delimited markers
    $_;
}

# Encodes the contents of enviroments that are passed to latex. The code
# is then used as key to a hash table pointing to the URL of the resulting
# picture.
sub encode {
    local($_) = @_;
    # Remove invocation-specific stuff
    1 while(s/\\(begin|end)\s*(($O|$OP)\d+($C|$CP))?|{?tex2html_(wrap|nowrap|deferred|)(_\w+)?}?(\2)?//go);
    $_ = &revert_to_raw_tex($_);
    s/\\protect//g;		# remove redundant \protect macros
    #$_ = pack("u*", $_);	# uuencode
    s/\\\$/dollar/g;		# replace funnies, may cause problems in a hash key
    s/\//slash/g;		# replace funnies, may cause problems in a hash key
    s/\$|\/|\\//g;		# remove funnies, may cause problems in a hash key
    s/\s*|\n//g;		# Remove spaces  and newlines
    s/^(.{80}).*(.{80})$/$1$2/;		# truncate to avoid DBM problems
    $_;
}


##################### Hypertext Section Links ########################
sub post_process {
    # Put hyperlinks between sections, add HTML headers and addresses,
    # do cross references and citations.
    # Uses the %section_info array created in sub translate.
    # Binds the global variables
    # $PREVIOUS, $PREVIOUS_TITLE
    # $NEXT, $NEXT_TITLE
    # $UP, $UP_TITLE
    # $CONTENTS, $CONTENTS_TITLE 
    # $INDEX, $INDEX_TITLE
    # $NEXT_GROUP, $NEXT_GROUP_TITLE
    # $PREVIOUS_GROUP, $PREVIOUS_GROUP_TITLE
    # Converting to and from lists and strings is very inefficient.
    # Maybe proper lists of lists should be used (or wait for Perl5?)
    # JKR:  Now using top_navigation and bot_navigation instead of navigation
    local($_, $key, $depth, $file, $title, $header, @link, @old_link,
	  $top_navigation, $bot_navigation, @keys,
	  @tmp_keys, $flag, $child_links, $body, $more_links);

    @tmp_keys = @keys = sort numerically keys %section_info;
    print "\nDoing section links ...";
    while (@tmp_keys) {
	$key = shift @tmp_keys;
	next if ($MULTIPLE_FILES &&!($key =~ /^$THIS_FILE/));
	print ".";
	$more_links = "";
	($depth, $file, $title, $body) = split($delim,$section_info{$key});
	print STDOUT "\n$key $file $title $body" if ($VERBOSITY > 3);
	next if ($body =~ /external/);
	$PREVIOUS = $PREVIOUS_TITLE = $NEXT = $NEXT_TITLE = $UP = $UP_TITLE
	    = $CONTENTS = $CONTENTS_TITLE = $INDEX = $INDEX_TITLE
	    = $NEXT_GROUP = $NEXT_GROUP_TITLE
	    = $PREVIOUS_GROUP = $PREVIOUS_GROUP_TITLE
	    = $_ = $top_navigation = $bot_navigation = undef;
	&add_link_tag('previous',$file);
	@link =  split(' ',$key);
        ($PREVIOUS, $PREVIOUS_TITLE) =
	    &add_link($previous_page_visible_mark,$file,@old_link);
	@old_link = @link;
	unless ($done{$file}) {
	    ++$link[$depth];
#	    if ($MULTIPLE_FILES && !$depth && $multiple_toc ) {
#	    	local($save_depth) = $link[$depth];
#	    	$link[$depth] = 1;
#		($NEXT_GROUP, $NEXT_GROUP_TITLE) =
#		    &add_link($next_visible_mark, $file, @link);
#		&add_link_tag('next', $file, @link);
#		$link[$depth] = $save_depth;
#	    } else {
		($NEXT_GROUP, $NEXT_GROUP_TITLE) =
		    &add_link($next_visible_mark, $file, @link);
		&add_link_tag('next', $file, @link);
#	    }

	    $link[$depth]--;$link[$depth]--;
	    if ($MULTIPLE_FILES && !$depth ) {
	    } else {
		($PREVIOUS_GROUP, $PREVIOUS_GROUP_TITLE) =
		    &add_link($previous_visible_mark, $file,@link);
		&add_link_tag('previous', $file,@link);
	    }

	    $link[$depth] = 0;
	    ($UP, $UP_TITLE) =
		&add_link($up_visible_mark, $file, @link);
	    &add_link_tag('up', $file, @link);

	    if ($CONTENTS_IN_NAVIGATION) {
		($CONTENTS, $CONTENTS_LINK) = 
		    &add_special_link($contents_visible_mark, $tocfile, $file);
		&add_link_tag('contents', $file, $delim.$tocfile);
	    }

	    if ($INDEX_IN_NAVIGATION) {
		($INDEX, $INDEX_LINK) = 
		    &add_special_link($index_visible_mark, $idxfile, $file);
		&add_link_tag('index', $file, $delim.$idxfile,);
	    }

	    @link = split(' ',$tmp_keys[0]);
	    # the required `next' link may be several sub-sections along
	    local($nextdepth,$nextfile,$nextkey,$nexttitle,$nextbody)=
	        ($depth,$file,$key,'','');
	    $nextkey = shift @tmp_keys;
	    ($nextdepth, $nextfile,$nexttitle,$nextbody) = split($delim,$section_info{$nextkey});
	    if (($nextdepth<$MAX_SPLIT_DEPTH)&&(!($nextbody=~/external/))) {
		($NEXT, $NEXT_TITLE) =
		    &add_link($next_page_visible_mark, $file, @link);
		&add_link_tag('next', $file, @link);
	    } else {
		($NEXT, $NEXT_TITLE) = ('','');
		$nextfile = $file;
	    }
	    if ((!$NEXT || $NEXT =~ /next_page_inactive_visible_mark/)&&(@tmp_keys)) {
		# the required `next' link may be several sub-sections along
		while ((@tmp_keys)&&(($MAX_SPLIT_DEPTH < $nextdepth+1)||($nextfile eq $file))) {
		    $nextkey = shift @tmp_keys;
		    ($nextdepth, $nextfile,$nexttitle,$nextbody) = split($delim,$section_info{$nextkey});
		    if ($nextbody =~ /external/) {
			$nextfile = $file;
			next;
		    };
		    print ",";
		    print STDOUT "\n $nextkey" if ($VERBOSITY > 3);
		}
		@link = split(' ',$nextkey);
		if (($nextkey)&&($nextdepth<$MAX_SPLIT_DEPTH)) {
		    ($NEXT, $NEXT_TITLE) =
			&add_link($next_page_visible_mark, $file, @link);
		    &add_link_tag('next', $file, @link);
		} else {
		    ($NEXT, $NEXT_TITLE) = ($NEXT_GROUP, $NEXT_GROUP_TITLE);
		    $NEXT =~ s/next_page_(inactive_)?visible_mark/next_page_$1visible_mark/;
		    ($PREVIOUS, $PREVIOUS_TITLE) = ($PREVIOUS_GROUP, $PREVIOUS_GROUP_TITLE);
		    $PREVIOUS =~ s/previous_(inactive_)?visible_mark/previous_page_$1visible_mark/;
		}
	    }
	    unshift (@tmp_keys,$nextkey) if ($nextkey);
#
	    $top_navigation = (defined(&top_navigation_panel) ?
			       &top_navigation_panel : &navigation_panel)
		unless $NO_NAVIGATION;
	    $bot_navigation = (defined(&bot_navigation_panel) ?
			       &bot_navigation_panel : &navigation_panel)
		unless $NO_NAVIGATION;
	    local($end_navigation) = "\n<!--End of Navigation Panel-->\n";
	    if ($USING_STYLES) {
		$top_navigation = "\n".'<DIV CLASS="navigation">' . $top_navigation
			if $top_navigation;
		$bot_navigation = "\n".'<DIV CLASS="navigation">' . $bot_navigation
			if $bot_navigation;
		$end_navigation = '</DIV>' . $end_navigation;
		$env_style{'navigation'} = " ";
	    }

	    $header = &make_head_and_body($title, $body);
	    $header = join('', $header, $top_navigation, $end_navigation) if ($top_navigation);

	    local($this_file) = $file;
	    if ($MULTIPLE_FILES && $ROOTED) {
		if ($this_file =~ /\Q$dd\E([^$dd$dd]+)$/) { $this_file = $1 }
	    }
	    &slurp_input($this_file);
	    open(OUTFILE, ">$this_file")
                || die "\nError: Cannot write file '$this_file': $!\n";

	    if (($INDEX) && ($SHORT_INDEX) && ($SEGMENT eq 1)) {
		&make_index_segment($title,$file); }

	    local($child_star,$child_links);
	    local($CURRENT_FILE) = $this_file; # ensure $CURRENT_FILE is set correctly
	    if (/$childlinks_on_mark\#(\d)\#/) { $child_star = $1 }
	    $child_links = &add_child_links('',$file, $depth, $child_star,$key, @keys)
		unless (/$childlinks_null_mark\#(\d)\#/);
	    if (($child_links)&&(!/$childlinks_mark/)&&($MAX_SPLIT_DEPTH > 1)) {
		if ($depth < $MAX_SPLIT_DEPTH -1) {
		    $_ = join('', $header, $_, &child_line(), $childlinks_mark, "\#0\#" );
		} else {
		    $_ = join('', $header, "\n$childlinks_mark\#0\#", &upper_child_line(), $_ );
		}
	    } else {
		$_ = join('', $header, $_ );
	    }
	    $flag = (($BOTTOM_NAVIGATION || &auto_navigation) && $bot_navigation);
	    $_ .= $bot_navigation . $end_navigation if ($flag &&($bot_navigation));
	    $_ .= &child_line() unless $flag;
	    print STDOUT "\n *** replace markers *** " if ($VERBOSITY > 1);
	    &replace_markers;
	    print STDOUT "\n *** post-post-process *** " if ($VERBOSITY > 1);
	    &post_post_process if (defined &post_post_process);
	    &adjust_encoding;
	    print OUTFILE $_;
	    print OUTFILE &make_address;
	    close OUTFILE;
	    $done{$file}++;
	}
    }
    &post_process_footnotes if ($footfile);
}

sub adjust_encoding {
    &convert_to_utf8($_) if ($USE_UTF);
    &lowercase_tags($_) if $LOWER_CASE_TAGS;
}

sub post_replace_markers {
    # MRO: replaced $* with /m
    # clean up starts and ends of  P, BR and DIV tags
    s/(<\/?(P|BR|DIV)>)\s*(\w)/$1\n$3/gom unless ($file eq $citefile);
    s/([^\s])(<(BR|DIV))/$1\n$2/gom unless ($file eq $citefile);
    local($keep,$after);

    # anchor images when otherwise there is an invisible-anchor
#    s/(<A[^>]*>)\&\#160;<\/A>\s?(<(P|DIV)[^>]*>)\s*(<IMG[^>]*>)\s*(<\/(P|DIV)>)/
    s/(<A[^>]*>)($anchor_mark|$anchor_invisible_mark)<\/A>\s?(<(P|DIV)[^>]*>)\s*(<IMG[^>]*>)\s*(<\/(P|DIV)>)/
	do{ $keep="$3$1$5<\/A>";
	    $after = $6;
	    join('',$keep, &after_punct_break($after), $after);
	} /egom;

    # absorb named anchor (e.g. from index-entry) into preceding or following anchor
#    s/(<A NAME=\"[^\"]+\")>\&#160;<\/A>\s*\b?<A( HREF=\"[^\"]+\">)/$1$2/gom;
#    s/(<A HREF=\"[^\"]+\")(>\s*\b?([^<]+|<([^>\/]+|\/[^>A]+)>\s*)*<\/A>)\s*\b?<A( NAME=\"[^\"]+\")>\&#160;<\/A>/$1$5$2/gom;

    # clean up empty table cells
    s/(<TD[^>]*>)\s*(<\/TD>)/<TD>$2/gom;

    # clean up list items (only desirable in the bibliography ?)
    # s/\n<P>(<DT[^>]*>)/\n<P><\/P>\n$1/gom;

    # remove blank lines and comment-markers
#    s/\n\n/\n/g;  # no, cause this kills intended ones in verbatims
    s/$comment_mark(\d+\n?)?//gm;
    s/\&quot;/"/gm;  # replace  &quot;  entities

    # italic \LaTeX looks bad
    s:<(I|EM)>(($Laname|$AmSname)?$TeXname)</\1>:$2:gm;
}

sub lowercase_tags {
    # MRO: modified to use $_[0]
    # local(*stream) = @_;
    my ($tags,$attribs);
    $_[0] =~ s!<(/?\w+)( [^>]*)?>!
	$tags = $1; $attribs = $2;
	$attribs =~ s/ ([\w\d-]+)(=| |$)/' '.lc($1).$2/eg;
	join('', '<', lc($tags) , $attribs , '>')!eg;
}

sub after_punct_break {
    # MRO: modified to use $_[0]
    # local(*stream) = @_;
#    $stream =~ s/^([ \t]*)([,;\.\)\!\"\'\?])[ \t]*(\n)?/(($2)? "$2" : "$1")."\n"/em;
#    $stream;
    $_[0] =~ s/^([ \t]*)([,;\.\)\!\"\'\?\>]|\&gt;)[ \t]*(\n)?//em;
    ($2 ? $2 : $1)."\n";
}

sub make_index_segment {
    local($title,$file)= @_ ;
#JCL(jcl-tcl)
#    s/<[^>]*>//g;
#
    $index_segment{$PREFIX} = "$title";
    if (!($ref_files{"segment"."$PREFIX"} eq "$file")) {
	$ref_files{"segment"."$PREFIX"} = "$file";
	$changed = 1
    }
    $SEGMENT = 2;
}


sub add_link {
    # Returns a pair (iconic link, textual link)
    local($icon, $current_file, @link) = @_;
    local($dummy, $file, $title, $lbody) = split($delim,$section_info{join(' ',@link)});
    if ($lbody =~ /external/) { return ('','') };

#    local($dummy, $file, $title) = split($delim,$toc_section_info{join(' ',@link)});

    if ($MULTIPLE_FILES && $ROOTED && $file) {
        if (!($DESTDIR =~ /\Q$FIXEDDIR\E[$dd$dd]?$/)) { $file = "..$dd$file" }
    }
#    if ($title && ($file ne $current_file || $icon ne $up_visible_mark)) {
    if ($title && ($file ne $current_file)) {
	#RRM: allow user-customisation of the link-text; thanks Dan Young
	if (defined &custom_link_hook ) {
	    $title = &custom_link_hook($title,$toc_section_info{join(' ',@link)});
	} else {
            $title = &purify($title);
	    $title = &get_first_words($title, $WORDS_IN_NAVIGATION_PANEL_TITLES);
	}
	return ("\n".&make_href($file, $icon), &make_href($file, "$title"))
    }
#    elsif ($icon eq $up_visible_mark && $file eq $current_file && $EXTERNAL_UP_LINK) {
    elsif ($icon eq $up_visible_mark && $EXTERNAL_UP_LINK) {
 	return ("\n".&make_href($EXTERNAL_UP_LINK, $icon),
		&make_href($EXTERNAL_UP_LINK, "$EXTERNAL_UP_TITLE"))
    }
    elsif (($icon eq $previous_visible_mark || $icon eq $previous_page_visible_mark)
    	&& $EXTERNAL_PREV_LINK && $EXTERNAL_PREV_TITLE) {
	return ("\n".&make_href($EXTERNAL_PREV_LINK, $icon),
		&make_href($EXTERNAL_PREV_LINK, "$EXTERNAL_PREV_TITLE"))
    }
    elsif (($icon eq $next_visible_mark ||  $icon eq $next_page_visible_mark)
    	&& $EXTERNAL_DOWN_LINK && $EXTERNAL_DOWN_TITLE) {
	return ("\n".&make_href($EXTERNAL_DOWN_LINK, $icon),
		&make_href($EXTERNAL_DOWN_LINK, "$EXTERNAL_DOWN_TITLE"))
    }
    (&inactive_img($icon), "");
}

sub add_special_link { &add_real_special_link(@_) }
sub add_real_special_link {
    local($icon, $file, $current_file) = @_;
    local($text);
    if ($icon eq $contents_visible_mark) { $text = $toc_title }
    elsif ($icon eq $index_visible_mark) { $text = $idx_title }
    elsif ($icon eq $biblio_visible_mark) { $text = $bib_title }
    (($file && ($file ne $current_file)) ? 
    	("\n" . &make_href($file, $icon), 
    	    ($text ? " ". &make_href($file, $text) : undef))
    	: ( undef, undef ))
}

#RRM: add <LINK ...> tag to the HTML head.
#     suggested by Marcus Hennecke
#
sub add_link_tag {
    local($rel, $currentfile, @link ) = @_;
#    local($dummy, $file, $title) = split($delim,$toc_section_info{join(' ',@link)});
    local($dummy, $file, $title) = split($delim,$section_info{join(' ',@link)});
    ($dummy, $file, $title) = split($delim,$toc_section_info{join(' ',@link)})
	unless ($title);

    if ($MULTIPLE_FILES && $ROOTED && $file) {
        if (!($DESTDIR =~ /\Q$FIXEDDIR\E[$dd$dd]?$/)) { $file = "..$dd$file" }
    }
    if ($file && !($file eq $currentfile) && (!$NO_NAVIGATION)) {
	#RRM: allow user-customisation of the REL attribute
	if (defined &custom_REL_hook ) {
	    $rel = &custom_REL_hook($rel,$toc_section_info{join(' ',@link)});
	}
        $more_links .= "\n<LINK REL=\"$rel\" HREF=\"$file\">";
    }
}

sub remove_markers {
# modifies $_
    s/$lof_mark//go;
    s/$lot_mark//go;
    &remove_bbl_marks;
    s/$toc_mark//go;
    s/$idx_mark//go;
    &remove_cross_ref_marks;
    &remove_external_ref_marks;
    &remove_cite_marks;
    &remove_file_marks;
# sensitive markers
    &remove_image_marks;
    &remove_icon_marks;
    &remove_verbatim_marks;
    &remove_verb_marks;
    &remove_child_marks;
# uncaught markers
    s/$percent_mark/%/go;
    s/$ampersand_mark/\&amp;/go;
    s/$comment_mark\s*(\d+\n?)?//sgo;
    s/$caption_mark//go;
    s/<tex2html[^>]*>//g;
    s/$OP\d+\$CP//g;
    $_;
}

sub replace_markers {
    &find_quote_ligatures;
    &replace_general_markers;
    &text_cleanup;
    # Must NOT clean the ~'s out of the navigation icons (in panel or text),
    # and must not interfere with verbatim-like environments
    &replace_sensitive_markers;
    &replace_init_file_mark if (/$init_file_mark/);
    &replace_file_marks;
    &post_replace_markers;
}

sub replace_general_markers {
    if (defined &replace_infopage_hook) {&replace_infopage_hook if (/$info_page_mark/);}
    else { &replace_infopage if (/$info_page_mark/); }
    if (defined &add_idx_hook) {&add_idx_hook if (/$idx_mark/);}
    else {&add_idx if (/$idx_mark/);}

    if ($segment_figure_captions) {
#	s/$lof_mark/<UL>$segment_figure_captions<\/UL>/o
#   } else { s/$lof_mark/<UL>$figure_captions<\/UL>/o }
	s/$lof_mark/$segment_figure_captions/o
    } else { s/$lof_mark/$figure_captions/o }
    if ($segment_table_captions) {
#	s/$lot_mark/<UL>$segment_table_captions<\/UL>/o
#   } else { s/$lot_mark/<UL>$table_captions<\/UL>/o }
	s/$lot_mark/$segment_table_captions/o
    } else { s/$lot_mark/$table_captions/o }
    &replace_morelinks();
    if (defined &replace_citations_hook) {&replace_citations_hook if /$bbl_mark/;}
    else {&replace_bbl_marks if /$bbl_mark/;}
    if (defined &add_toc_hook) {&add_toc_hook if (/$toc_mark/);}
    else {&add_toc if (/$toc_mark/);}
    if (defined &add_childs_hook) {&add_childs_hook if (/$childlinks_on_mark/);}
    else {&add_childlinks if (/$childlinks_on_mark/);}
    &remove_child_marks;

    if (defined &replace_cross_references_hook) {&replace_cross_references_hook;}
    else {&replace_cross_ref_marks if /$cross_ref_mark||$cross_ref_visible_mark/;}
    if (defined &replace_external_references_hook) {&replace_external_references_hook;}
    else {&replace_external_ref_marks if /$external_ref_mark/;}
    if (defined &replace_cite_references_hook) {&replace_cite_references_hook;}
    else { &replace_cite_marks if /$cite_mark/; }
    if (defined &replace_user_references) {
 	&replace_user_references if /$user_ref_mark/; }
}

sub replace_sensitive_markers {
    if (defined &replace_images_hook) {&replace_images_hook;}
    else {&replace_image_marks if /$image_mark/;}
    if (defined &replace_icons_hook) {&replace_icons_hook;}
    else {&replace_icon_marks if /$icon_mark_rx/;}
    if (defined &replace_verbatim_hook) {&replace_verbatim_hook;}
    else {&replace_verbatim_marks if /$verbatim_mark/;}
    if (defined &replace_verb_hook) {&replace_verb_hook;}
    else {&replace_verb_marks if /$verb_mark|$verbstar_mark/;}
    s/;SPMdollar;/\$/g; s/;SPMtilde;/\~/g; s/;SPMpct;/\%/g;
    s/;SPM/\&/go;
    s/$percent_mark/%/go;
    s/$ampersand_mark/\&amp;/go;
    #JKR: Turn encoded ~ back to normal
    s/&#126;/~/go;
}

sub find_quote_ligatures {
    my $ent;

# guillemets, governed by $NO_FRENCH_QUOTES
    do {
	$ent = &iso_map('laquo', "", 1);
	if ($NO_UTF && !$USE_UTF && $ent=~/\&\#(\d+);/) {
	    $ent='' if ($1 > 255);
	}
	s/((\&|;SPM)lt;){2}/$ent/ogs if $ent;
	$ent = &iso_map('raquo', "", 1) if ($ent);
	s/((\&|;SPM)gt;){2}/$ent/ogs if $ent;
	# single guillemot chars cannot be easily implemented this way
	# finding an approp regexp is work for the future
    } unless ($NO_FRENCH_QUOTES);

    $ent = &iso_map("gg", "", 1);
    s/;SPMgg;/($ent ? $ent : '&gt;&gt;')/eg unless ($USE_NAMED_ENTITIES);
    $ent = &iso_map("ll", "", 1);
    s/;SPMll;/($ent ? $ent : '&lt;&lt;')/eg unless ($USE_NAMED_ENTITIES);

    my $ldquo, $rdquo;
# "curly" quotes, governed by  $USE_CURLY_QUOTES.
    do {
	$ldquo = &iso_map("ldquo", "", 1);
	if ($NO_UTF && !$USE_UTF && $ldquo =~ /\&\#(\d+);/) {
	    $ldquo = '' if ($1 > 255);
	}
	s/``/$ldquo/ogs if ($ldquo);
	$rdquo = &iso_map("rdquo", "", 1) if ($ldquo);
	s/''/$rdquo/ogs if ($rdquo);
	
	# single curly quotes cannot be easily implemented this way
	# finding an approp regexp is work for the future
    } if ($USE_CURLY_QUOTES);

# "german" quotes, governed by  $NO_GERMAN_QUOTES.
    do {
	$ent = &iso_map('bdquo', "", 1);
	if ($NO_UTF && !$USE_UTF && $ent =~ /\&\#(\d+);/) {
	    $ent = '' if ($1 > 255);
	}
	s/,,/$ent/eg if $ent;

	# closing upper quotes are not properly displayed in browsers
	s/($ent[\w\s\&\#;']+)$ldquo/$1``/og
		if ($USE_CURLY_QUOTES && $ldquo && $ent);
    } unless ($NO_GERMAN_QUOTES);
}

sub add_childlinks {
    local($before, $after, $star);
    while (/$childlinks_on_mark\#(\d)\#/) {
	$star = $1;
	$before = $`;
	$after = $';
	$before =~ s/\n\s*$//;
	$_ = join('', $before, "\n", $child_links, $after);
    }
}

sub replace_infopage {
    local($INFO)=1 if !(defined $INFO);
    if ($INFO == 1) {
    	local($title);
	if ((defined &do_cmd_infopagename)||$new_command{'infopagename'}) {
	    local($br_id)=++$global{'max_id'};
	    $title = &translate_environments("$O$br_id$C\\infopagename$O$br_id$C");
	} else { $title = $info_title }
	    if ($MAX_SPLIT_DEPTH <= $section_commands{$outermost_level}) {
	        $_ =~ s/(<HR[^>]*>\s*)?$info_title_mark/
		    ($1? $1 : "\n<HR>")."\n<H2>$title<\/H2>"/eog;
	    } else {
	        $_ =~ s/$info_title_mark/"\n<H2>$title<\/H2>"/eog;
	    }
    }
    while (/$info_page_mark/o) {
	$_ = join('', $`, &do_cmd_textohtmlinfopage, $');
    }
}

sub replace_init_file_mark {
    local($init_file, $init_contents, $info_line)=($INIT_FILE,'','');
    if (-f $init_file) {
    } elsif (-f "$orig_cwd$dd$init_file") {
	$init_file = $orig_cwd.$dd.$init_file;
    } else {
	s/$init_file_mark//g;
	return();
    }
    if(open(INIT, "<$init_file")) {
        foreach $info_line (<INIT>) {
	    $info_line =~ s/[<>"&]/'&'.$html_special_entities{$&}.';'/eg;
	    $init_contents .= $info_line;
	}
        close INIT;
    } else {
        print "\nError: Cannot read '$init_file': $!\n";
    }
    s/$init_file_mark/\n<BLOCKQUOTE><PRE>\n$init_contents\n<\/PRE><\/BLOCKQUOTE>\n/g;
}

sub replace_morelinks {
    $_ =~ s/$more_links_mark/$more_links/e;
}

# This code is extremely inefficient. At least the subtrees should be
# filtered according to $MAX_LINK_DEPTH before going into the
# inner loops.
# RRM: revamped parts, for $TOC_STARS, fixing some errors.
#
sub add_child_links { &add_real_child_links(@_) }
sub add_real_child_links {
    local($exclude, $base_file, $depth, $star, $current_key, @keys) = @_;
    local $min_depth = $section_commands{$outermost_level} - 1;
    return ('') if ((!$exclude)&&(!$LEAF_LINKS)&&($depth >= $MAX_SPLIT_DEPTH));
    if ((!$depth)&&($outermost_level)) { $depth = $min_depth }

    local($_, $child_rx, @subtree, $next, %open, @roottree);
    local($first, $what, $pre, $change_key, $list_class);
    $childlinks_start = "<!--Table of Child-Links-->";
    $childlinks_end = "<!--End of Table of Child-Links-->\n";
    $child_rx = $current_key;
    $child_rx =~ s/( 0)*$//;	# Remove trailing 0's
    if ((!$exclude)&&($depth < $MAX_SPLIT_DEPTH + $MAX_LINK_DEPTH -1 )
#	    &&($depth >= $MAX_SPLIT_DEPTH-1)) {
	    &&($depth > $min_depth)) {
	if ((defined &do_cmd_childlinksname)||$new_command{'childlinksname'}) {
	    local($br_id)=++$global{'max_id'};
	    $what = &translate_environments("$O$br_id$C\\childlinksname$O$br_id$C");
	} else {
	    $what = "<strong>$child_name</strong>";
	}
	$list_class = ' CLASS="ChildLinks"' if ($USING_STYLES);
	$first = "$childlinks_start\n<A NAME=\"CHILD_LINKS\">$what<\/A>\n";
    } elsif ($exclude) {
	# remove any surrounding braces
	$exclude =~ s/^($O|$OP)\d+($C|$CP)|($O|$OP)\d+($C|$CP)$//g;
	# Table-of-Contents
	$list_class = ' CLASS="TofC"' if ($USING_STYLES);
	$childlinks_start = "\n<!--Table of Contents-->\n";
	$childlinks_end = "<!--End of Table of Contents-->";
	$first = "$childlinks_start";
    } else {
	$list_class = ' CLASS="ChildLinks"' if ($USING_STYLES);
	$first = "$childlinks_start\n"
	    . ($star ? '':"<A NAME=\"CHILD_LINKS\">$anchor_mark<\/A>\n");
    }
    my $startlist, $endlist;
    $startlist = "<UL$list_class>" unless $CHILD_NOLIST;
    $endlist = '</UL>' unless $CHILD_NOLIST;
    my $alt_item = '<BR>&nbsp;<BR>'."\n";
    my $outer_item = ($CHILD_NOLIST ? $alt_item : '<LI>');
    my $inner_item = '<LI>';
    my $inner_end = '</UL><BR>';

    # collect the relevant keys...
    foreach $next (@keys) {
	if ($MULTIPLE_FILES && $exclude) {
	    # ...all but with this document as the root
	    if ($next =~ /^$THIS_FILE /) {
#		# make current document the root
#	    	$change_key = '0 '.$';
		push(@roottree,$next);
		print "\n$next : m-root" if ($VERBOSITY > 3);
	    } else {
		push(@subtree,$next);
		print "\n$next : m-sub" if ($VERBOSITY > 3);
	    }
	} elsif (($next =~ /^$child_rx /)&&($next ne $current_key)) {
	# ...which start as $current_key
	    push(@subtree,$next);
	    print "\n$next : sub $child_rx" if ($VERBOSITY > 3);
	} else {
	    print "\n$next : out $current_key" if ($VERBOSITY > 3);
	}
    }
    if (@subtree) { @subtree = sort numerically @subtree; }
    if (@roottree) {
    	@roottree = sort numerically @roottree;
    	@subtree = ( @roottree, @subtree );
    }
    # @subtree now contains the subtree rooted at the current node

    local($countUL); #counter to ensure correct tag matching
    my $root_file, $href;
    if (@subtree) {
	local($next_depth, $file, $title, $sec_title, $star, $ldepth,$this_file, $prev_file);
	$ldepth = $depth;
	$prev_file = $base_file;
#	@subtree = sort numerically @subtree;
	foreach $next (@subtree) {
	    $title = '';
	    if ($exclude) {
		# making TOC
		($next_depth, $file, $sec_title) =
			split($delim,$section_info{$next});
		($next_depth, $file, $title, $star) =
			split($delim,$toc_section_info{$next});
		# use the %section_info  title, in case there are images
		$title = $sec_title if ($sec_title =~ /image_mark>\#/);
	    } else {
		# making mini-TOC i.e. the child-links tables
		$star = '';
		($next_depth, $file, $title) =
			split($delim,$section_info{$next});
	    }
	    $root_file = $file unless $root_file;
	    if ($root_file && $root_file =~ /_mn\./) { $root_file=$` };
	    # remove any surrounding braces
	    $title =~ s/^($O|$OP)\d+($C|$CP)|($O|$OP)\d+($C|$CP)$//g;
	    next if ($exclude && $title =~ /^$exclude$/);
	    if (!$title) {
		($next_depth, $file, $title, $star) =
			split($delim,$toc_section_info{$next});
	    }
	    $this_file = $file;
	    $title = "\n".$title if !($title =~/^\n/);
	    next if ( $exclude &&(				# doing Table-of-Contents
		( $TOC_DEPTH &&($next_depth > $TOC_DEPTH))	# and  too deep
		||($star && !$TOC_STARS ) ));			# or no starred sections 
	    $file = "" if (!$MAX_SPLIT_DEPTH); # Martin Wilck
	    next if ($exclude && !$MULTIPLE_FILES &&($title =~ /^\s*$exclude\s*$/));
	    next if (!$exclude && $next_depth > $MAX_LINK_DEPTH + $depth);
	    print "\n$next :" if ($VERBOSITY > 3);
	    if ($this_file =~ /^(\Q$prev_file\E|\Q$base_file\E)$/) {
		$file .= join('', "#SECTION", split(' ', $next));
	    } else { $prev_file = $file }

	    if (!$next_depth && $MULTIPLE_FILES) { ++$next_depth }
	    local($num_open) = (split('/',%open))[0];
	    if ((($next_depth > $ldepth)||$first)
		&& ((split('/',%open))[0] < $MAX_LINK_DEPTH + $depth )
		) {
		# start a new <UL> list
		if ($first) {
		    $_ = "$first\n$startlist\n"; $countUL++;
		    local $i = 1;
		    while ($i <= $ldepth) {
			$open{$i}=0; $i++
		    }
		    $first = '';	# include NAME tag first time only
		    while ($i < $next_depth) {
			$open{$i}=1; $i++; 
			$_ .= ($countUL >1 ? $inner_item : $outer_item)."<UL>\n";
			$countUL++;
		    }
		} else {
		    $_ .= "<UL>\n"; $countUL++;
		}
		$ldepth = $next_depth;
		$open{$ldepth}++; 
		# append item to this list
		print " yes " if ($VERBOSITY > 3);
		if (defined &add_frame_child_links) {
		    $href = &make_href($file,$title);
		    if ($href =~ s/($root_file)_mn/$1_ct/) {
			$href =~ s/(target=")main(")/$1contents$2/i;
		    };
		    $_ .= ($countUL >1 ? $inner_item : $outer_item)
			. $href . "\n";
		} else {
		    $_ .= ($countUL >1 ? $inner_item : $outer_item)
			. &make_href($file,$title) . "\n";
		}
	    }
	    elsif (($next_depth)&&($next_depth <= $ldepth)
		&&((split('/',%open))[0] <= $MAX_LINK_DEPTH + $depth )
		) {
		# append item to existing <UL> list
		while (($next_depth < $ldepth) && %open ) {
		# ...closing-off any nested <UL> lists
		    if ($open{$ldepth}) {
			if (!(defined $open{$next_depth}))  {
			    $open{$next_depth}++;
			} else {
			    $_ .= ($countUL==2 ? $inner_end : '</UL>')."\n";
			    $countUL--;
			}
			delete $open{$ldepth};
		    };
		    $ldepth--;
		}
		$ldepth = $next_depth;
		print " yes" if ($VERBOSITY > 3);
		if (defined &add_frame_child_links) {
		    $href = &make_href($file,$title);
		    if ($href =~ s/($root_file)_mn/$1_ct/) {
			$href =~ s/(target=")main(")/$1contents$2/i;
		    };
		    $_ .= ($countUL >1 ? $inner_item : $outer_item)
			. $href . "\n";
		} else {
		    $_ .= ($countUL >1 ? $inner_item : $outer_item)
			. &make_href($file,$title) . "\n";
		}
	    } else {
		# ignore items that are deeper than $MAX_LINK_DEPTH
		print " no" if ($VERBOSITY > 3);
	    }
	}

	if (%open) {
	# close-off any remaining <UL> lists
	    $countUL-- if $CHILD_NOLIST;
	    local $cnt = (split('/',%open))[0];
	    local $i = $cnt;
		while ($i > $depth) { 
		    if ($open{$i}) {
			$_ .= '</UL>' if $countUL;
			$countUL--;
			delete $open{$i};
		    }
		$i--;
	    }
	}
    }
    # just in case the count is wrong
    $countUL-- if ($CHILD_NOLIST && $countUL > 0);
    $countUL = '' if ($countUL < 0);
    while ($countUL) { $_ .= '</UL>'; $countUL-- }
    ($_ ? join('', $_, "\n$childlinks_end") : '');
}

sub child_line {($CHILDLINE) ? "$CHILDLINE" : "<BR>\n<HR>";}
sub upper_child_line { "<HR>\n"; }

sub adjust_root_keys {
    return() unless ($MULTIPLE_FILES && $ROOTED);
    local($next,$change_key,$current_rx);
    local(@keys) = (keys %toc_section_info);
    
    local($current_key) = join(' ',@curr_sec_id);
    $current_key =~ /^(\d+ )/;
    $current_rx = $1;
    return() unless $current_rx;

    # alter the keys which start as $current_key
    foreach $next (@keys) {
	if ($next =~ /^$current_rx/) {
	    # make current document the root
	    $change_key = '0 '.$';
	    $toc_section_info{$change_key} = $toc_section_info{$next};
	    $section_info{$change_key} = $section_info{$next};
#	    if (!($next eq $current_key)) {
#		$toc_section_info{$next} = $section_info{$next} = '';
#	    }
	}
    }
}

sub top_page {
    local($file, @navigation_panel) = @_;
    # It is the top page if there is a link to itself
    join('', @navigation_panel) =~ /$file/;
}

# Sets global variable $AUX_FILE
sub process_aux_file {
    local(@exts) = ('aux');
    push(@exts, 'lof') if (/\\listoffigures/s);
    push(@exts, 'lot') if (/\\listoftables/s);
    local($_, $status);		# To protect caller from &process_ext_file
    $AUX_FILE = 1;
    foreach $auxfile (@exts) {
	$status = &process_ext_file($auxfile);
	if ($auxfile eq "aux" && ! $status) {
	    print "\nCannot open $FILE.aux $!\n";
	    &write_warnings("\nThe $FILE.aux file was not found," .
			    " so sections will not be numbered \nand cross-references "
			    . "will be shown as icons.\n");
	}
    }
    $AUX_FILE = 0;
}

sub do_cmd_htmlurl {
    local($_) = @_;
    local($url);
    $url = &missing_braces unless (
	(s/$next_pair_pr_rx/$br_id=$1;$url=$2;''/e)
	||(s/$next_pair_rx/$br_id=$1;$url=$2;''/e));
    $url =~ s/\\(html)?url\s*($O|$OP)([^<]*)\2/$3/;
    $url =~ s/\\?~/;SPMtilde;/og;
    join('','<TT>', &make_href($url,$url), '</TT>', $_);
}
sub do_cmd_url { &do_cmd_htmlurl(@_) }

sub make_href { &make_real_href(@_) }
sub make_real_href {
    local($link, $text) = @_;
    $href_name++;
    my $htarget = '';
    $htarget = ' target="'.$target.'"'
	if (($target)&&($HTML_VERSION > 3.2));
    #HWS: Nested anchors not allowed.
    $text =~ s/<A .*><\/A>//go;
    #JKR: ~ is handled different - &#126; is turned to ~ later.
    #$link =~ s/&#126;/$percent_mark . "7E"/geo;
    if ($text eq $link) { $text =~ s/~/&#126;/g; }
    $link =~ s/~/&#126;/g;
    # catch \url or \htmlurl
    $link =~ s/\\(html)?url\s*(($O|$OP)\d+($C|$CP))([^<]*)\2/$5/;
    $link =~ s:(<TT>)?<A [^>]*>([^<]*)</A>(</TT>)?(([^<]*)|$):$2$4:;
    # this should not be here; else TOC, List of Figs, etc. fail:
    # $link =~ s/^\Q$CURRENT_FILE\E(\#)/$1/ unless ($SEGMENT||$SEGMENTED);
    $text = &simplify($text);
    "<A NAME=\"tex2html$href_name\"$htarget\n  HREF=\"$link\">$text</A>";
}

sub make_href_noexpand { # clean
    my ($link, $name, $text) = @_;
    do {$name = "tex2html". $href_name++} unless $name;
    #HWS: Nested anchors not allowed.
    $text =~ s/<A .*><\/A>//go;
    #JKR: ~ is handled different - &#126; is turned to ~ later.
    #$link =~ s/&#126;/$percent_mark . "7E"/geo;
    if ($text eq $link) { $text =~ s/~/&#126;/g; }
    $link =~ s/~/&#126;/g;
    # catch \url or \htmlurl
    $link =~ s/\\(html)?url\s*(($O|$OP)\d+($C|$CP))([^<]*)\2/$5/;
    $link =~ s:(<TT>)?<A [^>]*>([^<]*)</A>(</TT>)?(([^<]*)|$):$2$4:;
    "<A NAME=\"$name\"\n HREF=\"$link\">$text</A>";
}

sub make_named_href {
    local($name, $link, $text) = @_;
    $text =~ s/<A .*><\/A>//go;
    $text = &simplify($text);
    if ($text eq $link) { $text =~ s/~/&#126;/g; }
    $link =~ s/~/&#126;/g;
    # catch \url or \htmlurl
    $link =~ s/\\(html)?url\s*(($O|$OP)\d+($C|$CP))([^<]*)\2/$5/;
    $link =~ s:(<TT>)?<A [^>]*>([^<]*)</A>(</TT>)?(([^<]*)|$):$2$4:;
    if (!($name)) {"<A\n HREF=\"$link\">$text</A>";}
    elsif ($text =~ /^\w/) {"<A NAME=\"$name\"\n HREF=\"$link\">$text</A>";}
    else {"<A NAME=\"$name\"\n HREF=\"$link\">$text</A>";}
}

sub make_section_heading {
    local($text, $level, $anchors) = @_;
    local($elevel) = $level; $elevel =~ s/^(\w+)\s.*$/$1/;
    local($section_tag) = join('', @curr_sec_id);
    local($align,$pre_anchors);

    # separate any invisible anchors or alignment, if this has not already been done
    if (!($anchors)){ ($anchors,$text) = &extract_anchors($text) }
    else { 
	$anchors =~ s/(ALIGN=\"\w*\")/$align = " $1";''/e;
	$align = '' if ($HTML_VERSION < 2.2);
	$anchors = &translate_commands($anchors) if ($anchors =~ /\\/);
    }

    # strip off remains of bracketings
    $text =~ s/$OP\d+$CP//g;
    if (!($text)) {
	# anchor to a single `.' only
	$text = "<A NAME=\"SECTION$section_tag\">.</A>$anchors\n";
    } elsif ($anchors) {
#	# put anchors immediately after, except if title is too long
#	if ((length($text)<60 )&&(!($align)||($align =~/left/))) {
#	    $text = "<A NAME=\"SECTION$section_tag\">$text</A>\n" . $anchors;
	# ...put anchors preceding the title, on a separate when left-aligned
#	} else {
	    $text = "<A NAME=\"SECTION$section_tag\">$anchor_invisible_mark</A>$anchors"
		. (!($align)||($align =~ /left/i ) ? "<BR>" : "") . "\n". $text;
#	}
    } elsif (!($text =~ /<A[^\w]/io)) {
	# no embedded anchors, so anchor it all
	$text = "<A NAME=\"SECTION$section_tag\">\n" . $text . "</A>";
    } else {
	# there are embedded anchors; these cannot be nested
	local ($tmp) = $text;
	$tmp =~ s/<//o ;	# find 1st <
	if ($`) {		# anchor text before the first < 
#	    $text = "<A NAME=\"SECTION$section_tag\">\n" . $` . "</A>\n<" . $';
	    $text = "<A NAME=\"SECTION$section_tag\">\n" . $` . "</A>";
	    $pre_anchors = "<" . $';
	    if ($pre_anchors =~ /^(<A NAME=\"[^\"]+>${anchor_invisible_mark}<\/A>\s*)+$/) {
		$pre_anchors .= "\n"
	    } else { $text .= $pre_anchors; $pre_anchors = '' }
	} else {
	    # $text starts with a tag
	    local($after,$tmp) = ($','');
	    if ( $after =~ /^A[^\w]/i ) {	
		# it is an anchor already, so need a separate line
		$text = "<A NAME=\"SECTION$section_tag\">$anchor_invisible_mark</A><BR>\n$text";
	    } else {
		# Is it a tag enclosing the anchor ?
		$after =~ s/^(\w)*[\s|>]/$tmp = $1;''/eo;
		if ($after =~ /<A.*<\/$tmp>/) {
		    # it encloses an anchor, so use anchor_mark + break
		    $text = "<A NAME=\"SECTION$section_tag\">$anchor_invisible_mark</A><BR>\n$text";
		} else {
		    # take up to the anchor
		    $text =~ s/^(.*)<A([^\w])/"<A NAME=\"SECTION$section_tag\">$1<A$2"/oe;
		}
	    }
	}
    }
    "$pre_anchors\n<$level$align>$text\n<\/$elevel>";
}

sub do_cmd_captionstar { &process_cmd_caption(1, @_) }
sub do_cmd_caption { &process_cmd_caption('', @_) }
sub process_cmd_caption {
    local($noLOTentry, $_) = @_;
    local($text,$opt,$br_id, $contents);
    local($opt) = &get_next_optional_argument;
    $text = &missing_braces unless (
	(s/$next_pair_pr_rx/$br_id=$1;$text=$2;''/e)
	||(s/$next_pair_rx/$br_id=$1;$text=$2;''/e));

    # put it in $contents, so &extract_captions can find it
    local($contents) = join('','\caption', ($opt ? "[$opt]" : '')
	   , "$O$br_id$C" , $text , "$O$br_id$C");

    # $cap_env is set by the surrounding figure/table
    &extract_captions($cap_env);
    $contents.$_;
}

sub extract_captions {
    # Uses and modifies $contents and $cap_anchors, defined in translate_environments
    # and modifies $figure_captions, $table_captions, $before and $after
    # MRO: no effect! local($env,*cap_width) = @_;
    local($env) = @_;
    local(%captions, %optional_captions, $key, $caption, $optional_caption,
	  $item, $type, $list, $extra_list, $number, @tmp, $br_id, $_);
    # associate the br_id of the caption with the argument of the caption
    $contents =~ s/$caption_rx(\n)?/do {
	$key = $9; $caption = $10; $optional_caption = $3;
	$key = &filter_caption_key($key) if (defined &filter_caption_key);
	$optional_captions{$key} = $optional_caption||$caption;
	$captions{$key} = $10; ''}/ego;
#	$captions{$9} = $10; $caption_mark }/ego;
    $key = $caption = $optional_caption = '';

    #catch any  \captionwidth  settings that may remain
    $contents =~ s/$caption_width_rx(\n)?/&translate_commands($&);''/eo;
    
#    $after = join("","<P>",$after) if ($&);
#    $before .= "</P>" if ($&);
    #JKR: Replaced "Figure" and "Table" with variables (see latex2html.config too).
    if ($env eq 'figure') {
	if ((defined &do_cmd_figurename)||$new_command{'figurename'}){
	    $br_id = ++$global{'max_id'};
	    $type = &translate_environments("$O$br_id$C\\figurename$O$br_id$C")
		unless ($noLOFentry);
	} else { $type = $fig_name }
	$list = "\$figure_captions";
#	$extra_list = "\$segment_figure_captions" if ($figure_table_captions);
	$extra_list = "\$segment_figure_captions" if ($segment_figure_captions);
    }
    elsif ($env =~ /table/) {
	if ((defined &do_cmd_tablename)||$new_command{'tablename'}) {
	    $br_id = ++$global{'max_id'};
	    $type = &translate_environments("$O$br_id$C\\tablename$O$br_id$C")
		unless ($noLOTentry);
	} else { $type = $tab_name }
	$list = "\$table_captions";
	$extra_list = "\$segment_table_captions" if ($segment_table_captions);
    }

#    $captions = "";
    $cap_anchors = "";
    local($this);
    foreach $key (sort {$a <=> $b;} keys %captions){ # Sort numerically
	$this = $captions{$key};
	$this =~ s/\\label\s*($O\d+$C)[^<]+\1//g; # remove \label commands
       	local($br_id) = ++$global{'max_id'};
	local($open_tags_R) = []; # locally, initially no style
	$caption = &translate_commands(
	     &translate_environments("$O$br_id$C$this$O$br_id$C"));

	# same again for the optional caption
	$this = $optional_captions{$key};
	$this =~ s/\\label\s*($O\d+$C)[^<]+\1//g; # remove \label commands
	local($open_tags_R) = []; local($br_id) = ++$global{'max_id'};
	$this = &translate_environments("$O$br_id$C$this$O$br_id$C");
	$optional_caption = &translate_commands($this);

	$cap_anchors .= "<A NAME=\"$key\">$anchor_mark</A>";
	$_ = $optional_caption || $caption;


	# split at embedded anchor or citation marker
	local($pre_anchor,$post_anchor) = ('','');
	if (/\s*(<A\W|\#[^#]*\#<tex2html_cite_[^>]*>)/){
	    $pre_anchor = "$`";
	    $post_anchor = "$&$'";
	    $pre_anchor = $anchor_invisible_mark
		unless (($pre_anchor)||($SHOW_SECTION_NUMBERS));
	} else {
	    $pre_anchor = "$_";
	}

#JCL(jcl-tcl)
##	&text_cleanup;
##	$_ = &encode_title($_);
##	s/&nbsp;//g;            # HWS - LaTeX changes ~ in its .aux files
#	$_ = &sanitize($_);
##
#	$_ = &revert_to_raw_tex($_);

	#replace image-markers by the image params
	s/$image_mark\#([^\#]+)\#/&purify_caption($1)/e;

	local($checking_caption, $cap_key) = (1, $_);
	$cap_key = &simplify($cap_key);
	$cap_key = &sanitize($cap_key);
	@tmp = split(/$;/, eval ("\$encoded_$env" . "_number{\$cap_key}"));
	$number = shift(@tmp);
	$number = "" if ($number eq "-1");

	if (!$number) {
	    $cap_key = &revert_to_raw_tex($cap_key);
	    @tmp = split(/$;/
	       , eval ("\$encoded_$env" . "_number{\$cap_key}"));
	    $number = shift(@tmp);
	    $number = "" if ($number eq "-1");
	}

	#resolve any embedded cross-references first
	$checking_caption = '';
	$_ = &simplify($_);
	$_ = &sanitize($_);


#	@tmp = split(/$;/, eval ("\$encoded_$env" . "_number{\$_}"));
#	$number = shift(@tmp);
#	$number = "" if ($number eq "-1");

	&write_warnings(qq|\nNo number for "$_"|) if (! $number);
	eval("\$encoded_$env" . "_number{\$_} = join(\$;, \@tmp)");

	$item = join( '', ($SHOW_SECTION_NUMBERS ? $number."\. " : '')
	    , &make_href("$CURRENT_FILE#$key", $pre_anchor)
	    , $post_anchor);
	undef $_;
	undef @tmp;

	$captions = join("", ($captions ? $captions."\n<BR>\n" : '')
		, "<STRONG>$type" , ($number ? " $number:" : ":")
		, "</STRONG>\n$caption" , (($captions) ? "\n" : "" ));

	do {
	    eval "$extra_list .= \"\n<LI>\" .\$item" if ($extra_list);
	    eval "$list .= \"\n<LI>\" .\$item" }
		 unless ( $noLOTentry || $noLOFentry);
#	eval("print \"\nCAPTIONS:\".$extra_list.\n\"");
    }
}


# This processes \label commands found in environments that will
# be handed over to Latex. Sets the table %symbolic_labels
sub do_labels {
    local($context,$new_context) = @_;
    local($label);
    # MRO: replaced $* by /m
    $context =~ s/\s*$labels_rx/do {
	$label = &do_labels_helper($2);
	$new_context = &anchor_label($label,$CURRENT_FILE,$new_context);""}/geom;
    $new_context;
}

sub extract_labels {
    local($_) = @_;
    local($label,$anchors);
    # MRO: replaced $* by /m
    while (s/[ \t]*$labels_rx//om) {
        $label = &do_labels_helper($2);
        $anchors .= &anchor_label($label,$CURRENT_FILE,'');
    }
    ($_, $anchors);
}

# This should be done inside the substitution but it doesn't work ...
sub do_labels_helper {
    local($_) = @_;
    s/$label_rx/_/g;  # replace non-alphanumeric characters
    $symbolic_labels{$_} = $latex_labels{$_}; # May be empty;
    $_;
}

sub convert_to_description_list {
    # MRO: modified to use $_[1]
    # local($which, *list) = @_;
    my $which = $_[0];
    $_[1] =~ s!(</A>\s*)<[OU]L([^>]*)>!$1<DD><DL$2>!ig;
    $_[1] =~ s!<(/?)[OU]L([^>]*)>!$1? "<$1DL$2>":"<DL$2>"!eig;
    $_[1] =~ s!(</?)LI>!$1D$which>!ig;
#    $_[1] =~ s/^\s*<DD>//;
}

sub add_toc { &add_real_toc(@_) }
sub add_real_toc {
    local($temp1, $temp2);
    print "\nDoing table of contents ...";
    local(@keys) = keys %toc_section_info;
    @keys = sort numerically @keys;
    $temp1 = $MAX_LINK_DEPTH; $temp2 = $MAX_SPLIT_DEPTH;
    $MAX_SPLIT_DEPTH = $MAX_LINK_DEPTH = 1000;
    #JKR: Here was a "Contents" - replaced it with $toc_title
    local($base_key) = $keys[0];
    if ($MULTIPLE_FILES) {
    	$base_key = $THIS_FILE;
    }
    local($title);
    if ((defined &do_cmd_contentsname)||$new_command{'contentsname'}) {
	local($br_id)=++$global{'max_id'};
	$title = &translate_environments("$O$br_id$C\\contentsname$O$br_id$C");
    } else { $title = $toc_title }
    local($toc,$on_first_page) = ('','');
    $on_first_page = $CURRENT_FILE
	unless ($MAX_SPLIT_DEPTH && $MAX_SPLIT_DEPTH <1000);
    $toc = &add_child_links($title,$on_first_page,'',1,$keys[0],@keys);
    &convert_to_description_list('T',$toc) if ($use_description_list);
    s/$toc_mark/$toc/;
    $MAX_LINK_DEPTH = $temp1; $MAX_SPLIT_DEPTH = $temp2;
}

# Assign ref value, but postpone naming the label
sub make_half_href {
    local($link) = $_[0];
    $href_name++;
    "<A NAME=\"tex2html$href_name\"\n HREF=\"$link\">";
}


# Redefined in makeidx.perl
sub add_idx {
    local($sidx_style, $eidx_style) =('<STRONG>','</STRONG>');
    if ($INDEX_STYLES) {
	if ($INDEX_STYLES =~/,/) {
	local(@styles) = split(/\s*,\s*/,$INDEX_STYLES);
	    $sidx_style = join('','<', join('><',@styles) ,'>');
	    $eidx_style = join('','</', join('></',reverse(@styles)) ,'>');
	} else {
	    $sidx_style = join('','<', $INDEX_STYLES,'>');
	    $eidx_style = join('','</', $INDEX_STYLES,'>');
	}
    }
    &add_real_idx(@_)
}
sub add_real_idx {
    print "\nDoing the index ...";
    local($key, $str, @keys, $index, $level, $count,
	  @previous, @current);
    @keys = keys %index;
    @keys = sort keysort  @keys;
    $level = 0;
    foreach $key (@keys) {
	@current = split(/!/, $key);
	$count = 0;
	while ($current[$count] eq $previous[$count]) {
	    $count++;
	}
	while ($count > $level) {
	    $index .= "\n<DL COMPACT>";
	    $level++;
	}
	while ($count < $level) {
	    $index .= "\n</DL>";
	    $level--;
	}
	foreach $term (@current[$count .. $#current-1]) {
	    # need to "step in" a little
#	    $index .= "<DT>" . $term . "\n<DL COMPACT>";
	    $index .= "\n<DT>$sidx_style" . $term . "$eidx_style\n<DD><DL COMPACT>";
	    $level++;
	}
	$str = $current[$#current];
	$str =~ s/\#\#\#\d+$//o; # Remove the unique id's
	$index .= $index{$key} .
	    # If it's the same string don't start a new line
	    (&index_key_eq(join('',@current), join('',@previous)) ?
	     ", $sidx_style" . $cross_ref_visible_mark . "$eidx_style</A>\n" :
	     "<DT>$sidx_style" . $str . "$eidx_style</A>\n");
	@previous = @current;
    }
    while ($count < $level) {
	$index .= "\n</DL>";
	$level--;
    }
    $index = '<DD>'.$index unless ($index =~ /^\s*<D(T|D)>/);

    $index =~ s/(<A [^>]*>)(<D(T|D)>)/$2$1/g;
    
#    s/$idx_mark/<DL COMPACT>$index<\/DL>/o;
    s/$idx_mark/$preindex\n<DL COMPACT>\n$index<\/DL>\n/o;
}

sub keysort {
    local($x, $y) = ($a,$b);
    $x = &clean_key($x);
    $y = &clean_key($y);
#    "\L$x" cmp "\L$y";  # changed sort-rules, by M Ernst.
    # Put alphabetic characters after symbols; already downcased
    $x =~ s/^([a-z])/~~~$1/;
    $y =~ s/^([a-z])/~~~$1/;
    $x cmp $y;
}

sub index_key_eq {
    local($a,$b) = @_;
    $a = &clean_key($a);
    $b = &clean_key($b);
    $a eq $b;
}

sub clean_key {
    local ($_) = @_;
    tr/A-Z/a-z/;
    s/\s+/ /g;		# squeeze white space and newlines into space
    s/ (\W)/$1/g;	# make foo( ), foo () and foo(), or <TT>foo</TT>
    ;			# and <TT>foo </TT> to be equal
    s/$O\d+$C//go;	# Get rid of bracket id's
    s/$OP\d+$CP//go;	# Get rid of processed bracket id's
    s/\#\#\#\d+$//o;	# Remove the unique id
    $_;
}


sub make_footnotes {
    # Uses $footnotes defined in translate and set in do_cmd_footnote
    # Also uses $footfile
    local($_) = "\n<DL>$footnotes\n<\/DL>";
    $footnotes = ""; # else they get used
    local($title);
    if ((defined &do_cmd_footnotename)||$new_command{'footnotename'}) {
	local($br_id)=++$global{'max_id'};
	$title = &translate_environments("$O$br_id$C\\footnotename$O$br_id$C");
    } else {
	$foot_title = "Footnotes" unless $foot_title;
	$title = $foot_title;
    }
    print "\nDoing footnotes ...";
#JCL(jcl-tcl)
# If the footnotes go into a separate file: see &make_file.
    if ($footfile) {
	$toc_sec_title = $title;
	&make_file($footfile, $title, $FOOT_COLOR); # Modifies $_;
	$_ = "";
    } else {
	$footnotes = ""; # else they get re-used
	$_ = join ('', '<BR><HR><H4>', $title, '</H4>', $_ );
    }
    $_;
}

sub post_process_footnotes {
    &slurp_input($footfile);
    open(OUT, ">$footfile") || die "Cannot write file '$footfile': $!\n";
    &replace_markers;
    &post_post_process if (defined &post_post_process);
    &adjust_encoding;
    print OUT $_;
    close OUT;
}

sub make_file {
    # Uses and modifies $_ defined in the caller
    local($filename, $title, $layout) = @_;
    $layout = $BODYTEXT unless $layout;
    $_ = join('',&make_head_and_body($title,$layout), $_
	, (($filename =~ /^\Q$footfile\E$/) ? '' : &make_address )
	, (($filename =~ /^\Q$footfile\E$/) ? "\n</BODY>\n</HTML>\n" : '')
	);
    &replace_markers unless ($filename eq $footfile); 

    unless(open(FILE,">$filename")) {
        print "\nError: Cannot write '$filename': $!\n";
        return;
    }
    print FILE $_;
    close(FILE);
}

sub add_to_body {
    local($attrib, $value) = @_;
    local($body) = $BODYTEXT;
    if ($body =~ s/\Q$attrib\E\s*=\s*"[^"]*"/$attrib="$value"/) {
    } else {
	$body .= " $attrib=\"$value\""; $body =~ s/\s{2,}/ /g;
    }
    $BODYTEXT = $body if $body;
}

sub replace_verbatim_marks {
    # Modifies $_
    my($tmp);
    s/$math_verbatim_rx/&make_comment('MATH', $verbatim{$1})/eg;
    s/$mathend_verbatim_rx/&make_comment('MATHEND', '')/eg;
#    s/$verbatim_mark(verbatim\*?)(\d+)#/<PRE>\n$verbatim{$2}\n<\/PRE>/go;
##    s/$verbatim_mark(\w*[vV]erbatim\*?)(\d+)#/\n$verbatim{$2}\n/go;
    s!$verbatim_mark(\w*[vV]erbatim\*?|tex2html_code)(\d+)#\n?!$tmp=$verbatim{$2};
	$tmp.(($tmp =~/\n\s*$/s)? '':"\n")!eg;
#	"\n".$tmp.(($tmp =~/\n\s*$/s)? '':"\n")!eg;
#    s/$verbatim_mark(rawhtml)(\d+)#/$verbatim{$2}/eg; # Raw HTML
    s/$verbatim_mark(imagesonly)(\d+)#//eg; # imagesonly is *not* replaced
    # Raw HTML, but replacements may have protected characters
    s/$verbatim_mark(rawhtml)(\d+)#/&unprotect_raw_html($verbatim{$2})/eg;
    s/$verbatim_mark$keepcomments_rx(\d+)#/$verbatim{$2}/ego; # Raw TeX
    s/$unfinished_mark$keepcomments_rx(\d+)#/$verbatim{$2}/ego; # Raw TeX
}

# TeX's special characters may have been escaped with a '\'; remove it.
sub unprotect_raw_html {
    local($raw) = @_;
    $raw =~ s/\\($latex_specials_rx|~|\^|@)/$1/g;
    $raw;
}

# remove file-markers; special packages may redefine &replace_file_marks
sub remove_file_marks {
    s/<(DD|LI)>\n?($file_mark|$endfile_mark)\#.*\#\n<\/\1>(\n|(<))/$4/gm;
    s/($file_mark|$endfile_mark)\#.*\#(\n|(<))/$3/gm;
}
sub replace_file_marks { &remove_file_marks }

sub remove_verbatim_marks {
    # Modifies $_
    s/($math_verbatim_rx|$mathend_verbatim_rx)//go;
#    s/$verbatim_mark(verbatim\*?)(\d+)#//go;
    s/$verbatim_mark(\w*[Vv]erbatim\w*\*?)(\d+)#//go;
    s/$verbatim_mark(rawhtml|imagesonly)(\d+)#//go;
    s/$verbatim_mark$keepcomments_rx(\d+)#//go;
    s/$unfinished_mark$keepcomments_rx(\d+)#//go;
}

sub replace_verb_marks {
    # Modifies $_
    s/(?:$verb_mark|$verbstar_mark)(\d+)$verb_mark/
	$code = $verb{$1};
	$code = &replace_comments($code) if ($code =~ m:$comment_mark:);
	"<code>$code<\/code>"/ego;
}

sub replace_comments{
    local($_) = @_;
    $_ =~ s/$comment_mark(\d+)\n?/$verbatim{$1}/go;
    $_ =~ s/$comment_mark\d*\n/%\n/go;
    $_;
}

sub remove_verb_marks {
    # Modifies $_
    s/($verb_mark|$verbstar_mark)(\d+)$verb_mark//go;
}

# This is used by revert_to_raw_tex
sub revert_verbatim_marks {
    # Modifies $_
#    s/$verbatim_mark(verbatim)(\d+)#/\\begin{verbatim}$verbatim{$2}\\end{verbatim}\n/go;
    s/$verbatim_mark(\w*[Vv]erbatim)(\d+)#/\\begin{$1}\n$verbatim{$2}\\end{$1}\n/go;
    s/$verbatim_mark(rawhtml)(\d+)#/\\begin{rawhtml}\n$verbatim{$2}\\end{rawhtml}\n/go;
    s/$verbatim_mark(imagesonly|tex2html_code)(\d+)#\n?/$verbatim{$2}/go;
    s/$verbatim_mark$image_env_rx(\d+)#/\\begin{$1}\n$verbatim{$2}\\end{$1}\n/go;
    s/($math_verbatim_rx|$mathend_verbatim_rx)//go;
}

sub revert_verb_marks {
    # Modifies $_
    s/$verbstar_mark(\d+)$verb_mark/\\verb*$verb_delim{$1}$verb{$1}$verb_delim{$1}/go;
    s/$verb_mark(\d+)$verb_mark/\\verb$verb_delim{$1}$verb{$1}$verb_delim{$1}/go;
}

sub replace_cross_ref_marks {
    # Modifies $_
    local($label,$id,$ref_label,$ref_mark,$after,$name);
    local($invis) = "<tex2html_anchor_invisible_mark></A>";
#    s/$cross_ref_mark#([^#]+)#([^>]+)>$cross_ref_mark/
    s/$cross_ref_mark#([^#]+)#([^>]+)>$cross_ref_mark<\/A>(\s*<A( NAME=\"\d+)\">$invis)?/
	do {($label,$id) = ($1,$2); $name = $4;
	    $ref_label = $external_labels{$label} unless
		($ref_label = $ref_files{$label});
	    print "\nXLINK<: $label : $id :$name " if ($VERBOSITY > 3);
	    $ref_label = '' if ($ref_label eq $CURRENT_FILE);
	    $ref_mark = &get_ref_mark($label,$id);
	    &extend_ref if ($name); $name = '';
	    print "\nXLINK: $label : $ref_label : $ref_mark " if ($VERBOSITY > 3);
	    '"' . "$ref_label#$label" . "\">" . $ref_mark . "<\/A>"
	}/geo;

    # This is for pagerefs which cannot have symbolic labels ??? 
#    s/$cross_ref_mark#(\w+)#\w+>/
    s/$cross_ref_mark#([^#]+)#[^>]+>/
	do {$label = $1;
	    $ref_label = $external_labels{$label} unless
		($ref_label = $ref_files{$label});
	    $ref_label = '' if ($ref_label eq $CURRENT_FILE);
	    print "\nXLINKP: $label : $ref_label" if ($VERBOSITY > 3);
	    '"' . "$ref_files{$label}#$label" . "\">"
	}/geo;
}

#RRM: this simply absorbs the name from the invisible anchor following, 
#     when the anchor itself is not already named.
sub extend_ref {
    if ($ref_label !=~ /NAME=/) { $label .= "\"\n".$name  }
}

sub remove_cross_ref_marks {
    # Modifies $_
#    s/$cross_ref_mark#(\w+)#(\w+)>$cross_ref_mark/
    s/$cross_ref_mark#([^#]+)#([^>]+)>$cross_ref_mark/
	print "\nLOST XREF: $1 : $2" if ($VERBOSITY > 3);''/ego;
#    s/$cross_ref_mark#(\w+)#\w+>//go;
    s/$cross_ref_mark#([^#]+)#[^#>]+>//go;
}

sub replace_external_ref_marks {
    # Modifies $_
    local($label, $link);
#    s/$external_ref_mark#(\w+)#(\w+)>$external_ref_mark/
    s/$external_ref_mark#([^#]+)#([^>]+)>$external_ref_mark/
	do {($label,$id) = ($1,$2); 
	    $link = $external_labels{$label};
	    print "\nLINK: $label : $link" if ($VERBOSITY > 3);
	    '"'. "$link#$label" . "\">\n"
	       . &get_ref_mark("userdefined$label",$id)
	}
    /geo;
}

sub remove_external_ref_marks {
    # Modifies $_
#    s/$external_ref_mark#(\w+)#(\w+)>$external_ref_mark/
    s/$external_ref_mark#([^#]+)#([^>]+)>$external_ref_mark/
	print "\nLOST LINK: $1 : $2" if ($VERBOSITY > 3);''/ego;
}

sub get_ref_mark {
    local($label,$id) = @_;
    ( ( $SHOW_SECTION_NUMBERS && $symbolic_labels{"$label$id"}) ||
     $latex_labels{"userdefined$label$id"} ||
     $symbolic_labels{"$label$id"} ||
     $latex_labels{$label} ||
     $external_latex_labels{$label} ||
     $cross_ref_visible_mark );
}

sub replace_bbl_marks {
    # Modifies $_
    s/$bbl_mark#([^#]+)#/$citations{$1}/go;
}

sub remove_bbl_marks {
    # Modifies $_
    s/$bbl_mark#([^#]+)#//go;
}

sub replace_image_marks {
    # Modifies $_
    s/$image_mark#([^#]+)#([\.,;:\)\]])?(\001)?([ \t]*\n?)(\001)?/
	"$id_map{$1}$2$4"/ego;
#	"$id_map{$1}$2".(($4)?"\n":'')/ego;
}

sub remove_image_marks {
    # Modifies $_
    s/$image_mark#([^#]+)#//go;
}

sub replace_icon_marks {
    # Modifies $_
    if ($HTML_VERSION < 2.2 ) {
	local($icon);
	s/$icon_mark_rx/$icon = &img_tag($1);
	    $icon =~ s| BORDER="?\d+"?||;$icon/ego;
    } else {
	s/$icon_mark_rx/&img_tag($1)/ego;
    }
}

sub remove_icon_marks {
    # Modifies $_
    s/$icon_mark_rx//go;
}

sub replace_cite_marks {
    local($key,$label,$text,$file);
    # Modifies $_
    # Uses $citefile set by the thebibliography environment
    local($citefile) = $citefile;
    $citefile =~ s/\#.*$//;
    
    s/#([^#]+)#$cite_mark#([^#]+)#((($OP\d+$CP)|[^#])*)#$cite_mark#/
	$text = $3; $label= $1; $file='';
	$text = $cite_info{$1} unless $text;
	if ($checking_caption){
	    "$label"
	} elsif ($citefiles{$2}){
	    $file = $citefiles{$2}; $file =~ s:\#.*$::;
	    &make_named_href('', "$file#$label","$text");
	} elsif ($PREAMBLE) {
	    $text || "\#!$1!\#" ;
	} elsif ($simplifying) {
	    $text
	} else {
	     &write_warnings("\nno reference for citation: $1");
	     "\#!$1!\#"
	}/sge ;
    #
    #RRM: Associate the cite_key with  $citefile , for use by other segments.
    if ($citefile) {
	local($cite_key, $cite_ref);
	while (($cite_key, $cite_ref) = each %cite_info) {
	    if ($ref_files{'cite_'."$cite_key"} ne $citefile) {
		$ref_files{'cite_'."$cite_key"} = $citefile;
		$changed = 1; }
	}
    }
}

sub remove_cite_marks {
    # Modifies $_
    s/#([^#]+)#$cite_mark#([^#]+)#([^#]*)#$cite_mark#//go;
}

sub remove_anchors {
# modifies $_
    s/<A[^>]*>//g;
    s/<\/A>//g;
}


# We need two matching keys to determine section/figure/etc. numbers.
# The "keys" are the name of the section/figure/etc. and its
# equivalent in the .aux file (also carrying the number we desire).
# But both keys might have been translated slightly different,
# depending on the usage of math, labels, special characters such
# as umlauts, or simply spacing!
#
# This routine tries to squeeze the HTML translated keys such
# that they match (hopefully very often). -- JCL
#
sub sanitize {
    local($_,$mode) = @_;
    &remove_markers;
    &remove_anchors;
    &text_cleanup;
    s/(\&|;SPM)nbsp;//g;            # HWS - LaTeX changes ~ in its .aux files
    #strip unwanted HTML constructs
    s/<\/?(P|BR|H)[^>]*>//g;
    s/\s+//g; #collapse white space
    $_;
}

# This one removes any HTML markup, so that pure
# plain text remains. (perhaps with <SUP>/<SUB> tags)
# As the result will be part of the HTML file, it will be
# &text_cleanup'd later together with its context.
#
sub purify {
    local($_,$strict) = @_;
    &remove_markers;
    #strip unwanted HTML constructs
#    s/<[^>]*>/ /g;
    s/<(\/?SU[BP])>/>$1>/g unless ($strict);  # keep sup/subscripts ...
    s/<[^>]*>//g;                             # remove all other tags
    s/>(\/?SU[BP])>/<$1>/g unless ($strict);  # ...reinsert them
    s/^\s+|\001//g; s/\s\s+/ /g;              #collapse white space
    $_;
}

# This one is not as strict as &sanitize.
# It is chosen to strip section names etc. a bit from
# constructs so that it better fits a table of contents,
# label files, etc.
# As the result will be part of the HTML file, it will be
# &text_cleanup'd later together with its context.
#
sub simplify {
    local($_) = @_;
    local($simplifying) = 1;
    s/$tex2html_envs_rx//g;
    if (/\\/) {
	local($USING_STYLES) = 0;
	$_ = &translate_commands($_);
	undef $USING_STYLES;
    }
    &replace_external_ref_marks if /$external_ref_mark/;
    &replace_cross_ref_marks if /$cross_ref_mark||$cross_ref_visible_mark/;
    &replace_cite_marks if /$cite_mark/;
    # strip unwanted HTML constructs
#    s/<\/?H[^>]*>/ /g;
    s/<\/?(H)[^>]*>//g;
    s/<\#\d+\#>//g;
    s/^\s+//;
    $_;
}

#RRM: This extracts $anchor_mark portions from a given chunk of text,
#     so they can be positioned separately by the calling subroutine.
# added for v97.2: 
#  search within the immediately following text also; so that 
#  \index and \label after section-headings work as expected.
#
sub extract_anchors {
    local($search_text, $start_only) = @_; 
    local($anchors) = '';
    local($untranslated_anchors) = '';

    do {
	while ($search_text =~ s/<A[^>]*>($anchor_mark|$anchor_invisible_mark)<\/A>//) {
	    $anchors .= $&;
	}
    } unless ($start_only);
    
    $search_text =~ s/\s*(\\protect)?\\(label|index|markright|markboth\s*(($O|$OP)\d+($C|$CP))[^<]*\3)\s*(($O|$OP)\d+($C|$CP))[^<]*\6/
	$anchors .= $&;''/eg unless ($start_only);

    while ( s/^\s*<A[^>]*>($anchor_mark|$anchor_invisible_mark)<\/A>//m) {
	$untranslated_anchors .= $&;
    }
    while ( s/^\s*(\\protect)?\\(label|index|markright|markboth\s*(($O|$OP)\d+($C|$CP))[^<]*\3)\s*(($O|$OP)\d+($C|$CP))[^<]*\6//) {
	$untranslated_anchors .= $&;
    }
    if ($TITLE||$start_only) {
	$anchors .= &translate_commands($untranslated_anchors);
	$untranslated_anchors = '';
    }
    ($anchors.$untranslated_anchors,$search_text); 
}

# This routine must be called once on the text only,
# else it will "eat up" sensitive constructs.
sub text_cleanup {
    # MRO: replaced $* with /m
    s/(\s*\n){3,}/\n\n/gom;	# Replace consecutive blank lines with one
    s/<(\/?)P>\s*(\w)/<$1P>\n$2/gom;      # clean up paragraph starts and ends
    s/$O\d+$C//go;		# Get rid of bracket id's
    s/$OP\d+$CP//go;		# Get rid of processed bracket id's
    s/(<!)?--?(>)?/(length($1) || length($2)) ? "$1--$2" : "-"/ge;
    # Spacing commands
    s/\\( |$)/ /go;
    #JKR: There should be no more comments in the source now.
    #s/([^\\]?)%/$1/go;        # Remove the comment character
    # Cannot treat \, as a command because , is a delimiter ...
    s/\\,/ /go;
    # Replace tilde's with non-breaking spaces
    s/ *~/&nbsp;/g;

    ### DANGEROUS ?? ###
    # remove redundant (not <P></P>) empty tags, incl. with attributes
    s/\n?<([^PD >][^>]*)>\s*<\/\1>//g;
    s/\n?<([^PD >][^>]*)>\s*<\/\1>//g;
    # remove redundant empty tags (not </P><P> or <TD> or <TH>)
    s/<\/(TT|[^PTH][A-Z]+)><\1>//g;
    s/<([^PD ]+)(\s[^>]*)?>\n*<\/\1>//g;

    
#JCL(jcl-hex)
# Replace ^^ special chars (according to p.47 of the TeX book)
# Useful when coming from the .aux file (german umlauts, etc.)
    s/\^\^([^0-9a-f])/chr((64+ord($1))&127)/ge;
    s/\^\^([0-9a-f][0-9a-f])/chr(hex($1))/ge;
}

# This is useful for getting words from a title which are not cluttered
# with tex2html markers or HTML constructs
sub extract_pure_text {
    local($mode) = @_;
    &text_cleanup;		# Remove marking brackets
#
# HWS <hswan@perc.Arco.com>:  Conditionally doing the following
#     permits equations in section headings.
#
    if ($mode eq "strict") {
	s/$image_mark#[^#]*#//g;	# Remove image marker
	s/$bbl_mark#[^#]*#//g;		# Remove citations marker
        s/<tex2html_percent_mark>/%/g;  # BMcM: Retain % signs...
        s/<tex2html_ampersand_mark>/\&amp;/g;
	s/tex2html[\w\d]*//g; 	# Remove other markers
	}

#
# HWS <hswan@perc.Arco.com>:  Replace next statement with the following two
#    to permit symbolic links and images to appear in section headings.

#   s/<[^>]*>//go;			# Remove HTML constructs
    s/$OP[^#]*$CP//go;			# Remove <# * #> constructs
    s/<\s*>//go;			# Remove embedded whitespace
}

############################ Misc ####################################

# MRO: Print standardized header
sub banner {
    print <<"EOF";
This is LaTeX2HTML Version $TEX2HTMLVERSION
by Nikos Drakos, Computer Based Learning Unit, University of Leeds.

EOF
}

# MRO: Extract usage information from POD
sub usage {
    my $start  = 0;
    my $usage  = 'Usage: ';
    my $indent = '';

    print (@_, "\n") if @_;

    my $perldoc = "/usr/bin${dd}perldoc";
    my $script = $SCRIPT || $0;
    open(PIPE, "$perldoc -t $script |")
        || die "Fatal: can't open pipe: $!";
    while (<PIPE>) {
        if (/^\s*$/) {
            next;
        } elsif (/^SYNOPSIS/) {
            $start = 1;
        } elsif (/^\w/) {
            $start = 0;
        } elsif ($start == 1) {
            ($indent) = /^(\s*)/;
            s/^$indent/$usage/;
            $usage =~ s/./ /g;
            $start = 2;
            print $_;
        } elsif ($start == 2) {
            s/^$indent/$usage/;
            print $_;
        }
    }
    close PIPE;
    1;
}

# The bibliographic references, the appendices, the lists of figures and tables
# etc. must appear in the contents table at the same level as the outermost
# sectioning command. This subroutine finds what is the outermost level and
# sets the above to the same level;
sub set_depth_levels {
    # Sets $outermost_level
    local($level);
    # scan the document body, not the preamble, for use of sectioning commands
    my ($contents) = $_;
    if ($contents =~ /\\begin\s*((?:$O|$OP)\d+(?:$C|$CP))document\1|\\startdocument/s) {
	$contents = $';
    }
    #RRM:  do not alter user-set value for  $MAX_SPLIT_DEPTH
    foreach $level ("part", "chapter", "section", "subsection",
		    "subsubsection", "paragraph") {
	last if (($outermost_level) = $contents =~ /\\($level)$delimiter_rx/);
	last if (($outermost_level) = $contents =~ /\\endsegment\s*\[\s*($level)\s*\]/s);
	if ($contents =~ /\\segment\s*($O\d+$C)[^<]+\1\s*($O\d+$C)\s*($level)\s*\2/s)
		{ $outermost_level = $3; last };
    }
    $level = ($outermost_level ? $section_commands{$outermost_level} :
	      do {$outermost_level = 'section'; 3;});

    #RRM:  but calculate value for $MAX_SPLIT_DEPTH when a $REL_DEPTH was given
    if ($REL_DEPTH && $MAX_SPLIT_DEPTH) { 
	$MAX_SPLIT_DEPTH = $level + $MAX_SPLIT_DEPTH;
    } elsif (!($MAX_SPLIT_DEPTH)) { $MAX_SPLIT_DEPTH = 1 };

    %unnumbered_section_commands = (
          'tableofcontents', $level
	, 'listoffigures', $level
	, 'listoftables', $level
	, 'bibliography', $level
	, 'textohtmlindex', $level
        , %unnumbered_section_commands
        );

    %section_commands = ( 
	  %unnumbered_section_commands
        , %section_commands
        );
}

# Now ignores accents which cannot be translated to ISO-LATIN-1 characters
# Also replaces ?' and !' ....
sub replace_strange_accents { 
    &real_replace_strange_accents(@_); # if ($CHARSET =~ /8859[_\-]1$/);
}
sub real_replace_strange_accents {
    # Modifies $_;
    s/\?`/&iso_map("iquest", "")/geo;
    s/!`/&iso_map("iexcl", "")/geo;
    s/\\\^\\i /&iso_map("icirc", "")/geo;
    my ($charset) = "${CHARSET}_character_map_inv";
    $charset =~ s/-/_/g;
    # convert upper 8-bit characters
    if (defined %$charset &&($CHARSET =~ /8859[_\-]1$/)) {
	s/([\200-\377])/
	    $tmp = $$charset{'&#'.ord($1).';'};
	    &mark_string($tmp) if ($tmp =~ m!\{!);
	    &translate_commands($tmp)
	/egos
    }
};

# Creates a new directory or reuses old, perhaps after deleting its contents
sub new_dir {
    local($this_dir,$mode) = @_;
    local(@files)=();
    $this_dir = '.' unless $this_dir;
    $this_dir =~ s/[$dd$dd]+$//o;
    local($print_dir) = $this_dir.$dd;
    (!$mode && mkdir($this_dir, 0755)) ||
	do {
	    print "\nCannot create directory $print_dir: $!" unless ($mode);
	    if ($REUSE) {
		print ", reusing it.\n" unless ($mode);
		&reuse($this_dir,$print_dir);
	    } else {
	    	print "\n" unless ($mode);
		while (! ($answer =~ /^[dqr]$/)) {
		    if ($mode) {
			$answer = $mode;
		    } else { 
		        print "(r) Reuse the images in the old directory OR\n"
			    . (($this_dir eq '.') ?
		"(d) *** DELETE *** the images in $print_dir  OR\n"
		: "(d) *** DELETE *** THE CONTENTS OF $print_dir  OR\n" )
			    . "(q) Quit ?\n:";
		        $answer = scalar(<STDIN>);
		    };
		    if ($answer =~ /^d$/) {
                        @files = ();
			if(opendir(DIR,$this_dir)) {
			    @files = readdir DIR;
			    closedir DIR;
                        } else {
                            print "\nError: Cannot read dir '$this_dir': $!\n";
                        }
			foreach (@files) {
			    next if /^\.+$/;
			    if (-d "$this_dir$dd$_") {
				&new_dir("$this_dir$dd$_",'d');
			    } elsif ($this_dir eq '.') {
				L2hos->Unlink($_) if (/\.(pl|gif|png)$/) 
			    } else {
				L2hos->Unlink("$this_dir$dd$_"); 
			    };
			}
			return(1) if ($this_dir eq '.');
			if($mode) {
			  rmdir($this_dir);
			  rmdir($print_dir);
                        }
			if (!$mode) { &new_dir($this_dir,'r')};
			return(1);
		    } elsif ($answer =~ /^q$/) {
			die "Bye!\n";
		    } elsif ($answer =~ /^r$/) {
			&reuse($this_dir,$print_dir);
			return(1);
		    } else {print "Please answer r d or q!\n";};
		}
	    };
	};
    1;
}

sub reuse {
    local($this_dir,$print_dir) = @_;
    $print_dir = $this_dir.$dd unless ($print_dir);
    if (-f "$this_dir$dd${PREFIX}images.pl") {
	print STDOUT "Reusing directory $print_dir:\n";
	local($key);
	require("$this_dir$dd${PREFIX}images.pl");
    }
}


# JCL(jcl-del) - use $CD rather than a space as delimiter.
# The commands might take white space, or not, depending on
# their definition. Eg. \relax takes white space, because it's a
# letter command, but \/ won't.
# TeX seems to have an internal separator: If \x is " x",
# and \y is "y", then \expandafter\y \x expands to "y x", TeX
# hasn't gobbled the space, meaning that spaces are gobbled once
# when the \y token is consumed, but then never again after \y.
#
# The actions below ensure to insert exactly one space after
# the command name.	# what happens to  `\ '  ?
# The substition is done twice to handle \one\delimits\another
# cases.
# The internal shortcut $CD is then turned into the single
# space we desire.
#
sub tokenize {
    # Modifies $_;
    local($rx) = @_;
    # $rx must be specially constructed, see &make_new_cmd_rx.
    if (length($rx)) {
	# $1: non-letter cmd, or $2: letter cmd
	s/$rx/\\$1$2$CD$4/g;
	s/$rx/\\$1$2$CD$4/g;
	s/$CD+/ /g;	# puts space after each command name
    }
}

# When part of the input text contains special perl characters and the text
# is to be used as a pattern then these specials must be escaped.
sub escape_rx_chars {
    my($rx) = @_; # must use a copy of the string
    $rx =~ s:([\\(){}[\]\^\$*+?.|]):\\$1:g; $rx; }

# Does not do much but may need it later ...
# The document environment has to be removed because it spans
# more than one sections (the translator can only deal with
# environments wholly contained with sections).

# (Does a little more now ... the end of the preamble is now marked
# with an internally-generated command which causes all output
# erroneously generated from unrecognized commands in the preamble
# to vanish --- rst).

sub remove_document_env {
#    s/\\begin$match_br_rx[d]ocument$match_br_rx/\\latextohtmlditchpreceding /o;
    if (/\\begin\s*${match_br_rx}document$match_br_rx/) { 
        s/\\begin\s*$match_br_rx[d]ocument$match_br_rx/\\latextohtmlditchpreceding /
    }
#   s/\\end$match_br_rx[d]ocument$match_br_rx(.|\n)*//o;
    if (/\\end\s*${match_br_rx}document$match_br_rx/) { $_ = $` }
}

# And here's the code to handle the marker ...

sub do_cmd_latextohtmlditchpreceding {
    local($_) = @_;
    $ref_before = '';
    $_;
}

print "\n"; # flushes a cache? This helps, for some unknown reason!!

sub do_AtBeginDocument{
    local($_) = @_;
    eval $AtBeginDocument_hook;
    $_;
}

sub cleanup {
    local($explicit) = @_;
    return unless $explicit || !$DEBUG;

    if (opendir(DIR, '.')) {
	while (defined($_ = readdir(DIR))) {
	    L2hos->Unlink($_)
		if /\.ppm$/ || /^${PREFIX}images\.dvi$/ || /^(TMP[-._]|$$\_(image)?)/;
	}
	closedir (DIR);
    }

    L2hos->Unlink("WARNINGS") if ($explicit &&(-f "WARNINGS"));

    if ($TMPDIR && opendir(DIR, $TMPDIR)) {
	local(@files) = grep(!/^\.\.?$/,readdir(DIR));
	local($busy);
	foreach (@files) {
	    $busy .= $_." " unless (L2hos->Unlink("$TMPDIR$dd$_"));
	}
	closedir (DIR);
	if ($busy) {
	    print "\n\nFiles: $busy  are still in use.\n\n" if ($DEBUG);
	} else {
	    &write_warnings("\n\n Couldn't remove $TMPDIR : $!")
		unless (rmdir $TMPDIR);
	}
    }
    if (opendir(DIR, $TMP_)) {
	local(@files) = grep(!/^\.\.?$/,readdir(DIR));
	$busy = '';
	foreach (@files) {
	    $busy .= "$_ " unless (L2hos->Unlink("$TMP_$dd$_"));
	}
	closedir (DIR);
	local($full_dir) = L2hos->Make_directory_absolute($TMP_);
	if ($busy) {
	    print "\n\nFiles: $busy in $full_dir are still in use.\n\n"
	        if ($DEBUG);
	} else {
	    &write_warnings("\n\nCouldn't remove directory '$full_dir': $!")
		unless (rmdir $full_dir);
	}
    }
}

sub handler {
    print "\nLaTeX2HTML shutting down.\n";
    kill ('INT', $child_pid) if ($child_pid);
    &close_dbm_database;
    &cleanup();
    exit(-1);
}

# Given a filename or a directory it returns the file and the full pathname
# relative to the current directory.
sub get_full_path {
    local($file) = @_;
    local($path,$dir);
    if (-d $file) {	# $file is a directory
	$path = L2hos->Make_directory_absolute($file);
	$file = '';

# JCL(jcl-dir)
    } elsif ($file =~ s|\Q$dd\E([^$dd$dd]*)$||o ) {
	$path = $file;
	$file = $1;
	$path = L2hos->Make_directory_absolute($path);

#RRM: check within $TEXINPUTS directories
    } elsif (!($TEXINPUTS =~ /^\.$envkey$/)) {
	#check along directories in the $TEXINPUTS variable
	foreach $dir (split(/$envkey/,$TEXINPUTS)) {
	    $dir =~ s/[$dd$dd]$//o;
	    if (-f $dir.$dd.$file) {
		$path = L2hos->Make_directory_absolute($dir);
		last;
	    }
	}
    } else {
	$path = L2hos->Cwd();
    }
    ($path, $file);
}


# Given a directory name in either relative or absolute form, returns
# the absolute form.
# Note: The argument *must* be a directory name.
# The whole function has been moved to override.pm



# Given a relative filename from the directory in which the original
# latex document lives, it tries to expand it to the full pathname.
sub fulltexpath {
    # Uses $texfilepath defined in sub driver
    local($file) = @_;
    $file =~ s/\s//g;
    $file = "$texfilepath$dd$file"
      unless (L2hos->is_absolute_path($file));
    $file;
}

#RRM  Extended to allow customised filenames, set $CUSTOM_TITLES
#     or long title from the section-name, set $LONG_TITLES
#
sub make_name {
    local($sec_name, $packed_curr_sec_id) = @_;
    local($title,$making_name,$saved) = ('',1,'');
    if ($LONG_TITLES) {
	$saved = $_;
	&process_command($sections_rx, $_) if /^$sections_rx/;
	$title = &make_long_title($TITLE)
	    unless ((! $TITLE) || ($TITLE eq $default_title));
	$_ = $saved;
    } elsif ($CUSTOM_TITLES) {
	$saved = $_;
	&process_command($sections_rx, $_) if /^$sections_rx/;
	$title = &custom_title_hook($TITLE)
	    unless ((! $TITLE) || ($TITLE eq $default_title));
	$_ = $saved;
    }
    if ($title) {
	#ensure no more than 32 characters, including .html extension
	$title =~ s/^(.{1,27}).*$/$1/;
    	++$OUT_NODE;
	join("", ${PREFIX}, $title, $EXTN);
    } else {
    # Remove 0's from the end of $packed_curr_sec_id
	$packed_curr_sec_id =~ s/(_0)*$//;
	$packed_curr_sec_id =~ s/^\d+$//o; # Top level file
	join("",($packed_curr_sec_id ? 
	    "${PREFIX}$NODE_NAME". ++$OUT_NODE : $sec_name), $EXTN);
    }
}

#RRM: redefine this subroutine, to create customised file-names
#     based upon the actual section title.
#     The default is empty, so reverts to:  node1, node2, ...
#
sub custom_title_hook {
    local($_)= @_;
    "";
}


sub make_long_title {
    local($_)= @_;
    local($num_words) = $LONG_TITLES;
    #RRM:  scan twice for short words, due to the $4 overlap
    #      Cannot use \b , else words break at accented letters
    $_ =~ s/(^|\s)\s*($GENERIC_WORDS)(\'|(\s))/$4/ig;
    $_ =~ s/(^|\s)\s*($GENERIC_WORDS)(\'|(\s))/$4/ig;
    #remove leading numbering, unless that's all there is.
    local($sec_num);
    if (!(/^\d+(\.\d*)*\s*$/)&&(s/^\s*(\d+(\.\d*)*)\s*/$sec_num=$1;''/e))
	{ $num_words-- };
    &remove_markers; s/<[^>]*>//g; #remove tags
    #revert entities, etc. to TeX-form...
    s/([\200-\377])/"\&#".ord($1).";"/eg;
    $_ = &revert_to_raw_tex($_);

    # get $LONG_TITLES number of words from what remains
    $_ = &get_first_words($_, $num_words) if ($num_words);
    # ...and cleanup accents, spaces and punctuation
    $_ = join('', ($SHOW_SECTION_NUMBERS ? $sec_num : ''), $_);
    s/\\\W\{?|\}//g; s/\s/_/g; s/\W/_/g; s/__+/_/g; s/_+$//;
    $_;
}


sub make_first_key {
    local($_);
    $_ = ('0 ' x keys %section_commands);
    s/^0/$THIS_FILE/ if ($MULTIPLE_FILES);  
    chop;
    $_;
}

# This copies the preamble into the variable $preamble.
# It also sets the LaTeX font size, if $FONT_SIZE is set.
sub add_preamble_head {
    $preamble = join("\n", $preamble, @preamble);
    $preamble = &revert_to_raw_tex($preamble);
    $preamble = join ("\n", &revert_to_raw_tex(/$preamble_rx/o),
				$preamble);
    local($savedRS) = $/; undef $/;
    # MRO: replaced $* with /m
    $preamble =~ /(\\document(style|class))\s*(\[[^]]*\])?\s*\{/sm;
    local($before,$after) = ($`.$1, '{'.$');
    $/ = $savedRS;
    local ($options) = $3;
    if ($FONT_SIZE) {
	$options =~ s/(1\dpt)\b//;
	$options =~ s/(\[|\])//g;
	$options = "[$FONT_SIZE".($options ? ",$options" : '').']';
	$preamble = join('', $before, $options, $after );
	&write_mydb_simple("preamble", $preamble);
	@preamble = split(/\n/, $preamble);
	$LATEX_FONT_SIZE = $FONT_SIZE;
    }
    if (($options =~ /(1\dpt)\b/)&&(!$LATEX_FONT_SIZE)) {
	$LATEX_FONT_SIZE = $1;
    }
    #RRM: need to know the font-size before the .aux file is read
    $LATEX_FONT_SIZE = '10pt' unless ($LATEX_FONT_SIZE);
}

# It is necessary to filter some parts of the document back to raw
# tex before passing them to latex for processing.
sub revert_to_raw_tex {
    local($_) = @_;
    local($character_map) = "";
    if ( $CHARSET && $HTML_VERSION ge "2.1" ) {
	$character_map = $CHARSET;
	$character_map =~ tr/-/_/; }
    while (s/$O\s*\d+\s*$C/\{/o) { s/$&/\}/;}
    while (s/$O\s*\d+\s*$C/\{/o) { s/$&/\}/;} #repeat this.
    # The same for processed markers ...
    while ( s/$OP\s*\d+\s*$CP/\{/o ) { s/$&/\}/; }
    while ( s/$OP\s*\d+\s*$CP/\{/o ) { s/$&/\}/;} #repeat this.

    s/<BR>/\\\\/g; # restores the \\ from \parbox's

    # revert any math-entities
    s/\&\w+#(\w+);/\\$1/g;
    s/\&limits;/\\limits/g;
    s/\\underscore/\\_/g;
    s/\\circflex/\\^/g;
    s/\\space/\\ /g;
    s/;SPMthinsp;/\\,/g;
    s/;SPMnegsp;/\\!/g;
    s/;SPMsp;/\\:/g;
    s/;SPMthicksp;/\\;/g;
    s/;SPMgg;/\\gg /g;
    s/;SPMll;/\\ll /g;
    s/;SPMquot;/"/g;

    # revert any super/sub-scripts
    s/<SUP>/\^\{/g;
    s/<SUB>/\_\{/g;
    s/<\/SU(B|P)>/\}/g;


#    #revert common character entities  ??
#    s/&#92;/\\/g;

#    # revert special marks
#    s/$percent_mark/\\%/go;
##    s/$comment_mark(\d+)\n/%$comments{$1}\n/go;
    local($tmp,$tmp2);
#    s/$comment_mark(\d+)\n/$tmp=$verbatim{$1};chomp($tmp);$tmp."\n"/ego;
    s/$comment_mark(\d+)(\n|$|(\$))/$tmp=$verbatim{$1};$tmp2 = $3;
        ($tmp=~m!^\%!s ? '':'%').$tmp.(($tmp=~ m!\n\s*$!s)?'':"\n").$tmp2/sego;
    s/${verbatim_mark}tex2html_code(\d+)\#/$verbatim{$1}/go;
    s/^($file_mark|$endfile_mark).*\#\n//gmo;
    s/$comment_mark(\d*)\s*\n/%\n/go;
    s/$dol_mark/\$/go;
    s/$caption_mark//go;

    # From &pre_process.
    # MRO: replaced $* with /m
    s/\\\\[ \t]*(\n)?/\\\\$1/gm;

    # revert any array-cell delimiters
    s/$array_col_mark/\&/g;
    s/$array_row_mark/\\\\/g;
    s/$array_text_mark/\\text/g;
    s/$array_mbox_mark/\\mbox/g;

    # Replace any verbatim and image markers ...
    &revert_verbatim_marks;
    &revert_verb_marks;


#    &replace_image_marks;
    s/$image_mark\#([^\#]+)\#/&recover_image_code($1)/eg;

    # remove artificial environments and commands

    s/(\n*)\\(begin|end)(($O|$OP)\d+($C|$CP))tex2html_b(egin)?group\3\n?/
	($1? "\n":'')."\\".($6? $2:(($2 =~ m|end|)? 'e':'b'))."group\n"
    /gem;
    s/\\(begin|end)(\{|(($O|$OP)\d+($C|$CP|\})))(tex2html|verbatim)_code(\}|\3)\n?//gm;

    #take care not to concatenate \<cmd> with following letters
    local($tmp);
    s/(\\\w+)?$tex2html_wrap_rx([^\\\n])?/$tmp=$2;
        ((($tmp eq 'end')&&($1)&&!($5)&&($6))? "$1 $6":"$1$5$6")/egs;
    undef $tmp;
    s/\s*\\newedcommand\s*{/"%\n\\providecommand{\\"/gem;
    s/\\newedcommand\s*{/\\providecommand{\\/gom;
#    s/(\n*)\\renewedcommand{/($1? "\n":'')."\\renewcommand{\\"/geo;
    s/\s*\\providedcommand\s*{/"%\n\\providecommand{\\"/gem;
#    s/\\providedcommand{/\\providecommand{\\/go;
    s/\\renewedenvironment\s*/\\renewenvironment/gom;
    s/\\newedboolean\s*{/\\newboolean{/gom;
    s/\\newedcounter\s*{/\\newcounter{/gom;
    s/\\newedtheorem\s*{/\\newtheorem{/gom;
    s/\\xystar/\\xy\*/gom; # the * has a special meaning in Xy-pic

    #fix-up the star'd environment names
    s/(\\(begin|end)(($O|$OP)\d+($C|$CP))[^<]*)star\3/$1\*$3/gm;
    s/(\\(begin|end)\{[^\}]*)star\}/$1\*\}/gm;
    s/\\(begin|end)\{[^\}]*begin(group)\}/\\$1$2/gm;
    s/\\(b|e)(egin|end)\{[^\}]*b(group)\}/\\$1$3/gm;

    s/(\\(\w+)TeX)/($language_translations{$2}? "\\selectlanguage{$2}": $1)/egom;

    if ($PREPROCESS_IMAGES) {
      while (/$pre_processor_env_rx/m) {
	$done .= $`; $pre_env = $5; $which =$1; $_ = $';
        if (($which =~ /begin/)&&($pre_env =~ /indica/)) {
	    ($indic, $dum) = &get_next_optional_argument;
	    $done .= "\#$indic";
        } elsif (($which =~ /begin/)&&($pre_env =~ /itrans/)) {
	    ($indic, $dum) = &get_next_optional_argument;
	    $done .= "\#$indic";
        } elsif (($which =~ /end/)&&($pre_env =~ /indica/)) {
	    $done .= '\#NIL';
        } elsif (($which =~ /end/)&&($pre_env =~ /itrans/)) {
	    $done .= "\#end$indic";
	} elsif ($which =~ /begin/) {
	    $done .= (($which =~ /end/)? $end_preprocessor{$pre_env}
		          : $begin_preprocessor{$pre_env} )
	}
	$_ = $done . $_;
      }
    }
    s/\\ITRANSinfo\{(\w+)\}\{([^}]*)\}/\#$1=$2/gm if $itrans_loaded;

    s/\n{3,}/\n\n/gm; # remove multiple (3+) new-lines 
    s/^\n+$//gs; # ...especially if that is all there is!
    if ($PREAMBLE) {
	s/$comment_mark(\d+\n?)?//g;
#	$preamble =~ s/\\par\n?/\n/g;
	s/\\par\b/\n/g;
	s/^\s*$//g; #remove blank lines in the preamble
    };

    s/($html_specials_inv_rx)/$html_specials_inv{$1}/geo;
    # revert entities to TeX code, except if in {rawhtml} environments
    if (!($env =~ /rawhtml/)) {
        s/$character_entity_rx/( $character_map ?
	  eval "\$${character_map}_character_map_inv\{\"$1\"\}" :
	    $iso_8859_1_character_map_inv{$1} ||
	      $iso_10646_character_map_inv{$1})/geo;
        s/$named_entity_rx/( $character_map ? 
	  eval "\$${character_map}_character_map_inv\{\$${character_map}_character_map{'$1'}}" :
	    $iso_8859_1_character_map_inv{$iso_8859_1_character_map{$1}} ||
	      $iso_10646_character_map_inv{$iso_10646_character_map{$1}})/geo;

    } else {
        #RRM: check for invalid named entities in {rawhtml} environments
	s/($named_entity_rx)/&write_warnings(
	    "An unknown named entity ($1) appears in the source text.") unless (
		 $character_map && eval 
	  "\$${character_map}_character_map_inv\{\$${character_map}_character_map{'$2'}}");
		     ";SPM$2;"/ego;
    }

    #RRM: check for numbered character entity out-of-range
    if ($HTML_VERSION < 4.0) {
	s/$character_entity_rx/&write_warnings(
	    "An invalid character entity ($1) appears in the source text.")
	     if ($2 > 255);
	$1/ego; }

    #RRM: check for invalid named entities outside {rawhtml} environments
    # --- these should have been caught already, but check again
    s/$named_entity_rx/&write_warnings(
	    "An unknown named entity ($1) appears in the source text.") unless (
	$character_map && eval 
	  "\$${character_map}_character_map_inv\{\$${character_map}_character_map{'$1'}}");
		     $1/ego;

    &revert_to_raw_tex_hook if (defined &revert_to_raw_tex_hook);
    $_;
}

sub next_wrapper {
    local($dollar) = @_;
    local($_,$id);
    $wrap_toggle = (($wrap_toggle eq 'end') ? 'begin' : 'end');
    $id = ++$global{'max_id'};
    $_ = "\\$wrap_toggle$O$id$C"."tex2html_wrap$O$id$C";
    $_ = (($wrap_toggle eq 'end') ? $dollar.$_ : $_.$dollar);
    $_;
}

sub make_wrapper {
    &make_any_wrapper($_[0], '', "tex2html_wrap");
}

sub make_nowrapper {
    &make_any_wrapper($_[0], 1, "tex2html_nowrap");
}

sub make_inline_wrapper {
    &make_any_wrapper($_[0], '', "tex2html_wrap_inline");
}

sub make_deferred_wrapper {
    &make_any_wrapper($_[0], 1, "tex2html_deferred");
}

sub make_nomath_wrapper {
    &make_any_wrapper($_[0], '', "tex2html_nomath_inline");
}

sub make_any_wrapper {
    local($toggle,$break,$kind) = @_;
    local($max_id) = ++$global{'max_id'};
    '\\'. (($toggle) ? 'begin' : 'end')
	. "$O$max_id$C"."$kind$O$max_id$C"
	. (($toggle || !$break) ? '' : '');
}

sub get_last_word {
    # Returns the last word in multi-line strings
    local($_) = @_;
    local ($word,$lastbit,$which);
#JCL(jcl-tcl)
# also remove anchors and other awkward HTML markup
#    &extract_pure_text("strict");
##    $_ = &purify($_);  ## No. what if it is a verbatim string or image?
#
#    while (/\s(\S+)\s*$/g) { $word = $lastbit = $1;}

    if (!$_ && (defined $keep)) {
	# inside mathematics !
	$_ = $keep . $pre ;
    }
    if (!$_ && $ref_before) { $_ = $ref_before; }
    elsif (!$_) {
	# get it from last thing before the current environment
	$which = $#processedE;
	$_ = $processedE[$which];
    }

    while (/((($O|$OP)\d+($C|$CP))[.\n]*\2|\s(\S+))\s*$/g)
	{ $word = $lastbit = $1 }
    if (($lastbit =~ s/\$\s*$//)||(defined $keep)) {
	local($br_idA) = ++$global{'max_id'};
	local($br_idB) = ++$global{'max_id'};
	$lastbit = join('', "\\begin $O$br_idA${C}tex2html_wrap_inline$O$br_idA$C\$"
		, $lastbit, "\$\\end $O$br_idB${C}tex2html_wrap_inline$O$br_idB$C");
	$lastbit = &translate_environments($lastbit);
	$lastbit = &translate_commands($lastbit);
	return ($lastbit);
    }
    if ($lastbit =~ s/($O|$OP)\d+($C|$CP)//g) { return ($lastbit); }
    elsif ($lastbit eq '') { return ($_) }

    local($pre_bit);
    if ($lastbit =~/>([^>]*)$/) { 
	$word = $1; $pre_bit = $`.'>';
	if ($pre_bit =~ /($verb_mark|$verbstar_mark)$/) {
	    $word = $lastbit;
	} elsif ($pre_bit =~ /<\w+_mark>$/) {
	    $word = $& . $word;
	} elsif (!($word)) {
	    if ($lastbit =~ s/<([^\/][^>]*)>$//o)
	        { $word=$1; $pre_bit = $`; }
	    elsif ($lastbit =~ s/>([^<]*)<\/[^>]*>//o)
	        { $word=$1; $pre_bit = $`.'>' }
	    else { $word = ";SPMnbsp;"; }
	}
#	if ($pre_bit =~ /<\w+_mark>$/) { $word = $& . $word }
     } else { $word = $lastbit };
    $word;
}

#JCL(jcl-tcl)
# changed completely
#
# We take the first real words specified by $min from the string.
# Allow for simple HTML constructs like <I>...</I> (but not <H*>
# or <P*> and the like), math, or images to remain in the result,
# not counting as words.
# Take care that eg. <I>...</I> grouping tags are not broken.
# This is achieved by lifting the markup, removing superfluous
# words, re-inserting the markup, and throw empty markup away.
# In later versions images could be modified such that they become
# thumbnail sized.
#
# rawhtml or verbatim environments might introduce lots of awkward
# stuff, but yet we leave the according tex2html markers in.
#
sub get_first_words {
    local($_, $min) = @_;
    local($words,$i);
    local($id,%markup);
    #no limit if $min is negative
    $min = 1000 if ($min < 0);

    &remove_anchors;
    #strip unwanted HTML constructs
    s/<\/?(P|BR|H)[^>]*>/ /g;
    #remove leading white space and \001 characters
    s/^\s+|\001//g;
    #lift html markup, numbered for recovery
    s/(<[^>]*>(#[^#]*#)?)/$markup{++$id}=$1; "\000$id\000"/ge;

    foreach (split /\s+|\-{3,}/) {
        # count words (incl. HTML markup as part of the word)
        ++$i; 
#	$words .= $_ . " " if (/\000/ || ($i <= $min));
	$words .= $_ . " " if ($i <= $min);
    }
    $_ = $words;
    chop;

    #re-insert markup
    s/\000(\d+)\000/$markup{$1}/g;
    # remove empty markup
    # it's normalized, because generated by LaTeX2HTML only
    s/<([A-Z]+)[^>]*>\s*<\/\1>\s*//g;
    $_;
}

sub replace_word {
    # Replaces the LAST occurrence of $old with $new in $str;
    local($str, $old, $new) = @_;
    substr($str,rindex($str,$old),length($old)) = $new;
    $str;
}

# Returns the recognised sectioning commands as a string of alternatives
# for use in regular expressions;
sub get_current_sections {
    local($_, $key);
    foreach $key (keys %section_commands) {
	if ($key =~ /star/) {
	    $_ = $key . "|" . $_}
	else {
	    $_ .= "$key" . '[*]?|';
	}
    }
    chop;			# Remove the last "|".
    $_;
}

sub numerically {
    local(@x) = split(' ',$a);
    local(@y) = split(' ',$b);
    local($i, $result);
    for($i=0;$i<$#x;$i++) {
       last if ($result = ($x[$i] <=> $y[$i]));
    }
    $result
}

# Assumes that the files to be sorted are of the form
# <NAME><NUMBER>
sub file_sort {
    local($i,$j) = ($a,$b);
    $i =~ s/^[^\d]*(\d+)$/$1/;
    $j =~ s/^[^\d]*(\d+)$/$1/;
    $i <=> $j
}

# If a normalized command name exists, return it.
sub normalize {
    # MRO: modified to use $_[1]
    # local($cmd,*after) = @_;
    my $cmd =$_[0];
    my $ncmd;
    # Escaped special LaTeX characters
    if ($cmd =~ /^($latex_specials_rx)/) {
#	$cmd =~ s/&(.*)$/&amp;$1/o;
	$cmd =~ s/&(.*)$/$ampersand_mark$1/o;
        $cmd =~ s/%/$percent_mark/o;
	$_[1] = join('', $cmd, $_[1]);
	$cmd = ""}
    elsif ($ncmd = $normalize{$cmd}) {
	$ncmd;
    }
    else {
 	$cmd =~ s/[*]$/star/;
 	$cmd =~ s/\@/_at_/g;
	$cmd;
    }
}

sub normalize_sections {
    my $dummy = '';
    # MRO: s/$sections_rx/'\\' . &normalize($1.$2,*after) . $4/ge;
    s/$sections_rx/'\\' . &normalize($1.$2,$dummy) . $4/ge;
}

sub embed_image {
    my ($url,$name,$external,$altst,$thumbnail,$map,$align,
	$usemap,$exscale,$exstr) = @_;
    my $imgID = '';
    my $urlimg = $url;
    my $ismap = $map ? " ISMAP" : '';

#<bo>
# export a math formula to a file.

    my $filename = $url.".txt";
    my $outFH = new FileHandle;
    open($outFH,"> $filename")
	or die "Cannot open $filename: $!\n";
    $altst =~ s/ALT="(.*)"/$1/s;
    $altst =~ s/\$(.*)\$/$1/s;
    print $outFH $altst;
    close($outFH);

#</bo>
### print a math formula when -verbosity=2
#
# Here is an example:
#
# embedding img347.png for tex2html_wrap_inline2707, with ALT="$e_1(x,z)$"
#
    print "\nembedding $url for $name, with $altst\n" if ($VERBOSITY > 1);

    if (! ($NO_IMAGES || $PS_IMAGES)) {
	# for over-scaled GIFs with pre-determined sizes	# RRM 11-9-96
        my $size;
	if (($width{$name})&&(($exscale)||($EXTRA_IMAGE_SCALE))) {
	    $exscale = $EXTRA_IMAGE_SCALE unless ($exscale);
	    if ($name =~ /inline|indisplay|entity|equation|math|eqn|makeimage/){
		($size, $imgID) = &get_image_size($url, $exscale);
	    } else {
		($size, $imgID) = &get_image_size($url,'');
	    }
	} else {
	    ($size,$imgID) = &get_image_size($url,'');
	}
	$image_size{$url} = $size 
	    unless ((! $size) || ($size eq "WIDTH=\"0\" HEIGHT=\"0\""));
	$url = &find_unique($url);
    }

    $urlimg = $url;
    $urlimg =~ s/\.$IMAGE_TYPE$/.html/ if ($map);
    if ($exstr =~ s/align\s*=\s*(\"?)(\w+)\1($|\s|,)//io) { $align = $2; }
    my $usersize = '';
    if ($exstr =~ s/width\s*=\s*(\"?)([^\s,]+)\1($|\s|,)//io) {
	my ($pxs,$len) = &convert_length($2);
	$usersize = " WIDTH=\"$pxs\"";
    }
    if ($exstr =~ s/height\s*=\s*(\"?)([^\s,]+)\1($|\s|,)//io) { 
	my ($pxs,$len) = &convert_length($2);
	$usersize .= " HEIGHT=\"$pxs\"";
    }

    my $border = '';
    $border = "\" BORDER=\"0"
	unless (($HTML_VERSION < 2.2 )||($exstr =~ /BORDER/i));

    my $aalign;
    if (($name =~ /figure|table|displaymath\d+|eqnarraystar/)&&(!$align)) {
    } elsif ($name =~ /displaymath_/) {
	$aalign = "MIDDLE".$border;
    } elsif (($name =~ /(equation|eqnarray)($|\d)/)&&(!$align)) {
	if ($HTML_VERSION >= 3.2) {
	    $aalign =  ($EQN_TAGS eq "L") ? "RIGHT" : "LEFT";
	}
    } elsif ($name =~ /inline|display|entity|xy|diagram/ && $depth{$name} != 0) {
	$aalign = "MIDDLE".$border;
    } elsif ($name =~ /inpar/m) {
	$aalign = "TOP".$border;
    } else {  $aalign = "BOTTOM".$border }

    $aalign = "\U$align" if $align;
    my $ausemp = $usemap ? "\UUSEMAP=$usemap" : '';

    #append any extra valid options 
    $ismap .= &parse_keyvalues ($exstr, ("IMG")) if ($exstr);

    $altst = '' if ($ismap =~ /(^|\s+)ALT\s*=/);
    if ($altst) {
	if ($altst =~ /\s*ALT="?([^\"]+)"?\s*/io) { $altst=$1 }
	$altst =~ s/[<>"&]/'&'.$html_special_entities{$&}.';'/eg;
	$altst = "\n ALT=\"$altst\"";
    }

    my ($extern_image_mark,$imagesize);
    if ($thumbnail) {
	print "\nmaking thumbnail" if ($VERBOSITY > 1);
	if (($image_size{$thumbnail}) = &get_image_size($thumbnail,'')) {
	    $thumbnail = &find_unique($thumbnail);
	    $imagesize = " ".$image_size{$thumbnail};
	    if ($HTML_VERSION < 2.2 ) {
		# put the WIDTH/HEIGHT information into the ALT string
		# first removing the quotes
		my ($noquotes) = $imagesize;
		$noquotes =~ s/\"//g;
		$altst =~ s/"$/\% $noquotes "/m;
		$imagesize = '';
	    }
###Bo: insert an anchor
	    $anchorName = $thumbnail;
	    $anchorName =~ s/\.png//;
###
	    $extern_image_mark = join('',"<A NAME=$anchorName><IMG"
		, "\n$imagesize" 
		, (($aalign) ? " ALIGN=\"$aalign\"" : '')
		, ("$aalign$imagesize" ? "\n" : '' )
		, " SRC=\"$thumbnail\"$altst></A>");
	}
	$extern_image_mark =~ s/\s?BORDER="?\d+"?//
            unless ($exstr =~ /BORDER/i);
    } else { 
        # MRO: dubious (&extern_image_mark takes only one arg)
        $extern_image_mark = &extern_image_mark($IMAGE_TYPE,$altst);
    }

    my ($anch1,$anch2) = ('','');
    my $result;
    if ($external || $thumbnail || $EXTERNAL_IMAGES) {
	if ( $extern_image_mark ) {
	    $result = &make_href_noexpand($urlimg, $name , $extern_image_mark);
	    &save_image_map($url, $urlimg, $map, $name, $altst, $ausemp) if $map;
	}
    } else {
	if ($map) {
	    $anch1 = "<A HREF=\"$map\">";
	    $anch2 = "</A>";
	}
#	if ($aalign eq "CENTER") {
#	    if ($HTML_VERSION eq "2.0") {
#	        $anch1 .= "\n<P ALIGN=\"CENTER\">";
#	        $anch2 .= "</P>";
#	    } else {
#	        $anch1 .= "\n<DIV ALIGN=\"CENTER\">";
#	        $anch2 .= "</DIV>";
#	    }
#	}

	$imagesize = $image_size{$url};
	$imagesize = $usersize if (($usersize)&&($HTML_VERSION > 2.1 ));
	if ($HTML_VERSION < 2.2 ) {
	    # put the WIDTH/HEIGHT information into the ALT string
	    # first removing the quotes
	    my ($noquotes) = $imagesize;
	    $noquotes =~ s/\"//g;
	    $altst =~ s/"$/\% $noquotes "/m;
	}

	# include a stylesheet entry for each included image
	if ($USING_STYLES && $SCALABLE_IMAGES &&(!$imgID)) {
	    if ($url =~ /($dd|^)([^$dd$dd]+)\.$IMAGE_TYPE$/) {
		my $img_name = $2;
		$imgID = $img_name . ($img_name =~ /img/ ? '' : $IMAGE_TYPE);
		$img_style{"$imgID"} = ' ' unless $img_style{"$imgID"};
		$imgID = join('', ' CLASS="', $imgID, '"') if $imgID;
	    }
	}

	### MEH Add width and height to IMG
	### Patched by <hswan@perc.Arco.com>:  Fixed \htmladdimg 
	if ( $imagesize || $name eq "external image" || $NO_IMAGES || $PS_IMAGES) {
	    $imagesize = '' if ($HTML_VERSION < 2.2 );
	    if ($border =~ s/^"//) { $border .= '"' };
	    $result = join(''
		   , "<IMG$imgID"
		   , "\n", ($imagesize ? " $imagesize" : '')
		   , (($aalign)? " ALIGN=\"$aalign\"" : $border)
		   , $ismap );
	    if ($ausemp) { $result .= " $ausemp" }
	    $result .= "\n" unless (($result =~ /\n *$/m)|| !$imagesize);
	    $result .= " SRC=\"$url\"";
	    if ($altst) { $result .= $altst }
	    $result .= ">";
	}
    }
    join('',$anch1, $result, $anch2);
}

# MRO: added PNG support
sub get_image_size { # clean
    my ($imagefile, $scale) = @_;

    $scale = '' if ($scale == 1);
    my ($imgID,$size) = ('','');
    if (open(IMAGE, "<$imagefile")) {
        my ($buffer,$magic,$dummy,$width,$height) = ('','','',0,0);
	binmode(IMAGE); # not harmful un UNIX
        if ($IMAGE_TYPE =~ /gif/) {
	    read(IMAGE,$buffer,10);
	    ($magic,$width,$height) = unpack('a6vv',$buffer);
            # is this image sane?
	    unless($magic =~ /^GIF8[79]a$/ && ($width * $height) > 0) {
                $width = $height = 0;
	    }
        }
        elsif ($IMAGE_TYPE =~ /png/) {
            read(IMAGE,$buffer,24);
	    ($magic,$dummy,$width,$height) = unpack('a4a12NN',$buffer);
	    unless($magic eq "\x89PNG" && ($width * $height) > 0) {
                $width = $height = 0;
            }
	}
	close(IMAGE);

	# adjust for non-trivial $scale factor.
        my ($img_w,$img_h) = ($width,$height);
	if ($scale && ($width * $height) > 0) {
            $img_w = int($width / $scale + .5);
            $img_h = int($height / $scale + .5);
	}
	$size = qq{WIDTH="$img_w" HEIGHT="$img_h"};

	# allow height/width to be stored in the stylesheet
	my ($img_name,$imgID);
	if ($SCALABLE_IMAGES && $USING_STYLES) {
	    if ($imagefile =~ /(^|[$dd$dd])([^$dd$dd]+)\.(\Q$IMAGE_TYPE\E|old)$/o) {
		$img_name = $2;
		$imgID = $img_name . ($img_name =~ /img/ ? '' : $IMAGE_TYPE);
	    }
	    if ($imgID) {
		$width = $width/$LATEX_FONT_SIZE/$MATH_SCALE_FACTOR;
		$height = 1.8 * $height/$LATEX_FONT_SIZE/$MATH_SCALE_FACTOR;
		# How wide is an em in the most likely browser font ?
		if ($scale) {
		# How high is an ex in the most likely browser font ?
		    $width = $width/$scale; $height = $height/$scale;
		}
		$width = int(100*$width + .5)/100;
		$height = int(100*$height + .5)/100;
		$img_style{$imgID} = qq(width:${width}em ; height:${height}ex );
		#join('','width:',$width,'em ; height:',$height,'ex ');
		$imgID = qq{ CLASS="$imgID"};
	    }
	}
    }
    ($size, $imgID);
}

sub find_unique { # clean
    my ($image1) = @_;
    local($/) = undef; # slurp in complete files

    my $imagedata;
    if(open(IMG1,"<$image1")) {
	binmode(IMG1); # needed with .png under DOS
        $imagedata = <IMG1>;
        close(IMG1);
    } else {
        print "\nError: Cannot read '$image1': $!\n"
	    unless ($image1 =~ /^\s*$HTTP_start/i);
        return $image1;
    }

    my ($image2,$result);
    foreach $image2 (keys(%image_size)) {
	if ( $image1 ne $image2 &&
	    $image_size{$image1} eq $image_size{$image2} ) {
	    if(open(IMG2,$image2)) {
		binmode(IMG2); # needed with .png under DOS
	        $result = ($imagedata eq <IMG2>);
	        close(IMG2);
            } else {
                print "\nWarning: Cannot read '$image2': $!\n"
		    unless ($image2 =~ /^\s*$HTTP_start/i);
            }
#
#  If we've found a match, rename the new image to a temporary one.
#  Then try to link the new name to the old image.
#  If the link fails, restore the temporary image.
#
	    if ( $result ) {
		my $tmp = "temporary.$IMAGE_TYPE";
		L2hos->Unlink($tmp);
		L2hos->Rename($image1, $tmp);
		if (L2hos->Link($image2, $image1)) {
                    L2hos->Unlink($tmp);
                } else {
                    L2hos->Rename($tmp, $image1);
                }
		return $image1;
	    }
	}
    }
    $image1;
}

sub save_image_map { # clean
    my ($url, $urlimg, $map, $name, $altst, $ausemp) = @_;
    unless(open(IMAGE_MAP, ">$urlimg")) {
        print "\nError: Cannot write '$urlimg': $!\n";
        return;
    }
    ### HWS  Pass server map unchanged from user
    print IMAGE_MAP "<HTML>\n<BODY>\n<A HREF=\"$map\">\n";
    print IMAGE_MAP "<IMG\n SRC=\"$url\" ISMAP $ausemp $altst> </A>";
    print IMAGE_MAP "</BODY>\n</HTML>\n";
    close IMAGE_MAP;
}

#  Subroutine used mainly to rename an old image file about to recycled.
#  But for active image maps, we must edit the auxiliary HTML file to point
#     to the newly renames image.
sub rename_html {
    local ($from, $to) = @_;
    local ($from_prefix, $to_prefix, $suffix);
    ($from_prefix, $suffix) = split(/\./, $from);
    ($to_prefix, $suffix) = split(/\./, $to);
    if ($EXTN =~ /$suffix$/) {
	if (open(FROM, "<$from") && open(HTMP, ">HTML_tmp")) {
	    while (<FROM>) {
		s/$from_prefix\.$IMAGE_TYPE/$to_prefix.$IMAGE_TYPE/g;
		print HTMP;
	    }
	    close (FROM);
	    close (HTMP);
	    L2hos->Rename ("HTML_tmp", $to);
	    L2hos->Unlink($from) unless ($from eq $to);
	}
	else {
	    &write_warnings("File $from is missing!\n");
	}
    }
    L2hos->Rename("$from_prefix.old", "$to_prefix.$IMAGE_TYPE");
    $to;
}

sub save_captions_in_file {
    local ($type, $_) = @_;
    if ($_) {
	s/^\n//om;
	&replace_markers;
	&add_dir_to_href if ($DESTDIR);
	if(open(CAPTIONS, ">${PREFIX}$type.pl")) {
	    print CAPTIONS $_;
	    close (CAPTIONS);
        } else {
            print "\nError: Cannot write '${PREFIX}$type.pl': $!\n";
        }
    }
}

sub add_dir_to_href {
    $_ =~ s/'/\\'/g;
    $_ =~ s/(<LI><A )(NAME\=\"tex2html\d+\")?\s*(HREF=\")/$1$3\'.\$dir.\'/og;
    $_ = join('', "\'", $_, "\'\n");
}

sub save_array_in_file {
    local ($type, $array_name, $append, %array) = @_;
    local ($uutxt,$file,$prefix,$suffix,$done_file,$depth,$title);
    $prefix = $suffix = "";
    my $filespec = ($append ? '>>' : '>') . "${PREFIX}$type.pl";
    $prefix = q("$URL/" . )
	if ($type eq "labels") && !($array_name eq "external\_latex\_labels");
    $suffix = " unless (\$$array_name\{\$key\})"
	if (($type =~ /(sections|contents)/)||($array_name eq "printable\_key"));
    if ((%array)||($type eq "labels")) {
	print "\nSAVE_ARRAY:$array_name in FILE: ${PREFIX}$type.pl"
	    if ($VERBOSITY > 1);
	unless(open(FILE,$filespec)) {
            print "\nError: Cannot write '${PREFIX}$type.pl': $!\n";
            return;
        }
	if (($array_name eq "sub\_index") || ($array_name eq "printable\_key")) {
	    print FILE "\n# LaTeX2HTML $TEX2HTMLVERSION\n";
	    print FILE "# Printable index-keys from $array_name array.\n\n";
	} elsif ($array_name eq "index\_labels") {
	    print FILE "\n# LaTeX2HTML $TEX2HTMLVERSION\n";
	    print FILE "# labels from $array_name array.\n\n";
	} elsif ($array_name eq "index\_segment") {
	    print FILE "\n# LaTeX2HTML $TEX2HTMLVERSION\n";
	    print FILE "# segment identifier from $array_name array.\n\n";
	} elsif ($array_name eq "external\_latex\_labels") {
	    print FILE "\n# LaTeX2HTML $TEX2HTMLVERSION\n";
	    print FILE "# labels from $array_name array.\n\n";
	} else {
	    print FILE "# LaTeX2HTML $TEX2HTMLVERSION\n";
	    print FILE "# Associate $type original text with physical files.\n\n";
	}
	while (($uutxt,$file) = each %array) {
	    $uutxt =~ s|/|\\/|g;
	    $uutxt =~ s|\\\\/|\\/|g;

	    if (!($array_name =~/images/)&&($file =~ /</)) {
		do { local $_ = $file;
		     &replace_markers;
		     $file = $_; undef $_;
		     $file =~ s/(\G|[^q])[\\\|]\|/$1\\Vert/sg;
		     $file =~ s/(\G|[^q])\|/$1\\vert/sg;
		};
	    }

	    local ($nosave); 	
	    if ($MULTIPLE_FILES && $ROOTED && 
	    	    $type =~ /(sections|contents)/) {
		#RRM: save from $THIS_FILE only
	    	if ( $uutxt =~ /^$THIS_FILE /) {
		    #RRM: save from $THIS_FILE only
	    	    $nosave = ''
	    	} else { $nosave = 1 }
	    } else {
		#RRM: suppress info from other segments
	        $nosave = $noresave{$uutxt}; 
	    }

	    if (!$nosave && ($file ne ''))  {
		print FILE "\n\$key = q/$uutxt/;\n";

		$file =~ s/\|/\\\|/g; # RRM:  escape any occurrences of |
		$file =~ s/\\\\\|/\\\|/g; # unless already escaped as \|
		$file =~ s|\\\\|\\\\\\\\|g;
		$file =~ s/(SRC=")($HTTP_start)?/$1.($2 ? '' :"|.\"\$dir\".q|").$2/seg;
#
#
# added code for  $dir  with segmented docs;  RRM  15/3/96
#
		if ($type eq "contents") {
		    ($depth, $done_file) = split($delim, $file, 2 );
		    next if ($depth > $MAX_SPLIT_DEPTH + $MAX_LINK_DEPTH);
		    print FILE 
    "\$$array_name\{\$key\} = '$depth$delim'.\"\$dir\".q|$done_file|$suffix; \n";

		} elsif ($type eq "sections") {
		    ($depth, $done_file) = split($delim, $file, 2 );
		    next if ($depth > $MAX_SPLIT_DEPTH + $MAX_LINK_DEPTH);
		    print FILE 
    "\$$array_name\{\$key\} = '$depth$delim'.\"\$dir\".q|$done_file|$suffix; \n";

		} elsif ($type eq "internals") {
		    print FILE 
    "\$$array_name\{\$key\} = \"\$dir\".q|$file|$suffix; \n";

		} elsif ($array_name eq "sub_index") {
		    print FILE
    "\$$array_name\{\$key\} .= q|$file|$suffix; \n";

		} elsif ($array_name eq "index") {
		    local($tmp_file) = '';
		    ($depth, $done_file) = split('HREF=\"', $file, 2 );
		    if ($done_file) {
			while ($done_file) {
			    $depth =~ s/\s*$/ / if ($depth);
			    $tmp_file .= "q|${depth}HREF=\"|.\"\$dir\".";
			    ($depth, $done_file) = split('HREF=\"', $done_file, 2 );
			}
			print FILE
    "\$$array_name\{\$key\} .= ${tmp_file}q|$depth|$suffix; \n";

		    } else {
			print FILE
    "\$$array_name\{\$key\} .= q|$file|$suffix; \n";
		    }
		} elsif ($array_name eq "printable_key") {
		    print FILE
    "\$$array_name\{\$key\} = q|$file|$suffix; \n";

		} else {
		    print FILE
    "\$$array_name\{\$key\} = ${prefix}q|$file|$suffix; \n";
		}

		if ($type =~ /(figure|table|images)/) {} else {
		    print FILE "\$noresave\{\$key\} = \"\$nosave\";\n";
		}

		if ($type eq "sections") {
		    ($depth, $done_file, $title) = split($delim, $file);
		    print FILE "\$done\{\"\$\{dir\}$done_file\"\} = 1;\n";
		}
	    }
	}
	print FILE "\n1;\n\n"  unless  ( $array_name =~ /index/ );
	close (FILE);
    } else {
	print "\nSAVE_FILE:$array_name: ${PREFIX}$type.pl  EMPTY " if ($VERBOSITY > 1);
    }
}

# returns true if $AUTO_NAVIGATION is on and there are more words in $_
# than $WORDS_IN_PAGE
sub auto_navigation {
    # Uses $_;
    local(@tmp) = split(/\W*\s+\W*/, $_);
    ($AUTO_NAVIGATION && ( (scalar @tmp) > $WORDS_IN_PAGE));
}

# Returns true if $f1 is newer than $f2
sub newer {
    ($f1,$f2) = @_;
    local(@f1s) = stat($f1);
    local(@f2s) = stat($f2);
    ($f1s[9] > $f2s[9]);
};

sub iso_map {
    local($char, $kind, $quiet) = @_;
    my($character_map,$enc);
    local ($this);

    if ( $CHARSET && $HTML_VERSION ge "2.1" ) {
	# see if it is a character in the charset
	$character_map = ((($charset =~ /utf/)&&!$NO_UTF)?
			  'iso_10646' : $CHARSET );
	$character_map =~ tr/-/_/;
	eval "\$enc = \$${character_map}_character_map\{\"$char$kind\"\}";
	print "\n no support for $CHARSET: $@ " if ($@);
    }
    if ($USE_ENTITY_NAMES && $enc) { return(";SPM$char$kind;") }

    if ($enc) {
	$enc =~ /^\&\#(\d{3});$/;
	# maybe convert it to an 8-bit character
	if ($NO_UTF && !$USE_UTF && ($1<=255)) { $enc = chr($1) }
#	elsif (!$USE_UTF &&($1>127)&&($1<160)) { $enc = chr($1) }
	elsif ($character_map !~ /^iso_(8859_1|10646)/) {
	# get its latin1 or unicode entity encoding
	    $enc = $iso_8859_1_character_map{"$char$kind"}
	        ||$iso_8859_1A_character_map{"$char$kind"}
	        ||$iso_10646_character_map{"$char$kind"}
	}
     } else {
	# get its latin1 or unicode entity encoding, if available
	$enc = $iso_8859_1_character_map{"$char$kind"}
	    ||$iso_8859_1A_character_map{"$char$kind"}
	    ||$iso_10646_character_map{"$char$kind"};
    }

    if ($enc) {
	$ISOLATIN_CHARS = 1; $enc;
    } elsif (!$image_made{"$char$kind"}) {
	print "\ncouldn't convert character $char$kind into available encodings"
	    if (!quiet &&($VERBOSITY > 1));
	&write_warnings(
	    "couldn't convert character $char$kind into available encodings"
	    . ($ACCENT_IMAGES ? ', using image' : '')) unless ($quiet);
	$image_made{"$char$kind"} = 1;
	'';
    } else {''}
}

sub titles_language {
    local($_) = @_;
    local($lang) = $_ . "_titles";
    if (defined(&$lang)) { &$lang }
    else {
	&english_titles;
	&write_warnings(
	    "\nThere is currently no support for the $tmp language." .
	    "\nSee the file $CONFIG_FILE for examples on how to add it\n\n");
    }
}

sub translate_titles {
    $toc_title = &translate_commands($toc_title) if ($toc_title =~ /\\/);
    $lof_title = &translate_commands($lof_title) if ($lof_title =~ /\\/);
    $lot_title = &translate_commands($lot_title) if ($lot_title =~ /\\/);
    $idx_title = &translate_commands($idx_title) if ($idx_title =~ /\\/);
    $ref_title = &translate_commands($ref_title) if ($ref_title =~ /\\/);
    $bib_title = &translate_commands($bib_title) if ($bib_title =~ /\\/);
    $abs_title = &translate_commands($abs_title) if ($abs_title =~ /\\/);
    $app_title = &translate_commands($app_title) if ($app_title =~ /\\/);
    $pre_title = &translate_commands($pre_title) if ($pre_title =~ /\\/);
    $foot_title = &translate_commands($foot_title) if ($foot_title =~ /\\/);
    $fig_name = &translate_commands($fig_name) if ($fig_name =~ /\\/);
    $tab_name = &translate_commands($tab_name) if ($tab_name =~ /\\/);
    $prf_name = &translate_commands($prf_name) if ($prf_name =~ /\\/);
    $page_name = &translate_commands($page_name) if ($page_name =~ /\\/);
    $child_name = &translate_commands($child_name) if ($child_name =~ /\\/);
    $info_title = &translate_commands($info_title) if ($info_title =~ /\\/);
    $part_name = &translate_commands($part_name) if ($part_name =~ /\\/);
    $chapter_name = &translate_commands($chapter_name)
	if ($chapter_name =~ /\\/);
    $section_name = &translate_commands($section_name)
	if ($section_name =~ /\\/);
    $subsection_name = &translate_commands($subsection_name)
	if ($subsection_name =~ /\\/);
    $subsubsection_name = &translate_commands($subsubsection_name)
	if ($subsubsection_name =~ /\\/);
    $paragraph_name = &translate_commands($paragraph_name)
	if ($paragraph_name =~ /\\/);
    $see_name = &translate_commands($see_name) if ($see_name =~ /\\/);
    $also_name = &translate_commands($also_name) if ($also_name =~ /\\/);
    $next_name = &translate_commands($next_name) if ($next_name =~ /\\/);
    $prev_name = &translate_commands($prev_name) if ($prev_name =~ /\\/);
    $up_name = &translate_commands($up_name) if ($up_name =~ /\\/);
    $group_name = &translate_commands($group_name) if ($group_name =~ /\\/);
    $encl_name = &translate_commands($encl_name) if ($encl_name =~ /\\/);
    $headto_name = &translate_commands($headto_name) if ($headto_name =~ /\\/);
    $cc_name = &translate_commands($cc_name) if ($cc_name =~ /\\/);
    $default_title = &translate_commands($default_title)
	if ($default_title =~ /\\/);
}
####################### Code Generation Subroutines ############################
# This takes a string of commands followed by optional or compulsory
# argument markers and generates a subroutine for each command that will
# ignore the command and its arguments.
# The commands are separated by newlines and have the format:
##      <cmd_name>#{}# []# {}# [] etc.
# {} marks a compulsory argument and [] an  optional one.
sub ignore_commands {
    local($_) = @_;
    foreach (/.*\n?/g) {
	s/\n//g;
	# For each line
	local($cmd, @args) = split('\s*#\s*',$_);
	next unless $cmd;
	$cmd =~ s/ //;
	++$ignore{$cmd};
	local ($body, $code, $thisone) = ("", "");
	
	# alter the pattern here to debug particular commands
	$thisone = 1 if ($cmd =~ /let/);

	if (@args) {
	    print "\n$cmd: ".scalar(@args)." arguments" if ($thisone);
	    # Replace the argument markers with appropriate patterns
	    foreach $arg (@args) {
		print "\nARG: $arg" if ($thisone);
		if ($arg =~ /\{\}/) {
		    $body .= 'local($cmd) = '."\"$cmd\"".";\n";
		    $body .= '$args .= &missing_braces'."\n ".'unless (';
		    $body .= '(s/$next_pair_pr_rx/$args .= $2;\'\'/eo)'."\n";
		    $body .= '  ||(s/$next_pair_rx/$args .= $2;\'\'/eo));'."\n";
		    print "\nAFTER:$'" if (($thisone)&&($'));
		    $body .= $' if ($');
		} elsif ($arg =~ /\[\]/) {
		    $body .= '($dummy, $pat) = &get_next_optional_argument;'
			. '$args .= $pat;'."\n";
		    print "\nAFTER:$'" if (($thisone)&&($'));
		    $body .= $' if ($');
		} elsif ($arg =~ /^\s*\\/) {		    
		    $body .= '($dummy, $pat) = &get_next_tex_cmd;'
			. '$args .= $pat;'."\n";
		    print "\nAFTER:$'" if (($thisone)&&($'));
		    $body .= $' if ($');
		} elsif ($arg =~ /<<\s*([^>]*)[\b\s]*>>/) {
		    local($endcmd, $after) = ($1,$');
		    $after =~ s/(^\s*|\s*$)//g;
		    $endcmd = &escape_rx_chars($endcmd);
		    $body .= 'if (/'.$endcmd.'/o) { $args .= $`; $_ = $\' };'."\n";
		    print "\nAFTER:$after" if (($thisone)&&($after));
		    $body .= "$after" if ($after);
		} else {
		    print "\nAFTER:$'" if (($thisone)&&($arg));
		    $body .= $arg ;
		}
	    }
	    # Generate a new subroutine
#	    $code = "sub do_cmd_$cmd {\n".'local($_) = @_;'. join('',@args) .'$_}';
	    $code = "sub do_cmd_$cmd {\n"
		. 'local($_,$ot) = @_; '
		. 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R; '
		. 'local($args); '
		. "\n" . $body . (($body)? ";\n" : '')
		. (($thisone)? "print \"\\n$cmd:\".\$args.\"\\n\";\n" : '')
		. (($arg)? $arg : '$_') . "}";
	    print STDOUT "\n$code\n" if ($thisone); # for error-checking
	    eval ($code); # unless ($thisone);
	    print STDERR "\n\n*** sub do_cmd_$cmd failed: $@\n" if ($@);
	} else {
	    $code = "sub do_cmd_$cmd {\n".'$_[0]}';
	    print "\n$code\n" if ($thisone); # for error-checking
	    eval ($code); # unless ($thisone);
	    print STDERR "\n\n*** sub do_cmd_$cmd failed: $@\n" if ($@);
        }
    }
}


sub ignore_numeric_argument {
    # Chop this off
    #RRM: 2001/11/8: beware of taking too much, when  <num> <num> 
    local($num) = '(^|width|height|plus|minus)\s*[+-]?[\d\.]+(cm|em|ex|in|pc|pt|mm)?\s*';
    do { s/^\s*=?\s*//so; s/^($num)*//so } unless (/^(\s*\<\<\d+\>\>|$)/);
}

sub get_numeric_argument {
    my ($num_rx,$num) = ('','');
    # Collect the numeric part
    #RRM: 2001/11/8: beware of taking too much, when  <num> <num> 
    $num_rx = '(^|width|height|plus|minus)\s*[+-]?[\d\.]+(cm|em|ex|in|pc|pt|mm)?\s*';
    do { s/^\s*=?\s*//so; s/($num_rx)*/$num=$&;''/soe } unless (/^(\s*\<\<\d+\>\>|$)/);
    $num;
}

sub process_in_latex_helper {
    local($ctr,$val,$cmd) = @_;
    ($ASCII_MODE ? "[$cmd]" : 
	&process_in_latex("\\setcounter{$ctr}{$val}\\$cmd"))
}

sub do_cmd_catcode {
    local($_) = @_;
    s/^\s*[^=]+(=?\s*\d+\s|\\active)\s?//;
    $_;
}

sub do_cmd_string {
    local($_) = @_;
    local($tok);
    s/^\s*(\\([a-zA-Z]+|.)|[&;]\w+;(#\w+;)?|.)/$tok=$1;''/e;
    if ($2) {$tok = "\&#92;$2"};
    "$tok".$_
}

sub do_cmd_boldmath {
    local($_) = @_;
    $BOLD_MATH = 1;
    $_;
}

sub do_cmd_unboldmath {
    local($_) = @_;
    $BOLD_MATH = 0;
    $_;
}

sub do_cmd_lq {
    local($_) = @_ ;
    local($lquote);
    # check for double quotes
    if (s/^\s*\\lq(\b|$|[^A-Za-z])/$1/) {
	$lquote = ((($HTML_VERSION < 4)&&!($charset =~ /utf/)) ? '``'
		: &do_leftquotes($_));
    } else {
	$lquote = ((($HTML_VERSION < 4)&&!($charset =~ /utf/)) ? '`'
		: &do_leftquote($_));
    }
    $lquote . $_;
}

sub do_leftquote {
    # MRO: use $_[0] : local(*_) = @_;
    local($quote,$lquo) = ('',($HTML_VERSION<5)? '&#8216;' : ';SPMlsquo;');
    # select whole quotation, if \lq matches \rq
    if ($_[0] =~ /^(.*)((\\rq\\rq|'')*)(\\rq)/) {
	$quote = $1.$2; $_[0] = $';
	local($rquo) = &do_rightquote();
	&process_quote($lquo,$quote,$rquo);
    } else { $lquo; }
}

sub do_leftquotes {
    # MRO: use $_[0] : local(*_) = @_;
    local($quote,$lquo) = ('',($HTML_VERSION<5)? '&#8220;' : ';SPMldquo;');
    # select whole quotation, if \lq\lq matches \rq\rq or ''
    if ($_[0] =~ /^(.*)(\\rq\\rq|'')/) {
	$quote = $1; $_[0] = $';
	local($rquo) = &do_rightquotes();
	&process_quote($lquo,$quote,$rquo);
    } else { $lquo; }
}

# RRM: By default this just concatenates the strings; e.g. ` <quote> '
# This can be overridden in a html-version file
sub process_quote { join ('', @_) }

sub do_cmd_rq {
    local($_) = @_ ;
    local($rquote);
    if ($_ =~ s/^\s*\\rq\b//) {
	$rquote = ((($HTML_VERSION < 4)&&!($charset =~ /utf/)) ? "''"
		: &do_rightquotes());
    } else { 
	$rquote = ((($HTML_VERSION < 4)&&!($charset =~ /utf/)) ? "'"
		: &do_rightquote());
    }
    $rquote . $_;
}

sub do_rightquote { (($HTML_VERSION < 5)? '&#8217;' : ';SPMrsquo;') }
sub do_rightquotes { (($HTML_VERSION < 5)? '&#8221;' : ';SPMrdquo;') }

sub do_cmd_parbox {
    local($_) = @_;
    local($args, $contents, $dum, $pat);
#    $* = 1;			# Multiline matching ON
    ($dum,$pat) = &get_next_optional_argument; # discard this
    ($dum,$pat) = &get_next_optional_argument; # discard this
    ($dum,$pat) = &get_next_optional_argument; # discard this
    $args .= $pat if ($pat);
    $pat = &missing_braces unless (
	(s/$next_pair_pr_rx/$pat=$2;''/eom)
	||(s/$next_pair_rx/$pat=$2;''/eom));
    $args .= "{".$`.$pat."}";
    $contents = &missing_braces unless (
	(s/$next_pair_pr_rx/$contents=$2;''/eom)
	||(s/$next_pair_rx/$contents=$2;''/eom));
 #   $* = 0;			# Multiline matching OFF
    $args .= "{".$`.$contents."}";
    if ($NO_PARBOX_IMAGES) {
	$contents = join ('', &do_cmd_par(), $contents, '</P>' );
    } else {
	$contents = &process_math_in_latex('','text',0,"\\parbox$args")
	    if ($contents);
    }
    $contents . $_;
}


sub do_cmd_mbox {
    local($_) = @_;
    local($text,$after)=('','');
    $text = &missing_braces unless (
	(s/$next_pair_pr_rx/$text = $2;''/eo)
	||(s/$next_pair_rx/$text = $2;''/eo));
    $after = $_;

    # incomplete macro replacement
    if ($text =~ /(^|[^\\<])#\d/) { return($after) }

    if ($text =~ /(tex2html_wrap_inline|\$$OP(\d+)$CP$OP\2$CP\$|\$$O(\d+)$C$O\2$C\$)/) {
	if ($text =~ 
	    /$image_mark#([^#]+)#([\.,;:\)\]])?(\001)?([ \t]*\n?)(\001)?/) {
	    local($mbefore, $mtext, $mafter) = ($`, $&, $');
	    $mbefore = &translate_commands($mbefore) if ($mbefore =~ /\\/);
	    $mafter = &translate_commands($mafter) if ($mafter =~ /\\/);
	    join('', $mbefore, $mtext, $mafter, $after);
	} else {
	    join ('', &process_math_in_latex('','','',"\\hbox{$text}"), $after )
	}
    } else {
	$text = &translate_environments($text);
	$text = &translate_commands($text);
	join('', $text, $after);
    }
}



# *Generates* subroutines to handle each of the declarations
# like \em, \quote etc., in case they appear with the begin-end
# syntax.
sub generate_declaration_subs {
    local($key, $val, $pre, $post, $code );
    print "\n *** processing declarations ***\n";
    while ( ($key, $val) = each %declarations) {
	if ($val) {
	    ($pre,$post) = ('','');
	    $val =~ m|</.*$|;
	    do {$pre = $`; $post = $& } unless ($` =~ /^<>/);
	    $pre =~ s/"/\\"/g; $post =~ s/"/\\"/g;
	    $code = "sub do_env_$key {"
#		. 'local($_) = @_;' . "\n"
#		. 'push(@$open_tags_R, $key);'. "\n"
#		. '$_ = &translate_environments($_);'. "\n"
#		. '$_ = &translate_commands($_);'. "\n"
#		. "join('',\"$pre\",\"\\n\"," .'$_' .",\"$post\");\n};";
		. '&declared_env('.$key.',@_)};';
	    eval $code;
	    if ($@) {print "\n *** $key ".  $@ };
	}
    }
}

# *Generates* subroutines to handle each of the sectioning commands.
sub generate_sectioning_subs {
    local($key, $val, $cmd, $body);
    while ( ($key, $val) = each %standard_section_headings) {
	$numbered_section{$key} = 0;
	eval "sub do_cmd_$key {"
	    . 'local($after,$ot) = @_;'
	    . 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R;'
            . '&reset_dependents('. $key . ');'
            . '&do_cmd_section_helper('.$val.','.$key.');}';
	print STDERR "\n*** sub do_cmd_$key failed:\n$@\n" if ($@);
	# Now define the *-form of the same commands. The difference is that the
	# $key is not passed as an argument.
	eval "sub do_cmd_$key" . "star {"
	    . 'local($after,$ot) = @_;'
	    . 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R;'
	    . '&do_cmd_section_helper(' . $val . ');}';
	print STDERR "\n*** sub do_cmd_${key}star failed:\n$@\n" if ($@);
	# Now define the macro  \the$key  
	&process_commands_wrap_deferred("the$key \# {}\n");
###	local($_) = "<<1>>$key<<1>>";
	$body = "<<1>>$key<<1>>";
	&make_unique($body);
	$cmd = "the$key";
	eval "sub do_cmd_$cmd {"
	    . 'local($after,$ot) = @_;'
	    . 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R;'
	    . '&do_cmd_arabic(' . "\"$body\"" . ").\$after;};";
	print STDERR "\n*** sub do_cmd_$cmd failed:\n$@\n" if ($@);
	$raw_arg_cmds{$cmd} = 1;
    }
    &addto_dependents('chapter','section');
    &addto_dependents('section','subsection');
    &addto_dependents('subsection','subsubsection');
    &addto_dependents('subsubsection','paragraph');
    &addto_dependents('paragraph','subparagraph');
}

sub addto_dependents {
    local($ctr, $dep) = @_;
    local($tmp, $depends);
    if ($depends = $depends_on{$dep}) {
	&remove_dependency($depends, $dep) }
    $depends_on{$dep} = $ctr;

    $tmp = $dependent{$ctr};
    if ($tmp) { 
	$dependent{$ctr} = join($delim, $tmp, $dep);
    } else { $dependent{$ctr} = $dep }
}

sub remove_dependency {
    local($ctr, $dep) = @_;
    local(@tmp, $tmp, $dtmp);
    print "\nremoving dependency of counter {$dep} from {$ctr}\n";
    foreach $dtmp (split($delim, $dependent{$ctr})) {
	push(@tmp, $dtmp) unless ($dtmp =~ /$dep/);
    }
    $dependent{$ctr} = join($delim, @tmp);
}


# Uses $after which is defined in the caller (the caller is a generated subroutine)
# Also uses @curr_sec_id
#
#JCL(jcl-tcl) (changed almost everything)
#
sub do_cmd_section_helper {
    local($H,$key) = @_;
    local($section_number, $titletext, $title_key, @tmp, $align, $dummy);
    local($anchors,$pre,$run_title,$_) = ('', "\n", '', $after);
    local($open_tags_R) = [];

    # if we have a $key the current section is not of the *-form, so we need
    # to update the counters.
    &do_cmd_stepcounter("${O}0$C$key${O}0$C")
#	if ($key && !$making_name);
#	if ($key && !($unnumbered_section_commands{$key}) && !$making_name);
	if ($key && !($unnumbered_section_commands{$key}));
#   $latex_body .= "\\stepcounter{$key}\n" if $key;
#   &reset_dependents($key) if ($dependent{$key});

    local($br_id);
#    if ($USING_STYLES) {
#	$txt_style{"H$H.$key"} = " " unless $txt_style{"H$H.$key"}; 
#	$H .= " CLASS=\"$key\"; 
#    };

    local ($align, $dummy)=&get_next_optional_argument;
    if (($align =~/^(left|right|center)$/i)&&($HTML_VERSION > 2.0)) {
        $align = "ALIGN=\"$1\"";
    } elsif ($align) {
	# data was meant to be a running-head !
	$br_id = ++$global{'max_id'};
	$run_title = &translate_environments("$O$br_id$C$align$O$br_id$C");
	$run_title = &translate_commands($run_title) if ($run_title =~ /\\/);
	$run_title =~ s/($O|$OP)\d+($C|$CP)//g;
	$align = '';
    } else {
    }
    $titletext = &missing_braces 
	unless s/$next_pair_rx/$titletext=$2;''/eo;
    $br_id = ++$global{'max_id'};
    $titletext = &translate_environments("$O$br_id$C$titletext$O$br_id$C");

    $title_key = $run_title || $titletext;
    $title_key =~ s/$image_mark\#([^\#]+)\#(\\space)?/&purify_caption($1)/e;
    # This should reduce to the same information as contained in the .aux file.
    $title_key = &sanitize(&simplify($title_key));

    # RRM: collect all anchors from \label and \index commands
    ($anchors,$titletext) = &extract_anchors($titletext);
    local($saved_title) = $titletext;
    do {
        # to ensure a style ID is not saved and re-used in (mini-)TOCs
	local($USING_STYLES) = 0;
	$titletext = &translate_environments($titletext);
	$titletext = &translate_commands($titletext) 
	    if ($titletext =~/\\/);
    };
    # but the style ID can be used for the title on the HTML page
    if (!($titletext eq $saved_title)) {
	$saved_title = &translate_environments($saved_title);
	$saved_title = &translate_commands($saved_title) 
	    if ($saved_title =~/\\/);
	$saved_title = &simplify($saved_title);
    }
    local($closures) = &close_all_tags();
    $saved_title .= $closures;
    $title_text .= $closures;

    # This is the LaTeX section number read from the $FILE.aux file
    @tmp = split(/$;/,$encoded_section_number{$title_key});
    $section_number = shift(@tmp);
    $section_number = "" if ($section_number eq "-1");
    $encoded_section_number{$title_key} = join($;, @tmp)
#	unless (defined $title);
	unless ($title);

    # need to check also &{wrap_cmd_... also, if \renewcommand has been used; 
    # thanks Bruce Miller
    local($thehead,$whead) = ("do_cmd_the$key","wrap_cmd_the$key");
#    $thehead = ((defined &$thehead)? 
#	&translate_commands("\\the$key") : '');
    $thehead = ((defined &$thehead)||(defined &$whead)
	? &translate_commands("\\the$key") : '');
    $thehead .= $SECNUM_PUNCT
	if ($SECNUM_PUNCT &&($thehead)&& !($thehead =~ /\./));
    $section_number = $thehead if (($thehead)&&($SHOW_SECTION_NUMBERS));

    #JKR: Don't prepend whitespace 
    if ($section_number) {
	$titletext = "$section_number " . $titletext;
	$saved_title = "$section_number " . $saved_title;
	$run_title = "$section_number " . $run_title if $run_title;
    }

#    $toc_sec_title = $titletext;
#    $toc_sec_title = &purify($titletext);
    $toc_sec_title = &simplify($titletext);
    $titletext = &simplify($titletext);
#    $TITLE = &purify($titletext);
    local($after) = $_;
    do {
	local($_) = $titletext; &remove_anchors; 
	if ($run_title) {
	    $TITLE = $run_title;
	} elsif ($_) {
	    $TITLE = $_
	} else { $TITLE = '.' };
    };
    $global{$key}-- if ($key && $making_name);
    return ($TITLE) if (defined $title);

    #RRM: no preceding \n when this is the first section-head on the page.
    if (! $key || $key < $MAX_SPLIT_DEPTH) { $pre = '' };
    if ( defined &make_pre_title) {
	$pre = &make_pre_title($saved_title, $H);
    }

    undef $open_tags_R;
    $open_tags_R = [ @save_open_tags ];
    
    join('', $pre, &make_section_heading($saved_title, $H, $align.$anchors)
	, $open_all, $_);
}

sub do_cmd_documentclass {
    local($_) = @_;
    local ($docclass)=('');
    local ($cloptions,$dum)=&get_next_optional_argument;
    $docclass = &missing_braces unless (
	(s/$next_pair_pr_rx/$docclass = $2;''/eo)
	||(s/$next_pair_rx/$docclass = $2;''/eo));
    local($rest) = $';
    &do_require_package($docclass);
    if (! $styles_loaded{$docclass}) {
	&no_implementation("document class",$docclass);
    } else {
	if($cloptions =~ /\S+/) { # are there any options?
	    &do_package_options($docclass,$cloptions);
	}
    }
    $rest;
}
sub do_cmd_documentstyle { &do_cmd_documentclass($_[0]); }

sub do_cmd_usepackage {
    local($_) = @_;
    # RRM:  allow lists of packages and options
    local ($package, $packages)=('','');
    local ($options,$dum)=&get_next_optional_argument;
    $packages = &missing_braces unless (
	(s/$next_pair_pr_rx/$packages = $2;''/eo)
	||(s/$next_pair_rx/$packages = $2;''/eo));
    local($rest) = $_;
    # MRO: The files should have already been loaded by
    #      TMP_styles, but we better make it sure.
    foreach $package (split (',',$packages)) {	# allow multiple packages
	$package =~ s/\s|\%|$comment_mark\d*//g; # remove whitespace 
	$package =~ s/\W/_/g; # replace non-alphanumerics
	&do_require_package($package);
	if (! $styles_loaded{$package}) {
	    &no_implementation("package",$package);
	} else {
	    if($options =~ /\S+/) { # are there any options?
		&do_package_options($package,$options);
	    }
	}
    }
    $rest;
}


sub no_implementation {
    local($what,$which)= @_;
    print STDERR "\nWarning: No implementation found for $what: $which";
}

sub do_cmd_RequirePackage {
    local($_)= @_;
    local($file);
    local($options,$dum)=&get_next_optional_argument;
    $file = &missing_braces unless (
	(s/$next_pair_pr_rx/$file = $2;''/eo)
	||(s/$next_pair_rx/$file = $2;''/eo));
    local($rest) = $_;
    $file =~ s/^[\s\t\n]*//o;
    $file =~ s/[\s\t\n]*$//o;
    # load the package, unless that has already been done
    &do_require_package($file) unless ($styles_loaded{$file});
    # process any options
    if (! $styles_loaded{$file}) {
	    &no_implementation("style",$file);
    } else {
	# process any options
	&do_package_options($file,$options) if ($options);
    }
    $_ = $rest;
    # ignore trailing optional argument
    local($date,$dum)=&get_next_optional_argument;
    $_;
}

sub do_cmd_PassOptionsToPackage {
    local($_) = @_;
    local($options,$file);
    $options = &missing_braces unless (
        (s/$next_pair_pr_rx/$options = $2;''/eo)
        ||(s/$next_pair_rx/$options = $2;''/eo));
    $file = &missing_braces unless (
        (s/$next_pair_pr_rx/$file = $2;''/eo)
        ||(s/$next_pair_rx/$file = $2;''/eo));
    $passedOptions{$file} = $options;
    $_;
}
sub do_cmd_PassOptionsToClass{ &do_cmd_PassOptionsToPackage(@_)}

sub do_package_options {
    local($package,$options)=@_;
    local($option);
    if ($passedOptions{$package}) { $options = $passedOptions{$package}.'.'.$options };
    foreach $option (split (',',$options)) {
        $option =~ s/^[\s\t\n]*//o;
        $option =~ s/[\s\t\n]*$//o;
	$option =~ s/\W/_/g; # replace non-alphanumerics
	next unless ($option);
        if (!($styles_loaded{$package."_$option"})) {
            &do_require_packageoption($package."_$option");
            if (!($styles_loaded{$package."_$option"})) {
		&no_implementation("option","\`$option\' for \`$package\' package\n");
	    }
	}
    }
    $rest;
}

sub do_class_options {
    local($class,$options)=@_;
    local($option);
    if ($passedOptions{$class}) { $options = $passedOptions{$class}.'.'.$options };
    foreach $option (split (',',$options)) {
        $option =~ s/^[\s\t\n]*//o;
        $option =~ s/[\s\t\n]*$//o;
	$option =~ s/\W/_/g; # replace non-alphanumerics
	next unless ($option);
        &do_require_package($option);
        if (!($styles_loaded{$class."_$option"})) {
            &do_require_packageoption($class."_$option");
            if (!($styles_loaded{$class."_$option"})) {
		&no_implementation("option","\`$option\' for document-class \`$class\'\n");
	    }
	}
    }
    $rest;
}

sub do_require_package {
    local($file)= @_;
    local($dir);
    #RRM: make common ps/eps-packages use  epsfig.perl
    $file = 'epsfig' if ($file =~ /^(psfig|epsf)$/);

    if ($file =~ /^graphicx$/) {
	# work-around the CVS repository bug: use graphixx , not graphicx
	foreach $dir (split(/$envkey/,$LATEX2HTMLSTYLES)) {
	    if (-f "$dir${dd}graphixx.perl") {
		$file = 'graphixx';
		last;
	    }
	}
    }

    
    if (! $styles_loaded{$file}) {
	# look for a file named ${file}.perl
	# MRO: use $texfilepath instead of `..'
	if ((-f "$texfilepath$dd${file}.perl") && ! $styles_loaded{$file}){
	    print STDOUT "\nPackage: loading $texfilepath$dd${file}.perl";
	    require("$texfilepath$dd${file}.perl");
	    $styles_loaded{$file} = 1;
	} else {
	    foreach $dir (split(/$envkey/,$LATEX2HTMLSTYLES)) {
		if ((-f "$dir$dd${file}.perl") && ! $styles_loaded{$file}){
		    print STDOUT "\nPackage: loading $dir$dd${file}.perl";
		    require("$dir$dd${file}.perl");
	    	    $styles_loaded{$file} = 1;
		    last;
		}
	    }
	}
    }
}

sub do_require_extension {
    local($file)= @_;
    local($dir);

    if (! $styles_loaded{$file}) {
	# look for a file named ${file}.pl
	# MRO: use $texfilepath instead of `..'
	if (-f "$texfilepath$dd${file}.pl") {
	    print STDOUT "\nExtension: loading $texfilepath$dd${file}.pl";
	    require("$texfilepath$dd${file}.pl");
	    ++$styles_loaded{$file};
	    $NO_UTF = 1 if (($file =~ /latin/)&&($charset =~/utf/));
	} else {
	    foreach $dir (split(/$envkey/,$LATEX2HTMLVERSIONS)) {
		if (-f "$dir$dd${file}.pl"){
		    print STDOUT "\nExtension: loading $dir$dd${file}.pl";
		    require("$dir$dd${file}.pl");
		    ++$styles_loaded{$file};
		    $NO_UTF = 1 if (($file =~ /latin/)&&($charset =~/utf/));
		    last;
		}
	    }
	}
    } else {
	if (($file =~ /latin|hebrew/)&&($charset =~/utf|10646/)
			&& $loading_extensions) {
	    $NO_UTF = 1;
	    $USE_UTF = 0;
	    print STDOUT "\n\n ...producing $CHARSET output\n";
	    $charset = $CHARSET;
	} 
    }
}

sub do_require_packageoption {
    local($option)= @_;
    local($do_option);
    # first look for a file named ${option}.perl
    &do_require_package($option) unless ($styles_loaded{$option});
    # next look for a subroutine named  do_$option
    $do_option = "do_$option";
    if (!($styles_loaded{$option}) && defined(&$do_option)) {
	&$do_option();
	$styles_loaded{$option} = 1;
    }
}

############################ Environments ################################

# This is a dummy environment used to synchronise the expansion
# of order-sensitive macros.
sub do_env_tex2html_deferred {
    local($_) = @_;
    local($tex2html_deferred) = 1;
    $_ = &process_command($single_cmd_rx,$_);
}

# catch wrapped commands that need not have been
sub do_env_tex2html_nomath_inline {
    local($_) = @_;
    s/^\s+|\s+$//gs;
    my($cmd) = $_;
    if ($cmd=~s/^\\([a-zA-Z]+)//s) { $cmd = $1 };
    return (&translate_commands($_)) if ($raw_arg_cmds{$cmd}<1);
    &process_undefined_environment($env, $id, $_);
}

# The following list environment subroutines still do not handle
# correctly the case where the list counters are modified (e.g. \alph{enumi})
# and the cases where user defined bullets are mixed with the default ones.
# e.g. \begin{enumerate} \item[(1)] one \item two \end{enumerate} will
# not produce the same bullets as in the dvi output.
sub do_env_itemize {
    local($_) = @_;
    $itemize_level++;
    #RRM - catch nested lists
    &protect_useritems($_);
    $_ = &translate_environments($_);

    local($bullet,$bulletx)=('&nbsp;','');
    SWITCH: {
	if ($itemize_level==1) { $bulletx = "\\bullet"; last SWITCH; }
	if ($itemize_level==2) { $bulletx = "\\mathbf{\\circ}"; last SWITCH; }
	if ($itemize_level==3) { $bulletx = "\\mathbf{\\ast}"; last SWITCH; }
    }
    $itemize_level--;

    if (/\s*$item_description_rx/) {
	# Contains user defined optional labels
	$bulletx = &do_cmd_mbox("${O}1$C\$$bulletx\$${O}1$C") if $bulletx;
	&do_env_description($_, " COMPACT", $bullet.$bulletx)
    } else { &list_helper($_,'UL'); }
}

sub do_env_enumerate {
    local($_) = @_;
# Reiner Miericke provided the main code; integrated by RRM: 14/1/97
# works currently only with 'enumerate' and derived environments
# explicit styled labels are computed for each \item
# ultimately the environment is done as:  &do_env_description($_, " COMPACT")
    ++$enum_level;
    local(%enum) = %enum;		# to allow local changes
# Reiner: \begin{enumerate}[<standard_label>]
    local($standard_label) = "";
    local(@label_fields);
    local($label_func, $preitems, $enum_type);
    local($rlevel) = &froman($enum_level); # e.g. 3 => iii

    # \begin{enumerate}[$standard_label]
    if (s/^$standard_label_rx//s) {		# multiline on/off ?
	# standard label should be used later to modify
	# entries in %enum
	$standard_label = $1;		# save the standard label
#	s/^$standard_label_rx//;	# and cut it off
	$standard_label =~ s/([\\\[\]\(\)])/\\$1/g; # protect special chars

	# Search for [aAiI1] which is not between a pair of { }
	# Other cases like "\theenumi" are not handled
	@label_fields = $standard_label =~ /$enum_label_rx/;
	if (($standard_label =~ /^[aAiI1]$/)&&(not(/item\s*\[/))) {
	    $enum_type = ' TYPE="'.$standard_label.'"';
	    $standard_label = '';
	} else {
	    $label_func = $enum_label_funcs{$label_fields[$#label_fields-1]} . 
		"(\'enum" . $rlevel . "\')";
	    $enum{'theenum' . $rlevel} = "\&$label_func";
#	local($thislabel) = "\&$label_func";
#	do { local($_) = $thislabel; &make_unique($_);
#	     $enum{'theenum' . $rlevel} = $_; };
	    $standard_label = 
		"\"$label_fields[0]\" . eval(\$enum{\"theenum$rlevel\"})"
		. ".\"$label_fields[$#label_fields]\"";
	    $enum{'labelenum' . $rlevel} = $standard_label;
	}
    }  elsif (s/^((.|\n)+?)\\item/$preitems=$1;"\\item"/es) {
	my $pre_preitems; local($cmd); $label_part;
	my $num_styles = join('|', values %enum_label_funcs );
	while ($preitems =~
	    /\s*\\renew(ed)?command\s*(($O|$OP)\d+($C|$CP))\\?((label|the)enum(\w+))\s*\2/) {
	    # this catches one  \renewcommand{\labelenum}{....} 
	    $pre_preitems .= $`; $preitems = $'; $cmd = $5;
	    &missing_braces unless (
	        ($preitems=~s/$next_pair_pr_rx\s*/$label_part=$2;''/oe)
	        ||($preitems=~s/$next_pair_rx\s*/$label_part=$2;''/oe));
	    $cmd =~ s/^label/the/;
	    $label_part=~s/\\($num_styles)\s*(($O|$OP)\d+($C|$CP))(\w+)\2/".\&$1\(\'$5\'\)."/g;
	    $label_part = '"'.$label_part.'"';
	    $enum{$cmd} = $label_part;
        }
	$standard_label = 
	    "\"$label_fields[0]\" . eval(\$enum{\"theenum$rlevel\"})"
	    . ".\"$label_fields[$#label_fields]\"" if ($cmd);
	$_ = $pre_preitems . $preitems . $_ if ($pre_preitems||$preitems);
    } else {
	@enum_default_type = ('A', '1', 'a', 'i', 'A') unless (@enum_default_type);
	$enum_type = $enum_level%4;
	$enum_type = ' Type="'.@enum_default_type[$enum_type].'"';
    }

    # enclose contents of user-defined labels within a group,
    # in case of style-change commands, which could bleed outside the label.
    &protect_useritems($_);
    $_ = &translate_environments($_);	#catch nested lists

    local($enum_result);
    if (($standard_label)||(/\\item\[/)) {
	# split it into items
	@items = split(/\\item\b/,$_);
	# save anything (non-blank) before the items actually start
	$preitems = shift(@items);
	$preitems =~ s/^\s*$//;
	local($enum_label);
	# prepend each item with an item label: \item => \item[<label>]
	foreach $item (@items) {
#	  unless ( $item =~ /^\s*$/ ) { # first line may be empty
	    $enum{"enum" . $rlevel}++;	# increase enumi
	    $enum_label = eval("$enum{'labelenum' . $rlevel}");
	    # insert a label, removing preceding space, BUT...
	    # do NOT handle items with existing labels
	    $item =~ s/^\s*//;
	    if ($item =~ s/^\s*\[([^]]*)\]//) {
		$enum{"enum" . $rlevel}--;
		$enum_label = "$1";
		local($processed) = ($enum_label =~/$OP/);
		$enum_label = join('',($processed ? "<#0#>" : "<<0>>")
		    ,$enum_label ,($processed ? "<#0#>" : "<<0>>"))
			if ($enum_label =~ /\\/);
		if ($processed) { &make_unique_p($enum_label) }
		elsif ($enum_label =~ /$O/) { &make_unique($enum_label) };
		$item = "[${enum_label}]".$item;
	    } else { 
		local($processed) = ($enum_label =~/$OP/);
		$enum_label = join('',($processed ? "<#0#>" : "<<0>>")
		    ,$enum_label ,($processed ? "<#0#>" : "<<0>>"))
			if ($enum_label =~ /\\/);
		if ($processed) { &make_unique_p($enum_label) }
		elsif ($enum_label =~ /$O/) { &make_unique($enum_label) };
		$item = "[$enum_label\]$item";
		$enum_label =~ s/\.$//;
	    }
	    if ($standard_label) {
	        $item =~ s/(\\labelitem$rlevel|$standard_label)/$enum_label/g
	    } else {
	        $item =~ s/(\\labelitem$rlevel)/$enum_label/g
	    }
	};
	$_ = join("\\item ", $preitems, @items);

	# Original, but $enum_result
	$enum_result = &do_env_description($_, " COMPACT");
    } else {
	$enum_result = &list_helper($_, "OL$enum_type", '', '');
    }

    #clean-up and revert the $enum_level
    $enum{"enum" . $rlevel} = 0;
    $enum{"enum" . &froman($enum_level)} = 0;
    --$enum_level;
    $enum_result;
}

sub do_env_list {
    local ($_) = @_;
    local ($list_type,$labels,$lengths) = ('UL','','');

    $labels = &missing_braces unless	 ( # get the label specifier
	(s/$next_pair_pr_rx/$labels=$2;''/e)
	||(s/$next_pair_rx/$labels=$2;''/e));

    $lengths = &missing_braces unless ( # get the length declarations
	(s/$next_pair_pr_rx/$lengths=$2;''/e)
	||(s/$next_pair_rx/$lengths=$2;''/e));
    # switch to enumerated style if they include a \usecounter.
    $list_type = 'OL' if $lengths =~ /\\usecounter/;

    /\\item\b/; local($preitems) = $`;
	$_ =~ s/^\Q$preamble//s if ($preitems);
    $preitems =~s/^\s*|\s*$//g;
    if ($preitems) {
	$preitems = &translate_environments($preitems);
	$preitems = &translate_commands($preitems) if ($preitems =~ /\\/);
#	&write_warnings("\nDiscarding: $preitems before 1st item in list")
#	    if ($preitems);
    }

    #RRM - catch nested lists
    #RRM unfortunately any uses of the \\usecounter  within \item s
    #    may be broken --- sigh.
    &protect_useritems($_);
    $_ = &translate_environments($_);

    if (($list_type =~ /OL/)&&($labels)) {
	local($br_ida,$br_idb,$label,$aft);
	$br_ida = ++$global{'max_id'};
	$lengths =~ s/\\usecounter((($O|$OP)\d+($C|$CP))[^<]+\2)/
		&make_nowrapper(1)."\\stepcounter$1".&make_nowrapper(0)/e;
	$labels = "$O$br_ida$C$lengths$O$br_ida$C".$labels;

#	s/\\item\b\s*([^\[])/do {
#		$label = $labels; $aft = $1;
#		$br_id = ++$global{'max_id'};
#		$label = &translate_environments(
#			"$O$br_id$C$label$O$br_id$C");
#		join('',"\\item\[" , $label, "\]$aft" );
#	    }/eg;
#	$labels ='';
    }

    if (($labels)||(/\\item\[/)) {
	$_ = &list_helper($_, 'DL', $labels, $lengths)
    } else {
	$_ = &list_helper($_, $list_type, '', $lengths)
    }
    $_;
}

sub do_env_trivlist {
    local($_) = @_;
    local($compact,$item_sep,$pre_items) = ' COMPACT';
    &protect_useritems($_);

    # assume no styles initially for this list
    local($close_tags,$reopens) = &close_all_tags();
    local($open_tags_R) = [];
    local(@save_open_tags) = ();

    # include \label anchors from [...] items
    s/$item_description_rx\s*($labels_rx8)?\s*/
	(($9)? "<A NAME=\"$9\">$1<\/A>" : $1 ) ."\n"/eg;
    # remove unwanted space before \item s
    s/[ \t]*\\item\b/\\item/g;
    
    local($this_item,$br_id) = ('','');
    local($this_sitem,$this_eitem) = ("\n<P>","</P>\n",'');

    # assume no sub-lists, else...  why use {trivlist} ?
    # extract up to the 1st \item
    local(@items) = split(/\\item\b/, $_);
    $pre_items = shift @items;
    $_ = '';
    while (@items) {
	$br_id = ++$global{'max_id'};
	$this_item = shift @items;
	$this_item = &translate_environments(
	     "$O$br_id$C".$pre_items.$this_item."$O$br_id$C" );
	if ($this_item =~ /\\/) {
	    $this_item = &translate_commands($this_item);
	    $_ .= join('' , $this_sitem 
		       , $this_item
		       # , $this_eitem
		       )
	} else { $_ .= $this_sitem . $this_item }
    }
	
    $_ = &translate_environments($_);
    $_ = &translate_commands($_);

    join('' , $close_tags , $_ , $reopens);

}

# enclose the contents of any user-defined labels within a group,
# else any style-change commands may bleed outside the label.
sub protect_useritems {
    # MRO: use $_[0] instead: local(*_) = @_;
    local($preitems, $thisitem);
    $_[0] =~ s/^$par_rx\s*//s; # discard any \par before 1st item

    # locate \item with optional argument 
    local($saveRS) = $/; undef $/;
    local(@preitems);
    # allow one level of nested []
    # MRO: Caution! We have a double-wildcarded RX here, this may cause
    # trouble. Should be re-coded.
    $_[0] =~ s/\\item[\s\r]*(\b(\[(([^\[\]]|\[[^]]*\])*)\])?|[^a-zA-Z\s])/
	$thisitem = " $1";
	if ($2) {
	    $br_id = ++$global{'max_id'};
	    $thisitem = '['.$O.$br_id.$C.$3.$O.$br_id.$C.']';
	};
	"\\item".$thisitem
    /egm;

    $/ = $saveRS;
    $_[0] = join(@preitems, $_[0]);
}

sub do_env_description {
    local($_, $compact, $bullet) = @_;
    #RRM - catch nested lists
    &protect_useritems($_);
    $_ = &translate_environments($_) unless ($bullet);

    # MRO: replaced $* with /m
    $compact = "" unless $compact;
    if ($compact) {		# itemize/enumerate with optional labels
	s/\n?$item_description_rx\s*($labels_rx8)?\s*/"\n<\/DD>\n<DT>". 
	    (($9)? "<A NAME=\"$9\">$1<\/A>" : $1 ) ."<\/DT>\n<DD>"/egm;
    } else {
	s/\n?$item_description_rx\s*($labels_rx8)?\s*/"\n<\/DD>\n<DT>". 
	    (($9)? "<A NAME=\"$9\"><STRONG>$1<\/STRONG><\/A>" 
	     : "<STRONG>$1<\/STRONG>") ."<\/DT>\n<DD>"/egm;
    }
    # and just in case the description is empty ...
#JCL(jcl-del) - $delimiter_rx -> ^$letters
    s/\n?\\item\b\s*([^$letters\\]|)\s*/\n<\/DD>\n<DT>$bullet<\/DT>\n<DD>$1/gm;
    s/^\s+//m;

    $_ = '<DD>'.$_ unless ($_ =~ s/^\s*<\/D(T|D)>\n?//s);
    $_ =~ s/\n$//s;
    "<DL$compact>\n$_\n</DD>\n</DL>";
}

sub list_helper {
    local($_, $tag, $labels, $lengths) = @_;
    local($item_sep,$pre_items,$compact,$etag,$ctag);
    $ctag = $tag; $ctag =~ s/^(.*)\s.*$/$1/;

    # assume no styles initially for this list
    local($close_tags,$reopens) = &close_all_tags();
    local($open_tags_R) = [];
    local(@save_open_tags) = ();

#    #RRM: cannot have anything before the first <LI>
#    local($savedRS) = $/; $/='';
#    $_ =~ /\\item[\b\r]/s;
#    if ($`) { 
#	$preitems = $`; $_ = $&.$';
#	$preitems =~ s/<P( [^>]*)?>//g;
#	$close_tags .= "\n".$preitems if $preitems;
#    }
#    $/ = $savedRS; 
#

#    $* = 1;			# Multiline matching ON
    if (($tag =~ /DL/)&&$labels) {
	local($label,$aft,$br_id);
	s/\\item\b[\s\r]*([^\[])/mdo {
		$label = $labels; $aft = $1;
		$br_id = ++$global{'max_id'};
		$label = &translate_environments(
			"$O$br_id$C$label$O$br_id$C");
		join('',"\\item\[" , $label, "\]$aft" );
	    }/eg;
    }
#    $* = 0;			# Multiline matching OFF

    # This deals with \item[xxx] ...
    if ($tag =~ /DL/) {
	$compact = ' COMPACT';
	# include \label anchors in the <DT> part
	# and  $pre_item  tags in the <DD> part:
	if ($labels && $lengths) { 
	    $item_sep = "\n</DD>\n<DT>";
	} else {
	    $item_sep = ($labels ? "<DT>$labels\n" : '') ."</DT>\n<DD>";
	}
	$etag = "\n</DD>";
	s/$item_description_rx[\r\s]*($labels_rx8)?[\r\s]*/"<DT>" .
	    (($9)? "<A NAME=\"$9\">$1<\/A>" : $1 ) ."\n<DD>"/egm;
    } else {
	$item_sep = "\n</LI>\n<LI>";
	$etag = "\n</LI>";
    }

    # remove unwanted space before \item s
    s/[ \t]*\\item\b/\\item/gm;

    #JCL(jcl-del) - $delimiter_rx -> ^$letters
    s/\n?\\item\b[\r\s]*/$item_sep/egm;

    #RRM: cannot have anything before the first <LI>
    local($savedRS) = $/; $/='';
    $_ =~ /\Q$item_sep\E|<DT>|<LI>/s;
    #RRM: ...try putting it before the list-open tag
    if ($`) { 
	$preitems = $`; $_ = $&.$';
	$preitems =~ s/<P( [^>]*)?>//gm;
	$close_tags .= "\n".$preitems if $preitems;
    }
    $_ =~ s/^\s*<\/[^>]+>\s*//s;

    # remove \n from end of the last item
    $_ =~ s/\n$//s;
    $/ = $savedRS;

    join('' , $close_tags , "\n<$tag$compact>\n" 
	 , $_ , "$etag\n</$ctag>" , $reopens);
}


# RRM:  A figure environment generates a picture UNLESS it contains a 
# {makeimage} sub-environment; in which case it creates a <DIV>
# inside which the contents are interpreted as much as is possible.
# When there are captions, this modifies $before .
sub do_env_figure {
    local($_) = @_;
    local($halign, $anchors) = ('CENTER','');
    local ($border, $attribs );
    local($cap_width) = $cap_width;
    my ($opt, $dummy) = &get_next_optional_argument;

    my $abovedisplay_space = $ABOVE_DISPLAY_SPACE||"<P></P>\n";
    my $belowdisplay_space = $BELOW_DISPLAY_SPACE||"<P></P>\n";

    ($_,$anchors) = &extract_labels($_); # extract labels
    # Try to establish the alignment
    if (/^(\[[^\]]*])?\s*\\begin\s*<<\d*>>(\w*)<<\d*>>|\\(\w*)line/) {
	$halign = $2.$3;
	if ($halign =~ /right/i)  { $halign = 'RIGHT' }
	elsif ($halign =~ /left/i) { $halign = 'LEFT' }
	elsif ($halign =~ /center/i) { $halign = 'CENTER' }
	else { $halign = 'CENTER' }
    }

    # allow caption-alignment to be variable
    local($cap_align);
    if ($FIGURE_CAPTION_ALIGN =~ /^(TOP|BOTTOM|LEFT|RIGHT)/i) {
	$cap_align = join('', ' ALIGN="', $&, $','"')};  

    local($cap_env, $captions,$has_minipage) = ('figure','');
    if ((/\\begin\s*($O\d+$C)\s*(makeimage|minipage)\s*\1|\\docode/)||
	(/\\includegraphics/&&(!/$htmlborder_rx|$htmlborder_pr_rx|\\htmlimage/))){
	$has_minipage = ($2 =~ /minipage/sg );
	$_ = &translate_environments($_);
	if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	do { local($contents) = $_;
	    &extract_captions($cap_env); $_ = $contents;
	} if (/\\caption/);
	$_ = &translate_commands($_);
	while ($_ =~ s/(^\s*<BR>\s*|\s*<BR>\s*$)//sg){}; # remove unneeded breaks
    } else {
	do { local($contents) = $_;
	    # MRO: no effect: &extract_captions($cap_env, *cap_width); $_ = $contents;
	    &extract_captions($cap_env); $_ = $contents;
	} if (/\\caption/);
	# Generate picture of the whole environment
	if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	$_ = &process_undefined_environment($env, $id, $_);
	$_ = &post_latex_do_env_figure($_);
	$_ =~ s/\s*<BR>\s*$//g;
    }

    if ($captions) {
        # MRO: replaced $* with /m
        $captions =~ s/^\n//m;
        $captions =~ s/\n$//m;
    }
    s/$caption_mark//g;

    local($close_tags) = &close_all_tags;
    $_ .= $close_tags;

    # place all the pieces inside a TABLE, if available
    if ($HTML_VERSION > 2.1) {
	if ($captions) {
	    local($pxs,$len) = &convert_length($cap_width,$MATH_SCALE_FACTOR)
		if $cap_width;
	    local($table) = "<TABLE$env_id"; # WIDTH="65%"';
	    $table .= " WIDTH=\"$pxs\"" if ($pxs);
	    if ($border) { $table .= " BORDER=\"$border\"" } # no checking !!
	    $table .= ">";
	    s/^\s*|\s*$//g;
	    join (''
		    , $above_display_space
		    , "\n<DIV", ($halign ? " ALIGN=\"$halign\"" :'')
		    , '>', $anchors , $cap_anchors
		    , "\n$table\n<CAPTION", $cap_align, '>'
		    , $captions , "</CAPTION>\n<TR><TD>"
		    , ($cap_width ? '</TD><TD>' : '')
		    , $_ , '</TD>'
		    , ($cap_width ? '<TD></TD>' : '')
		    , "</TR>\n</TABLE>\n</DIV>\n"
		    , $below_display_space
	    )
	} elsif ($halign) {
	    if ($border||($attributes)||$env_id) {
		&make_table( $border, $attribs, $anchors, '', $halign, $_ );
	    } else {
		join (''
			, $above_display_space
			, "\n<DIV ALIGN=\"$halign\">\n"
			, ($anchors ? "\n<P>$anchors</P>" : '')
			, $_
			, "\n</DIV>"
			, $below_display_space
		)
	    }
	} else {
	    if ($border||($attributes)||$env_id) {
		join (''
			, $above_display_space
			, "\n<DIV", ($halign ? " ALIGN=\"$halign\"":'')
			, '>'
			, &make_table( $border, $attribs, $anchors, '', $halign, $_ )
			, "\n</DIV><BR"
			, (($HTML_VERSION > 3.1)? " CLEAR=\"ALL\"" :'')
			, '>'
			, $below_display_space
		);
	    } else {  
		join (''
			, $above_display_space
			, "\n<DIV", ($halign ? " ALIGN=\"$halign\"":'')
			, ">$anchors\n" , $_ , "\n</DIV><BR"
			, (($HTML_VERSION > 3.1)? " CLEAR=\"ALL\"" :'')
			, '>'
			, $below_display_space
		);
	    }
	}
    } else {
	# MRO: replaced $* with /m
        s/^\n//m;
        s/\n$//m;
	if ($captions) {
	    join('', "\n<BR>\n", (($anchors) ? "$anchors" : '')
		, "$cap_anchors\n$captions\n<BR>" 
		, "\n<P", ($halign ? " ALIGN=\"$halign\"":'')
		, '>', $_ , "\n</P>");
	} elsif ($halign) {
	    join ('', "<BR>\n$anchors", $_ , "\n<BR>" )
	} else {
	    join('', "<BR>\n<P", ($halign ? " ALIGN=\"$halign\"":'')
		, ">$anchors\n" , $_ , "\n</P><BR>");
	}
    }
}

sub do_env_figurestar { &do_env_figure(@_) }

sub do_env_table {
    local($_) = @_;
    local($halign, $anchors) = ('','');
    local ( $border, $attribs );
    &get_next_optional_argument;

    # Try to establish the alignment 
    if (/^(\[[^\]]*])?\s*\\begin\s*<<\d*>>(\w*)<<\d*>>|\\(\w*)line/) {
	$halign = $2.$3;
	if ($halign =~ /right/i)  { $halign = 'RIGHT' }
	elsif ($halign =~ /left/i) { $halign = 'LEFT' }
	elsif ($halign =~ /center/i) { $halign = 'CENTER' }
	else { $halign = '' }
    }

    local($cap_env, $captions) = ('table','');

    # allow caption-alignment to be variable
    local($cap_align);
    if ($TABLE_CAPTION_ALIGN =~ /^(TOP|BOTTOM|LEFT|RIGHT)/i) {
	$cap_align = join('', ' ALIGN="', $&, $','"')};  

    if ((/\\(begin|end)\s*($O\d+$C)\s*makeimage\s*\2/)||
	    ($HTML_VERSION > 2.0 && (
	        /\\begin\s*($O\d+$C)\s*((super)?tabular|longtable)\s*\1/))) {
	$_ = &translate_environments($_);
	($_,$anchors) = &extract_labels($_); # extract labels
	do { local($contents) = $_;
	    &extract_captions($cap_env); $_ = $contents;
	} if (/\\caption/);
	if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	$_ = &translate_commands($_);
	while ($_ =~ s/(^\s*<BR>\s*|\s*<BR>\s*$)//g){};
    } else {
	# Make an image of the whole environment.
	($_,$anchors) = &extract_labels($_); # extract labels
	do { local($contents) = $_;
	    &extract_captions($cap_env); $_ = $contents;
	} if (/\\caption/);
	if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
	$_ = &process_undefined_environment($env, $id, $_);
	$_ = &post_latex_do_env_table($_);
	$_ =~ s/\s*<BR>\s*$//g;
    }

    if ($captions) {
        # MRO: replaced $* with /m
        $captions =~ s/^\n//m;
        $captions =~ s/\n$//m;
    }
    s/$caption_mark//g;

    local($close_tags) = &close_all_tags;
    $_ .= $close_tags;

    #  when $captions remain place all the pieces inside a TABLE, if available
    if ($HTML_VERSION > 2.1) {
	if ($captions) {
	    $halign = 'CENTER' unless $halign;
	    local($table) = '<TABLE';
	    if ($border) { $table .= " BORDER=\"$border\"" } # no checking !!
	    $table .= ">";
	    join ('', "<BR><P></P>\n<DIV$env_id ALIGN=\"$halign\">"
		, "$anchors$cap_anchors\n$table\n<CAPTION", $cap_align, '>'
		, $captions , "</CAPTION>\n<TR><TD>"
		, $_ , "</TD></TR>\n</TABLE>\n</DIV><P></P><BR>" )
	} elsif ($halign) {
	    if ($halign) {
		# MRO: replaced $* with /m
		s/^\s*(<(P|DIV)$env_id ALIGN=\"\w+[^>]+>)/$1$anchors/m
                    if ($anchors);
		join('', "<BR>", $_, "\n<BR>" )
	    } else {
		join ('', "<BR>\n$anchors", $_ , "\n<BR>" )
	    }
        } else {
            join ('', "<BR><P></P>\n<DIV$env_id ALIGN=\"CENTER\">$anchors\n", $_ , "\n</DIV><BR>" )
        }
    } else {
        # MRO: replaced $* with /m
        s/^\n//m;
        s/\n$//m;
        if ($captions) {
            join('', "<BR>\n", (($anchors) ? "$anchors" : ''), "$cap_anchors\n$captions\n<BR>"
                , "\n<P ALIGN=\"$halign\">", $_, "\n</P><BR>");
        } elsif ($halign) {
            join ('', "<BR><P></P>\n$anchors", $_ , "\n<P></P>" )
        } else {
            join('', "<BR>\n<P ALIGN=\"CENTER\">$anchors\n", $_, "\n</P><BR>");
        }
    }
}

sub do_env_tablestar { &do_env_table(@_) }

# RRM:  A makeimage environment generates a picture of its entire contents, 
#  UNLESS it is empty.
#
sub do_env_makeimage {
    local($_) = @_;
    local($attribs, $border);
    s/^\s*//;
    if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    if (/^((\\begin\s*(($O|$OP)\d+($C|$CP))tex2html_deferred\3)?\\par(\\end(($O|$OP)\d+($C|$CP))tex2html_deferred\7)?\%?\s*\n)+$/s) { return("\n<BR>\n") }
    if (/^(\s\%?\n)+$/s) { return() }
    $_ = &process_undefined_environment($env, $id, $_);
    if (($border||($attributes))&&($HTML_VERSION > 2.1 ))
	{ $_ = &make_table( $border, $attribs, '', '', '', $_ ) }
    $_ . ((!$_=~/^\s*$/)? "\n<BR>\n" :'');
}

sub do_env_abstract { &make_abstract($_[0]) }

sub do_env_minipage {
    local($_) = @_;
    &get_next_optional_argument;
    local($width);
    $width = &missing_braces unless (
    	(s/$next_pair_pr_rx/$width=$2;''/e)
    	||(s/$next_pair_rx/$width=$2;''/e));
    local($pxs,$len) = &convert_length($width,$MATH_SCALE_FACTOR) if $width;
    $width = " WIDTH=\"$pxs\"";
    
    local ( %mpfootnotes, $mpfootnotes ) unless ($MINIPAGE);
    local ( $border, $attribs, $footfile);
    $global{'mpfootnote'} = 0 unless ($MINIPAGE);
    $MINIPAGE++;
    print "\n *** doing minipage *** " if ($VERBOSITY > 1);
    local($open_tags_R) = [ @$open_tags_R ];
    local($close_tags,$reopens) = &close_all_tags();
    local(@save_open_tags) = @$open_tags_R;
   
    local($minipage_caption) if $cap_env;
    if ($cap_env &&($HTML_VERSION>2.1)) {
	do {
	    local($captions);
	    local($contents) = $_;
	    &extract_captions($cap_env) if ($_ =~ /\\caption/m);
	    $minipage_caption = $captions;
	    $_ = $contents;
	    undef $contents; undef $captions;
	};
    }

    if (s/^\s*$htmlborder_rx//so) {
	$attribs = $2; $border = (($4)? "$4" : 1)
    } elsif (s/^\s*$htmlborder_pr_rx//so) {
	$attribs = $2; $border = (($4)? "$4" : 1)
    }
    if (/^\s*\\/) {
	local($tmp) = ++$global{'max_id'};
	$_ = $O.$tmp.$C.$_.$O.$tmp.$C
    }
    $_ = &translate_environments($_);
    if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    $_ = &translate_commands($_);
    $MINIPAGE--; $MINIPAGE='' if ($MINIPAGE==0);

    $_ .= &balance_tags();
    $attribs .= $width unless ($attribs =~ /WIDTH/i);
#    if (($border||$attribs)&&$MINIPAGE&&($HTML_VERSION>2.1)) { 
    if (($border||$attribs||$env_id)&&$MINIPAGE&&($HTML_VERSION>2.1)) { 
	$_ = &make_table( $border, $attribs, '', '', '', $_ );
    } elsif ($MINIPAGE) { 
	$_ = join ('', '<BR><HR>', $_ , '<BR><HR><BR>' );
    } elsif (($border||($attribs)||$minipage_caption)&&($HTML_VERSION > 2.1 )) {
	$mpfootnotes = '<DL>'.$mpfootnotes.'</DL>' if $mpfootnotes;
	$_ = &make_table( $border, $attribs, '', $mpfootnotes, '', $_ );
	$_ = join('','<BR><HR'
		, (($HTML_VERSION > 3.0)? ' WIDTH="50\%" ALIGN="CENTER"' : '')
		, '>', $_ , '<BR><HR'
		, (($HTML_VERSION > 3.0)? ' WIDTH="50\%" ALIGN="CENTER"' : '')
		, '><BR>') unless ($border||$attribs||$mpfootnotes);
    } else {
	$global{'mpfootnote'} = 0;
	if ($mpfootnotes) {
	    $mpfootnotes = '<DD>'.$mpfootnotes unless ($mpfootnotes =~ /^\s*<D(T|D)>/);
	    $_ = join('','<BR><HR>', $_ , '<BR><HR'
		, (($HTML_VERSION > 3.0)? ' WIDTH="200" ALIGN="LEFT"' : '')
		, '><DL>', $mpfootnotes , '</DL><HR><BR'
		, (($HTML_VERSION > 3.0)? ' CLEAR="all"' : '')
		, '>' );
	} else {
	    $_ = join ('', '<BR><HR><P></P>', $_ , '<BR><HR><BR>' );
	}
    }
    join('', $close_tags, $_, $reopens);
}

if (($HTML_VERSION > 2.1)&&($HTML_VERSION < 4.0)) {
    $TABLE_attribs = ",ALIGN,";
    $TABLE__ALIGN = ",left,right,center,";
    $TABLE_attribs_rx_list = ",CELLPADDING,BORDER,WIDTH,CELLSPACING,";
    $TABLE__WIDTH_rx = "\^\\d+%?";
    $TABLE__BORDER_rx = $TABLE__CELLSPACING_rx = $TABLE__CELLPADDING_rx = "\^\\d+";
}

sub make_table {
    local($border, $attribs, $anchors, $extra_cell, $halign, $_) = @_;
    local($table,$caption,$div,$end,$Tattribs);
    $caption = join('',"<CAPTION$cap_align>"
	, $minipage_caption
	,'</CAPTION>') if ($minipage_caption);
    $end = "</TD></TR>\n</TABLE>";
    $table = join('', "<TABLE$env_id"
	, ((($caption)&&!($attribs =~/WIDTH/i)) ? " WIDTH=\"100\%\"" : '')
	, ((($border)&&!($attribs =~/BORDER/i)) ? " BORDER=\"$border\"" : '')
	);
    if ($attribs) {
	if (!($attribs =~ /=/)) {
	    $Tattribs = &parse_valuesonly($attribs,"TABLE");
	} else {
	    $Tattribs = &parse_keyvalues($attribs,"TABLE");
	}
	$table .= " $Tattribs" if ($Tattribs);
    }
    print STDOUT "\nTABLE: $table>" if ($VERBOSITY >2 );
    $table .= ">".$caption."\n<TR><TD>";
    if ($extra_cell) {
	local($sep) = "</TD></TR>\n<TR ALIGN=\"LEFT\">\n<TD>";
	join ('', $div, $anchors, $table, $_ , $sep, $extra_cell, $end );
    } else {
	join ('', $div, $anchors, $table, $_ , $end );
    }
}

sub do_cmd_etalchar {
    local($_) = @_;
    my $etalchar;
    $etalchar = &missing_braces unless (
	(s/$next_pair_pr_rx/$etalchar = $2;''/eo)
	||(s/$next_pair_rx/$etalchar = $2;''/eo));
    $etalchar = &translate_commands($etalchar) if ($etalchar =~ /\\/);
    if ($HTML_VERSION < 3.0) {
	$etalchar = &process_in_latex("\$^\{$etalchar\}\$");
    } else {
	$etalchar = '<SUP>'.$etalchar.'</SUP>';
    }
    $etalchar . $_
}

sub do_env_thebibliography {
    # Sets $citefile and $citations defined in translate
    local($_) = @_;
    $bibitem_counter = 0;
    $citefile = $CURRENT_FILE;
    $citefiles{$bbl_nr} = $citefile;
    local($dummy,$title);
    $dummy = &missing_braces unless (
	(s/$next_pair_pr_rx/$dummy=$2;''/e)
	||(s/$next_pair_rx/$dummy=$2;''/e));
    # MRO: replaced $* with /m
    s/^\s*$//gm; # Remove empty lines (otherwise will have paragraphs!)
    s/^\s*//m;

    # Replace non-breaking spaces, particularly in author names.
#    s/([^\\])~/$1 /g; # Replace non-breaking spaces.

    $_ = &translate_environments($_);
    $_ = &translate_commands($_);

    # RRM: collect all anchors from initial \label and \index commands
    local($anchors) = &extract_anchors('',1);
    $_ = '<DD>'.$_ unless ($_ =~ /^\s*<D(T|D)>/);
    $citations = join('',"<DL COMPACT>", $_, "</DL>");
    $citations{$bbl_nr} = $citations;
    local($br_id);
    if ((defined &do_cmd_bibname)||$new_command{'bibname'}) {
	$br_id=++$global{'max_id'};
	$title = &translate_environments("$O$br_id$C\\bibname$O$br_id$C");
    } else { $title = $bib_title }
    if (! $title ) {
	if ((defined &do_cmd_refname)||$new_command{'refname'}) {
	    $br_id=++$global{'max_id'};
	    $title = &translate_environments("$O$br_id$C\\refname$O$br_id$C");
	} else { $title = $ref_name }
    }
    local($closures,$reopens) = &preserve_open_tags();
    $toc_sec_title = $title ;
    local $bib_head = $section_headings{'bibliography'};
    $_ = join('', $closures
	    , &make_section_heading($title, $bib_head, $anchors)
	    , "$bbl_mark#$bbl_nr#" , $reopens );
    $bbl_nr++ if $bbl_cnt > 1;
    $_ =~ s/;SPMnbsp;/ /g;  # replace non-breaking spaces with real ones
    $_;
}

# IGNORE - We construct our own index
sub do_env_theindex { "" }

# This is defined in html.sty
sub do_env_comment { "" }


sub do_env_equation{
    local($_)=@_;  
    local($attribs, $border, $no_num);
    if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    if (/\\nonumber/) {
	$no_num = 1;
	$_ = &process_undefined_environment($env,$id,$_);
    } else {
	$latex_body .= join('', "\n\\setcounter{equation}{"
			, $global{'eqn_number'}, "}\n");

	#include equation-number into the key, with HTML 2.0
#	$_ = join("\n", "%EQNO:".$global{'eqn_number'}, $_)
	$_ .= "%EQNO:".$global{'eqn_number'}."\n" if ($HTML_VERSION < 2.2);

	$_ = &process_undefined_environment($env,$id,$_);
	$global{'eqn_number'}++;
	local($save) = $_;
	$_ = join('', $save, &post_latex_do_env_equation($eqno_prefix));
    }
    if (($border||($attribs))&&($HTML_VERSION > 2.1 )) { 
	join('',"<BR>\n<DIV$env_id ALIGN=\"CENTER\">\n"
	    , &make_table( $border, $attribs, '', '', '', $_ )
	    , "\n<BR CLEAR=\"ALL\">");
    } elsif ($HTML_VERSION < 2.2 ) { 
	join('', "\n<P>", $_ , "\n<BR></P>" )
    } elsif ($HTML_VERSION > 2.1 ) { 
	join('', "\n<P ALIGN="
	    , ((!$no_num &&($EQN_TAGS =~ /L/))?
		'"LEFT"':($no_num ?'"CENTER"':'"RIGHT"'))
	    , '>', $_ , "\n<BR></P>" )
    } else { $_ }
}

sub do_env_eqnarray{
    local($_)=@_;
    local($attribs, $border, $no_num);
    if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    local($contents) = $_;
#    $_ = join("\n", "%EQNO:".$global{'eqn_number'}, $_)
#	if ($HTML_VERSION < 3.2);  #include equation-number into the key.
    $_ .= "%EQNO:".$global{'eqn_number'}."\n" if ($HTML_VERSION < 2.2);
    $_ = &process_undefined_environment($env,$id,$_);
    $_ .= &post_latex_do_env_eqnarray($eqno_prefix,$contents);
    if (($border||($attribs))&&($HTML_VERSION > 2.1 )) { 
	join('',"<BR>\n<DIV ALIGN=\"CENTER\">\n"
            , &make_table( $border, $attribs, '', '', '', $_ )
	    , "\n<BR CLEAR=\"ALL\">");
    } elsif ($HTML_VERSION < 2.2 ) { 
	join('', "\n<P>", $_ , "\n<BR></P>" )
    } elsif ($HTML_VERSION > 3.1 ) { 
	join('',"<BR>\n<DIV ALIGN=\"CENTER\">\n", $_ 
	     , "\n</DIV><BR CLEAR=\"ALL\">" );
    } else {
	join('', "\n<P ALIGN="
	     , (($EQN_TAGS =~ /L/)? '"LEFT"' : '"RIGHT"')
	     , '>' , $_ , "\n<BR></P>" )
    }
}

#RRM: these are needed with later versions, when {eqnarray}
#  environments are split into <TABLE> cells.

sub protect_array_envs {
    local($_) = @_;
    local($cnt, $arraybit, $thisbit, $which) = (0,'','','');
    # MRO: replaced $* with /m
    while (/\\(begin|end)\s*(<(<|#)\d+(#|>)>)($sub_array_env_rx)(\*|star)?\2/m ) {
        $thisbit = $` . $&; $_ = $'; $which = $1;
        do {
            # mark rows/columns in nested arrays
            $thisbit =~ s/;SPMamp;/$array_col_mark/g;
            $thisbit =~ s/\\\\/$array_row_mark/g;
            $thisbit =~ s/\\text/$array_text_mark/g;
            $thisbit =~ s/\\mbox/$array_mbox_mark/g;
        } if ($cnt > 0);
        $arraybit .= $thisbit;
        if ($which =~ /begin/) {$cnt++} else {$cnt--};
    }
    $_ = $arraybit . $_;

    local($presub,$thisstack) = '';
    for (;;) {
      # find \\s needing protection within \substack commands
      # a while-loop is simpler syntax, but uses longer strings
      if ( /(\\substack\s*(<(<|#)\d+(#|>)>)(.|\n)*)\\\\((.|\n)*\2)/m ) {
        $presub .= $`; $thisstack =$1.${array_row_mark}.$6; $_ = $';
        # convert all \\s in the \substack
        $thisstack =~ s/\\\\/${array_row_mark}/og;
        $presub .= $thisstack;
        } else { last }
    }
    $_ = $presub . $_ if ($presub);
    $_;
}

sub revert_array_envs {
    local($array_contents) = @_;
    $array_contents =~ s/$array_col_mark/$html_specials{'&'}/go;
    $array_contents =~ s/$array_row_mark/\\\\/go;
    $array_contents =~ s/$array_text_mark/\\text/go;
    $array_contents =~ s/$array_mbox_mark/\\mbox/go;
    $array_contents;
}



sub do_env_tabbing {
    local($_) = @_;
    local($attribs, $border);
    if (s/$htmlborder_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    elsif (s/$htmlborder_pr_rx//o) { $attribs = $2; $border = (($4)? "$4" : 1) }
    $_ = &tabbing_helper($_);
    if (/$image_mark/) {
	local($tab_warning) = 
	   "*** Images are not strictly valid within HTML <pre> tags\n"
	   . "Please change your use of {tabbing} to a {tabular} environment.\n\n";
	   &write_warnings("\n".$tab_warning);
	   print "\n\n **** invalid tabbing environment ***\n";
	   print $tab_warning;
    }
    if (($border||($attribs))&&($HTML_VERSION > 2.1 )) { 
	join('',"<BR>\n<DIV$env_id ALIGN=\"CENTER\">\n"
            , &make_table( $border, $attribs, '', '', '', $_ )
	    , "\n</DIV><BR CLEAR=\"ALL\">");
    } else { $_ }
}

sub tabbing_helper {
    local($_) = @_;
    s/\\=\s*//go;  # cannot alter the tab-stops
    s/\t/ /g;      # convert any tabs to spaces
    # MRO: replaced $* with /m
    s/(^|\n)[^\n]*\\kill *\n/\n/gm;
    s/( )? *\n/$1/gm; # retain at most 1 space for a \n
    # replace \\ by \n ... , ignoring any trailing space
#    s/\\\\ */\n/gm;
    # ...but make sure successive \\ do not generate a <P> tag
#    s/\n( *)?\n/\n&nbsp;\n/gm;
    s/\\\&gt;//go;
    s/(^| *([^\\]))\\[>]/$2\t\t/go;
    s/([^\\])\\>/$1\t\t/go;
    s/\n$//; s/^\n//;           # strip off leading/trailing \n
    local($inside_tabbing) = 1;
    $_ = &translate_commands(&translate_environments($_));
    "<PRE><TT>\n$_\n</TT></PRE>";
}

################# Post Processing Latex Generated Images ################

# A subroutine of the form post_latex_do_env_<ENV> can be used to
# format images that have come back from latex

# Do nothing (avoid the paragraph breaks)
sub post_latex_do_env_figure { $_[0] }
sub post_latex_do_env_figurestar { &post_latex_do_env_figure(@_) }

sub post_latex_do_env_table { $_[0] }
sub post_latex_do_env_tablestar { &post_latex_do_env_table(@_) }

sub post_latex_do_env_equation {
    local($prefix) = @_;
    $global{'eqn_number'}+=1;
    # include equation number at the side of the image -- HTML 3.2
    if ($HTML_VERSION >= 3.2){
	join('',"<P ALIGN=\"" , (($EQN_TAGS eq "L") ? "left" : "right")
		, "\">$EQNO_START" , $prefix 
		, &translate_commands('\theequation')
		, "$EQNO_END</P>\n<BR CLEAR=\"all\">" );
    # </P> creates unwanted space in some browsers, but others need it.
    } else { "" }
}

sub do_cmd_theequation {
    if ($USING_STYLES) {
	$txt_style{'eqn-number'} = " " unless ($txt_style{'eqn-number'});
	join('', "<SPAN CLASS=\"eqn-number\">"
		,&get_counter_value('eqn_number'),"</SPAN>", $_[0]);
    } else { join('',&get_counter_value('eqn_number'), $_[0]); }
}

sub post_latex_do_env_eqnarray {
    local($prefix,$body) = @_;
    local($num_string,$line,@lines) = '';
    local($side) = (($EQN_TAGS eq "L") ? "\"left\"" : "\"right\"" );
    # MRO: replaced $* with /m
    @lines = split(/\\\\\\\\/m, $body);
    $line = pop(@lines);
    if (!($line=~/^\s*$/)&&!($line =~/\\nonumber/)) {
	$global{'eqn_number'}++;
	$num_string .= join('', "<BR><BR>\n" , $EQNO_START , $prefix
	    , &translate_commands('\theequation')
	    , $EQNO_END);
    }
    foreach $line (@lines) {
	next if ($line=~/^\s*$/);
	$num_string .= "\n<BR>". (($MATH_SCALE_FACTOR > 1.3)? '<BR>' : '')
	                . "<BR CLEAR=$side>";
	if (!($line =~/\\(nonumber|(no)?tag)/)) {
	    $global{'eqn_number'}+=1;
	    $num_string .= join('', $EQNO_START , $prefix
		, &translate_commands('\theequation')
		, $EQNO_END);
	 }
    }
    # include equation numbers at the side of the image -- HTML 3.2
    if ($HTML_VERSION >= 3.2){
	"<P ALIGN=\"" . (($EQN_TAGS eq "L") ? "left" : "right")
	    . "\">" . (($DISP_SCALE_FACTOR >= 1.2 ) ? '<BIG>' : '')
	    . ${num_string}
	    . (($DISP_SCALE_FACTOR >= 1.2 ) ? '</BIG>' : '')
	    . "</P>\n<BR CLEAR=\"all\">"
    # </P> creates unwanted space in some browsers, but others need it.
    } else { "" };
}

sub post_latex_do_env_eqnarraystar {
    local($_) = @_;
    if (($HTML_VERSION >= 3.2)&&(!$NO_SIMPLE_MATH)){
	join('', "<BR>\n<DIV ALIGN=\"CENTER\">\n"
	    , $_ , "\n<BR CLEAR=\"ALL\">\n<P>");
    } elsif (($HTML_VERSION >= 2.2)&&(!$NO_SIMPLE_MATH)) {
	join('', "\n<BR><P ALIGN=\"CENTER\">\n", $_ , "\n<BR></P>\n<P>");
    } else {
	join('', "\n<BR><P>\n", $_ , "\n<BR></P>\n<P>");
    }
}

############################ Grouping ###################################

sub do_cmd_begingroup { $latex_body .= "\n\\begingroup\n"; $_[0] }
sub do_cmd_endgroup { $latex_body .= "\\endgroup\n\n"; $_[0] }
sub do_cmd_bgroup { $latex_body .= "\n\\bgroup\n"; $_[0] }
sub do_cmd_egroup { $latex_body .= "\\egroup\n\n"; $_[0] }

sub do_env_tex2html_begingroup {
    local($_) = @_;
    $latex_body .= "\\begingroup ";
    $_ = &translate_environments($_);
    $_ = &translate_commands($_);
    $latex_body .= "\\endgroup\n";
    $_;
}

sub do_env_tex2html_bgroup {
    local($_) = @_;
    $latex_body .= "\\bgroup ";
    $_ = &translate_environments($_);
    $_ = &translate_commands($_);
    $latex_body .= "\\egroup\n";
    $_;
}


############################ Commands ###################################

# Capitalizes what follows the \sc declaration
# *** POTENTIAL ERROR ****
# (This is NOT the correct meaning of \sc in the cases when it
# is followed by another declaration (e.g. \em).
# The scope of \sc should be limited to the next occurence of a
# declaration.
#sub do_cmd_sc {
#    local($_) = @_;
#    local(@words) = split(" ");
# Capitalize the words which are not commands and do not contain any markers
#   grep (do {tr/a-z/A-Z/ unless /(^\\)|(tex2html)/}, @words);
#    grep (do {s/([a-z]+)/<small>\U$1\E<\/small>/g unless /(^\\)|(tex2html)/}, @words);
#    join(" ", @words);
#}
sub do_cmd_sc { &process_smallcaps(@_) }
sub do_cmd_scshape { &do_cmd_sc(@_) }

# This is supposed to put the font back into roman.
# Since there is no HTML equivalent for reverting
# to roman we keep track of the open font tags in
# the current context and close them.
# *** POTENTIAL ERROR ****#
# This will produce incorrect results in the exceptional
# case where \rm is followed by another context
# containing font tags of the type we are trying to close
# e.g. {a \bf b \rm c {\bf d} e} will produce
#       a <b> b </b> c   <b> d   e</b>
# i.e. it should move closing tags from the end
sub do_cmd_rm { # clean
    my ($str, $ot) = @_;
    $ot = $open_tags_R unless(defined $ot);
    return("<\#rm\#>".$str) if ($inside_tabular);

    my ($size,$color,$tags);
    while (@$ot) {
	my $next = pop (@$ot);
	print STDOUT "\n</$next>" if $VERBOSITY > 2;
	if ($next =~ /$sizechange_rx/) {
	    $size = $next unless ($size);
	}
#	if ($next =~ /$colorchange_rx/) {
#	    $color = $next unless ($color);
#	}
	$declarations{$next} =~ m|</.*$|;
	$tags .= $& unless ($` =~ /^<>/);
    }
    if ($size) {
	$declarations{$size} =~ m|</.*$|;
	$tags .= $` unless ($` =~ /^<>/);
	push (@$ot,$size);
	print STDOUT "\n<$size>" if $VERBOSITY > 2;
    }
    $tags.$str;
}

sub do_cmd_rmfamily{ &do_cmd_rm(@_) }

sub do_cmd_textrm { 
    local($_) = @_;
    local($text,$br_id)=('','0');
    $text = &missing_braces unless (
	(s/$next_pair_pr_rx/$text=$2;$br_id=$1;''/eo)
	||(s/$next_pair_rx/$text=$2;$br_id=$1;''/eo));
    join ('' ,
	  &translate_environments("$O$br_id$C\\rm $text$O$br_id$C")
	  , $_ );
}

sub do_cmd_emph { 
    local($_) = @_;
    local($ifstyle,$join_tags) = ('',join(',',@$open_tags_R));
    $join_tags =~ s/(^|,)(text)?(it|rm|normalfont)/$if_style=$3;''/eg; 
    if ($if_style =~ /it/) {
	($ifstyle,$join_tags) = ('',join(',',@$open_tags_R));
	$join_tags =~ s/(^|,)(text)?(bf|rm|normalfont)/$if_style=$3;''/eg; 
	if ($if_style =~ /bf/) { &do_cmd_textrm(@_) }
	else { &do_cmd_textbf(@_) }
    } else { &do_cmd_textit(@_) }
}

#RRM: These cope with declared commands for which one cannot
#     simply open a HTML single tag.
#     The do_cmd_... gets found before the $declaration .

sub do_cmd_upshape{&declared_env('upshape',$_[0],$tex2html_deferred)}
sub do_cmd_mdseries{&declared_env('mdseries',$_[0],$tex2html_deferred)}
sub do_cmd_normalfont{&declared_env('normalfont',$_[0],$tex2html_deferred)}


# This is supposed to put the font back into normalsize.
# Since there is no HTML equivalent for reverting
# to normalsize we keep track of the open size tags in
# the current context and close them.
sub do_cmd_normalsize { # clean
    my ($str, $ot) = @_;
    $ot = $open_tags_R unless(defined $ot);

    my ($font,$fontwt,$closures,$reopens,@tags);

    while (@$ot) {
	my $next = pop @$ot;
	$declarations{$next} =~ m|</.*$|;
	my ($pre,$post) = ($`,$&);
	if ($post =~ /$block_close_rx|$all_close_rx/ ) {
	    push (@$ot, $next);
	    last;
	}
	$closures .= $post unless ($pre =~ /^<>/);
	print STDOUT "\n</$next>" if $VERBOSITY > 2;

	if ($next =~ /$fontchange_rx/) {
	    $font = $next unless ($font);
	} elsif ($next =~ /$fontweight_rx/) {
	    $fontwt = $next unless ($fontwt);
	} elsif ($next =~ /$sizechange_rx/) {
	    # discard it
	} else {
	    unshift (@tags, $next);
	    print STDOUT "\n<<$next>" if $VERBOSITY > 2;
	    $reopens .= $pre unless ($pre =~ /^<>/);
	}
    }
    push (@$ot, @tags);
    if ($font) {
	$declarations{$font} =~ m|</.*$|;
	$reopens .= $` unless ($` =~ /^<>/);
	push (@$ot,$font);
	print STDOUT "\n<$font>" if $VERBOSITY > 2;
    }
    if ($fontwt) {
	$declarations{$fontwt} =~ m|</.*$|;
	$reopens .= $` unless ($` =~ /^<>/);
	push (@$ot,$fontwt);
	print STDOUT "\n<$fontwt>" if $VERBOSITY > 2;
    }
    join('', $closures, $reopens, $str);
}



#JCL(jcl-tcl)
# changed everything
#
sub do_cmd_title {
    local($_) = @_;
    &get_next_optional_argument;
    local($making_title,$next) = (1,'');
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $2;''/eo)
	||(s/$next_pair_rx/$next = $2;''/eo));
    $t_title = &translate_environments($next);
    $t_title = &translate_commands($t_title);
#    $toc_sec_title = &simplify(&translate_commands($next));
    $toc_sec_title = &purify(&translate_commands($next));
    $TITLE = (($toc_sec_title)? $toc_sec_title : $default_title)
	unless ($TITLE && !($TITLE =~ /^($default_title|\Q$FILE\E)$/));
#    $TITLE = &purify($TITLE);

    #RRM: remove superscripts inserted due to \thanks
    $TITLE =~ s/<A[^>]*><SUP>\d+<\/SUP><\/A>/$1/g;
    $_;
}

sub do_cmd_author {
    local($_) = @_;
    &get_next_optional_argument;
    my $next;
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $2;''/seo)
	||(s/$next_pair_rx/$next = $2;''/seo));
    local($after) = $_;
    if ($next =~ /\\and/) {
	my @author_list = split(/\s*\\and\s*/, $next);
	my $t_author, $t_affil, $t_address;
	foreach (@author_list) {
	    $t_author = &translate_environments($_);
	    $t_author =~ s/\s+/ /g;
	    $t_author = &simplify(&translate_commands($t_author));
	    ($t_author,$t_affil,$t_address) = split (/\s*<BR>s*/, $t_author);
	    push @authors, $t_author;
	    push @affils, $t_affil;
	    push @addresses, $t_address;
	}
    } else {
	$_ = &translate_environments($next);
	$next = &translate_commands($_);
	($t_author) = &simplify($next);
	($t_author,$t_affil,$t_address) = split (/\s*<BR>s*/, $t_author);
	push @authors, $t_author;
	push @affils, $t_affil if $t_affil;
	push @addresses, $t_address if $t_address;
    }
    $after;
}

sub do_cmd_address {
    local($_) = @_;
    &get_next_optional_argument;
    local($next);
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $&;''/eo)
	||(s/$next_pair_rx/$next = $&;''/eo));
    ($t_address) = &simplify(&translate_commands($next));
    push @addresses, $t_address;
    $_;
}

sub do_cmd_institute {
    local($_) = @_;
    &get_next_optional_argument;
    local($next);
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $&;''/eo)
	||(s/$next_pair_rx/$next = $&;''/eo));
    ($t_institute) = &simplify(&translate_commands($next));
    push @affils, $t_institute;
    $_;
}

sub do_cmd_dedicatory {
    local($_) = @_;
    &get_next_optional_argument;
    local($next);
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $&;''/eo)
	||(s/$next_pair_rx/$next = $&;''/eo));
    ($t_affil) = &simplify(&translate_commands($next));
    push @affils, $t_affil;
    $_;
}

sub do_cmd_email {
    local($_) = @_;
    local($next,$target)=('','notarget');
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $2;''/eo)
	||(s/$next_pair_rx/$next = $2;''/eo));
    local($mail) = &translate_commands($next);
    ($t_email) = &make_href("mailto:$mail","$mail");
    push @emails, $t_email;
    $_;
}

sub do_cmd_authorURL {
    local($_) = @_;
    local($next);
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $2;''/eo)
	||(s/$next_pair_rx/$next = $2;''/eo));
    ($t_authorURL) =  &translate_commands($next);
    push @authorURLs, $t_authorURL;
    $_;
}

sub do_cmd_date {
    local($_) = @_;
    local($next);
    $next = &missing_braces unless (
	(s/$next_pair_pr_rx/$next = $&;''/eo)
	||(s/$next_pair_rx/$next = $&;''/eo));
    ($t_date) = &translate_commands($next);
    $_;
}

sub make_multipleauthors_title {
    local($alignc, $alignl) = (@_);
    local($t_author,$t_affil,$t_institute,$t_date,$t_address,$t_email,$t_authorURL)
	= ('','','','','','','');
    local ($t_title,$auth_cnt) = ('',0);
    if ($MULTIPLE_AUTHOR_TABLE) {
	$t_title = '<TABLE' .($USING_STYLES? ' CLASS="author_info_table"' : '')
		.' WIDTH="90%" ALIGN="CENTER" CELLSPACING=15>'
		."\n<TR VALIGN=\"top\">";
    }
    foreach $t_author (@authors) {
	$t_affil = shift @affils;
	$t_institute = ''; # shift @institutes;
	$t_address = shift @addresses;
	$t_email = shift @emails;
	$t_authorURL = shift @authorURLs;
	if ($MULTIPLE_AUTHOR_TABLE) {
	    if ($auth_cnt == $MAX_AUTHOR_COLS) {
		$t_title .= join("\n", '</TR><TR>', '');
		$auth_cnt -= $MAX_AUTHOR_COLS;
	    }
	    $t_title .= join("\n"
		, '<TD>'
		, &make_singleauthor_title($alignc, $alignl ,$t_author
		    , $t_affil,$t_institute,$t_date,$t_address,$t_email,$t_authorURL)
		, '</TD>' );
	    ++$auth_cnt;
	} else {
	    $t_title .= &make_singleauthor_title($alignc, $alignl ,$t_author
		, $t_affil,$t_institute,$t_date,$t_address,$t_email,$t_authorURL);
	}
    }
    if ($MULTIPLE_AUTHOR_TABLE) {
	$t_title .= "\n</TR></TABLE>\n";
    }
    $t_title;
}

sub do_cmd_maketitle {
    local($_) = @_;
    local($the_title) = '';
    local($alignc, $alignl);
    if ($HTML_VERSION > 2.1) {
	$alignc = " ALIGN=\"CENTER\""; 
	$alignl = " ALIGN=\"LEFT\""; 
	$alignl = $alignc if ($MULTIPLE_AUTHOR_TABLE);
    }
    if ($t_title) {
	$the_title .= "<H1$alignc>$t_title</H1>";
    } else { &write_warnings("\nThis document has no title."); }
    if (($#authors >= 1)||$MULTIPLE_AUTHOR_TABLE) {
	$the_title .= &make_multipleauthors_title($alignc,$alignl);
	if ($t_date&&!($t_date=~/^\s*(($O|$OP)\d+($C|$CP))\s*\1\s*$/)) {
	    $the_title .= "\n<P$alignc><STRONG>$t_date</STRONG></P>";}
    } else {
	$the_title .= &make_singleauthor_title($alignc,$alignl ,$t_author
	    , $t_affil,$t_institute,$t_date,$t_address,$t_email,$t_authorURL);
    }
    $the_title . $_ ;
}

sub make_singleauthor_title {
    local($alignc, $alignl , $t_author
	, $t_affil,$t_institute,$t_date,$t_address,$t_email,$t_authorURL) = (@_);
    my $t_title = '';
    my ($s_author_info, $e_author_info) = ('<DIV','</DIV>');
    $s_author_info .= ($USING_STYLES ? ' CLASS="author_info"' : '').'>';

    if ($t_author) {
	if ($t_authorURL) {
	    local($href) = &translate_commands($t_authorURL);
	    $href = &make_named_href('author'
			, $href, "<STRONG>${t_author}</STRONG>");
	    $t_title .= "\n<P$alignc>$href</P>";
	} else {
	    $t_title .= "\n<P$alignc><STRONG>$t_author</STRONG></P>";
	}
    } else { &write_warnings("\nThere is no author for this document."); }

    if ($t_institute&&!($t_institute=~/^\s*(($O|$OP)\d+($C|$CP))\s*\1\s*$/)) {
	$t_title .= "\n<P$alignc><SMALL>$t_institute</SMALL></P>";}
    if ($t_affil&&!($t_affil=~/^\s*(($O|$OP)\d+($C|$CP))\s*\1\s*$/)) {
	$t_title .= "\n<P$alignc><I>$t_affil</I></P>";}
    if ($t_date&&!($t_date=~/^\s*(($O|$OP)\d+($C|$CP))\s*\1\s*$/)) {
	$t_title .= "\n<P$alignc><STRONG>$t_date</STRONG></P>";}
    if ($t_address&&!($t_address=~/^\s*(($O|$OP)\d+($C|$CP))\s*\1\s*$/)) {
	$t_title .= "\n<P$alignl><SMALL>$t_address</SMALL></P>";
    }  # else { $t_title .= "\n<P$alignl>"}
    if ($t_email&&!($t_email=~/^\s*(($O|$OP)\d+($C|$CP))\s*\1\s*$/)) {
	$t_title .= "\n<P$alignl><SMALL>$t_email</SMALL></P>";
    }  # else { $t_title .= "</P>" }
    join("\n", $s_author_info, $t_title, $e_author_info);
}

sub do_cmd_abstract {
    local($_) = @_;
    local($abstract);
    $abstract = &missing_braces unless (
	(s/$next_pair_pr_rx/$abstract = $&;''/eo)
	||(s/$next_pair_rx/$abstract = $&;''/eo));
    join('', &make_abstract($abstract), $_);
}

sub make_abstract {
    local($_) = @_;
    # HWS  Removed emphasis (hard to read)	   
    $_ = &translate_environments($_);
    $_ = &translate_commands($_);
    local($title);
    if ((defined &do_cmd_abstractname)||$new_command{'abstractname'}) {
	local($br_id)=++$global{'max_id'};
	$title = &translate_environments("$O$br_id$C\\abstractname$O$br_id$C");
    } else { $title = $abs_title }
    local($env_id) = " CLASS=\"ABSTRACT\"" if ($USING_STYLES);
    join('',"\n<H3>", $title, ":</H3>\n"
	, (($HTML_VERSION > 3)? "<DIV$env_id>" : "<P>"), $_ 
	, (($HTML_VERSION > 3)? "</DIV>" : "</P>"), "\n<P>");
}

sub set_default_language {
    # MRO: local($lang,*_) = @_;
    my $lang = shift;
    push(@language_stack, $default_language);
    $default_language = $lang;
    $_[0] .= '\popHtmlLanguage';
}

sub do_cmd_popHtmlLanguage {
    $default_language = pop(@language_stack);
    $_[0];
}

sub do_cmd_today {
    local($lang);
    if ($PREAMBLE) {
	$lang = $TITLES_LANGUAGE || $default_language ;
    } else {
	$lang = $current_language || $default_language ;
    }
    local($today) = $lang . '_today';
    if (defined &$today) { join('', eval "&$today()", $_[0]) }
    else { join('', &default_today(), $_[0]) }
}

sub default_today {
    #JKR: Make it more similar to LaTeX
    ## AYS: moved french-case to styles/french.perl
    my $today = &get_date();

    $today =~ s|(\d+)/0?(\d+)/|$Month[$1] $2, |;
    join('',$today,$_[0]);
}

sub do_cmd_textbackslash { join('','&#92;', $_[0]);}
sub do_cmd_textbar { join('','|', $_[0]);}
sub do_cmd_textless { join('',';SPMlt;', $_[0]);}
sub do_cmd_textgreater { join('',';SPMgt;', $_[0]);}
sub do_cmd_textasciicircum { join('','&#94;', $_[0]);}
sub do_cmd_textasciitilde { join('','&#126;', $_[0]);}
sub do_cmd_textquoteleft { join('','&#96;', $_[0]);}
sub do_cmd_textquoteright { join('','&#39;', $_[0]);}

sub do_cmd_textcompwordmark { join('','', $_[0]);}
sub do_cmd_texttrademark { join('','<SUP><SMALL>TM</SMALL></SUP>', $_[0]);}

sub do_cmd_textsubscript   { &make_text_supsubscript('SUB',$_[0]);} 
sub do_cmd_textsuperscript { &make_text_supsubscript('SUP',$_[0]);}

sub make_text_supsubscript { 
    local ($supsub, $_) = (@_);
    my $arg = '';
    $arg = &missing_braces unless (
	(s/$next_pair_pr_rx/$arg = $&;''/eo)
	||(s/$next_pair_rx/$arg = $&;''/eo));
    $arg = &translate_commands($arg) if ($arg =~ m!\\!);
    join('', "<$supsub>", $arg, "</$supsub>", $_);
}

sub do_cmd_textcircled { 
    local ($_) = (@_);
    my $arg = '';
    $arg = &missing_braces unless (
	(s/$next_pair_pr_rx/$arg = $&;''/eo)
	||(s/$next_pair_rx/$arg = $&;''/eo));
    my $after = $_;
    join('', &process_undefined_environment("tex2html_nomath_inline"
	   , ++$global{'max_id'}
	   , "\\vbox{\\kern3pt\\textcircled{$arg}}" )
	, $after );
}

# these can be overridded in charset (.pl) extension files:
sub do_cmd_textemdash { join('','---', $_[0]);}
sub do_cmd_textendash { join('','--', $_[0]);}
#sub do_cmd_exclamdown { join('','', $_[0]);}
#sub do_cmd_questiondown { join('','', $_[0]);}
sub do_cmd_textquotedblleft { join('',"``", $_[0]);}
sub do_cmd_textquotedblright { join('',"''", $_[0]);}
sub do_cmd_textbullet { join('','*', $_[0]);}
sub do_cmd_textvisiblespace { join('','_', $_[0]);}

sub do_cmd_ldots {
    join('',(($math_mode&&$USE_ENTITY_NAMES) ? ";SPMldots;" : "..."),$_[0]);
}

sub do_cmd_dots {
    join('',(($math_mode&&$USE_ENTITY_NAMES) ? ";SPMldots;" : "..."),$_[0]);
}

sub do_cmd_hrule {
    local($_) = @_;
    &ignore_numeric_argument;
    #JKR: No need for <BR>
    local($pre,$post) = &minimize_open_tags('<HR>');
    join('',$pre,$_);
}

#sub do_cmd_hrulefill {
#    "<HR ALIGN=\"right\">\n<BR CLEAR=\"right\">";
#}

sub do_cmd_linebreak {
    local($num,$dum) = &get_next_optional_argument;
    if (($num)&&($num<4)) { return $_[0] }
    join('',"<BR>", $_[0]);
}

sub do_cmd_pagebreak {
    local($_) = @_;
    local($num,$dum) = &get_next_optional_argument;
    if (($num)&&($num<4)) { return($_) }
    elsif (/^ *\n *\n/) {
	local($after) = $';
	local($pre,$post) = &minimize_open_tags("<BR>\n<P>");
	join('',$pre, $')
    } else { $_ }
}


sub do_cmd_newline { join('',"<BR>", $_[0]); }
# this allows for forced newlines in tables, etc.
sub do_cmd_endgraf { join('',"<BR>", $_[0]); }

sub do_cmd_space { join(''," ",$_[0]); }
sub do_cmd_enspace { join('',"\&nbsp;",$_[0]); }
sub do_cmd_quad { join('',"\&nbsp;"x4,$_[0]); }
sub do_cmd_qquad { join('',"\&nbsp;"x8,$_[0]); }

sub do_cmd_par {
    local ($_) = @_;
    my ($pre,$post) = &preserve_open_tags();
    my ($spar, $lcode) = ("\n<P", '');
    if (($USING_STYLES) &&(!($default_language eq $TITLES_LANGUAGE))) {
	$lcode = &get_current_language();
	$spar .= $lcode if $lcode;
    }
    join('', $pre, $spar, ">\n",$post,$_);
}

sub do_cmd_medskip {
    local ($_) = @_;
    local($pre,$post) = &preserve_open_tags();
    join('',$pre,"\n<P><BR>\n",$post,$_);
}

sub do_cmd_smallskip {
    local ($_) = @_;
    local($pre,$post) = &preserve_open_tags();
    join('',$pre,"\n<P></P>\n",$post,$_);
}

sub do_cmd_bigskip {
    local ($_) = @_;
    local($pre,$post) = &preserve_open_tags();
    join('',$pre,"\n<P><P><BR>\n",$post,$_);
}

# MEH: Where does the slash command come from?
# sub do_cmd_slash {
#    join('',"/",$_[0]);
#}
sub do_cmd_esc_slash { $_[0]; }
sub do_cmd_esc_hash { "\#". $_[0]; }
sub do_cmd_esc_dollar { "\$". $_[0]; }
sub do_cmd__at_ { $_[0]; }
sub do_cmd_lbrace { "\{". $_[0]; }
sub do_cmd_rbrace { "\}". $_[0]; }
sub do_cmd_Vert { "||". $_[0]; }
sub do_cmd_backslash { "\\". $_[0]; }

#RRM: for subscripts outside math-mode
# e.g. in Chemical formulae
sub do_cmd__sub {
    local($_) = @_;
    local($next);
    $next = &missing_braces unless (
        (s/$next_pair_pr_rx/$next = $2;''/e)
        ||(s/$next_pair_rx/$next = $2;''/e));
    join('',"<SUB>",$next,"</SUB>",$_);   
}

#JCL(jcl-del) - the next two ones must only have local effect.
# Yet, we don't have a mechanism to revert such changes after
# a group has closed.
#
sub do_cmd_makeatletter {
    $letters =~ s/@//;
    $letters .= '@';
    &make_letter_sensitive_rx;
    $_[0];
}

sub do_cmd_makeatother {
    $letters =~ s/@//;
    &make_letter_sensitive_rx;
    $_[0];
}


################## Commands to be processed by Latex #################
#
# The following commands are passed to Latex for processing.
# They cannot be processed at the same time as normal commands
# because their arguments must be left untouched by the translator.
# (Normally the arguments of a command are translated before the
# command itself).
#
# In fact, it's worse:  it is not correct to process these
# commands after we process environments, because some of them
# (for instance, \parbox) may contain unknown or wrapped
# environments.  If math mode occurs in a parbox, the
# translate_environments routine should *not* process it, lest
# we encounter the lossage outlined above.
#
# On the other hand, it is not correct to process these commands
# *before* we process environments, or figures containing
# parboxes, etc., will be mishandled.
#
# RRM: (added for V97.1) 
#  \parbox now uses the  _wrap_deferred  mechanism, and has a  do_cmd_parbox
#  subroutine defined. This means that environments where parboxes are
#  common (.g. within table cells), can detect the \parbox command and
#  adjust the processing accordingly.
#
# So, the only way to handle these commands is to wrap them up
# in null environments, as for math mode, and let translate_environments
# (which can handle nesting) figure out which is the outermost.
#
# Incidentally, we might as well make these things easier to configure...

sub process_commands_in_tex {
    local($_) = @_;
    local($arg,$tmp);
    foreach (/.*\n?/g) {
	chop;
	# For each line
	local($cmd, @args) = split('#',$_);
	next unless $cmd;
	$cmd =~ s/ //g;

	# skip if a proper implementation already exists
	$tmp = "do_cmd_$cmd";
	next if (defined &$tmp);

	# Build routine body ...
	local ($body, $code, $thisone) = ("", "");

	# alter the pattern here to debug particular commands
#	$thisone = 1 if ($cmd =~ /mathbb/);

	print "\n$cmd: ".scalar(@args)." arguments" if ($thisone);
	foreach $arg (@args) {
	    print "\nARG: $arg" if ($thisone);
	    print "\nARG: $next_pair_rx" if ($thisone);
	    if ($arg =~ /\{\}/) {
# RRM: the $` is surely wrong, allowing no error-checking.
# Use <<...>> for specific patterns
#		$body .= '$args .= "$`$&" if s/$next_pair_rx//o;'."\n"; 
		$body .= '$args .= join("","{", &missing_braces, "}") unless ('."\n";
		$body .= '  (s/$next_pair_pr_rx/$args.=$`.$&;""/es)'."\n";
		$body .= '  ||(s/$next_pair_rx/$args.=$`.$&;""/es));'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
		$body .= $' if ($');
	    } elsif ($arg =~ /\[\]/) {
		$body .= '($dummy, $pat) = &get_next_optional_argument;'
		    . '$args .= $pat;'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
		$body .= $' if ($');
	    } elsif ($arg =~ /^\s*\\/) {		    
		$body .= '($dummy, $pat) = &get_next_tex_cmd;'
		    . '$args .= $pat;'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
		$body .= $' if ($');
	    } elsif ($arg =~ /<<\s*/) {
		$arg = $';
		if ($arg =~ /\s*>>/) {
                    # MRO: replaced $* with /m
		    $body .= '$args .= "$`$&" if (/\\'.$`.'/m);' . "\n"
#		    $body .= '$args .= "$`$&" if (/\\\\'.$`.'/);' . "\n"
			. "\$_ = \$\';\n";
		    print "\nAFTER:$'" if (($thisone)&&($'));
		    $body .= $' if ($');
		} else { $body .= $arg ; }
	    } else {
	        print "\nAFTER:$'" if (($thisone)&&($arg));
		$body .= $arg ;
	    }
	}

	# Generate a new subroutine
	local($padding) = " ";
	$padding = '' if (($cmd =~ /\W$/)||(!$args)||($args =~ /^\W/));
	$code = "sub wrap_cmd_$cmd {" . "\n"
	    . 'local($cmd, $_) = @_; local ($args, $dummy, $pat) = "";' . "\n"
	    . $body
	    . (($thisone)? "print STDERR \"\\n$cmd:\".\$args.\"\\n\";\n" : '')
	    . '(&make_wrapper(1).$cmd'
	    . ($padding ? '"'.$padding.'"' : '')
	    . '.$args.&make_wrapper(0), $_)}'
	    . "\n";
	print "\nWRAP_CMD: $code " if ($thisone); # for debugging
	eval $code; # unless ($thisone);
	print STDERR "\n*** sub wrap_cmd_$cmd  failed: $@" if ($@);

	# And make sure the main loop will catch it ...
#	$raw_arg_cmds{$cmd} = 1;
	++$raw_arg_cmds{$cmd};
    }
}

sub process_commands_nowrap_in_tex {
    local($_) = @_;
    local($arg);
    foreach (/.*\n?/g) {
	chop;
	local($cmd, @args) = split('#',$_);
	next unless $cmd;
	$cmd =~ s/ //g;
	# Build routine body ...
	local ($bodyA, $codeA, $bodyB, $codeB, $thisone) = ("", "", "", "");

	# alter the pattern here to debug particular commands
#	$thisone = 1 if ($cmd =~ /epsf/);

	print "\n$cmd: ".scalar(@args)." arguments" if ($thisone);
	foreach $arg (@args) {
	    print "\nARG: $arg" if ($thisone);
	    if ($arg =~ /\{\}/) {
#		$bodyA .= '$args .= "$`"."$&" if (s/$any_next_pair_rx//);'."\n";
		$bodyA .= 'if (s/$next_pair_rx//s){$args.="$`"."$&"; $_='."\$'};\n";
		$bodyB .= '$args .= &missing_braces'."\n unless (";
		$bodyB .= '(s/$any_next_pair_pr_rx/$args.=$`.$&;\'\'/eo)'."\n";
		$bodyB .= '  ||(s/$any_next_pair_rx/$args.=$`.$&;\'\'/eo));'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
#		$bodyA .= $'.";\n" if ($');
		$bodyB .= $'.";\n" if ($');
	    } elsif ($arg =~ /\[\]/) {
		$bodyA .= '($dummy, $pat) = &get_next_optional_argument;'
		    . '$args .= $pat;'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
#		$bodyA .= $'.";\n" if ($');
		$bodyB .= $'.";\n" if ($');
	    } elsif ($arg =~ /^\s*\\/) {		    
		$bodyA .= '($dummy, $pat) = &get_next_tex_cmd;'
		    . '$args .= $pat;'."\n";
		$bodyB .= '($dummy, $pat) = &get_next_tex_cmd;'
		    . '$args .= $pat;'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
		$bodyA .= $'.";\n" if ($');
		$bodyB .= $'.";\n" if ($');
	    } elsif ($arg =~ /<<\s*/) {
		$arg = $';
		if ($arg =~ /\s*>>/) {
                    # MRO: replaced $* with /m
		    $bodyA .= '$args .= "$`$&" if (/\\'.$`.'/m);' . "\n"
#		    $bodyA .= '$args .= $`.$& if (/\\\\'.$`.'/);' . "\n"
			. "\$_ = \$\';\n";
		    $bodyB .= '$args .= "$`$&" if (/\\'.$`.'/m);' . "\n"
			. "\$_ = \$\';\n";
		    print "\nAFTER:$'" if (($thisone)&&($'));
#		    $bodyA .= $'.";\n" if ($');
		    $bodyB .= $'.";\n" if ($');
		} else { 
		    print "\nAFTER:$arg" if (($thisone)&&($arg));
#		    $bodyA .= $arg.";\n" if ($arg);
		    $bodyB .= $arg.";\n" if ($arg);
		}
	    } else { 
		print "\nAFTER:$arg" if (($thisone)&&($arg));
		$bodyA .= '$args .= '.$arg.";\n" if ($');
		$bodyB .= $arg.";\n" if ($'); 
	    }
	}
	local($padding) = " ";
	$padding = '' if (($cmd =~ /\W$/)||(!$args)||($args =~ /^\W/));
	# Generate 2 new subroutines
	$codeA = "sub wrap_cmd_$cmd {" . "\n"
	    .'local($cmd, $_) = @_; local($args, $dummy, $pat) = "";'."\n"
	    . $bodyA
	    . (($thisone)? "print \"\\nwrap $cmd:\\n\".\$args.\"\\n\";\n" : '')
	    . '(&make_nowrapper(1)."\n".$cmd.'."\"$padding\""
	    . '.$args.&make_nowrapper(0)," ".$_)}'
	    ."\n";
	print "\nWRAP_CMD: $codeA " if ($thisone); # for debugging
	eval $codeA;
	print STDERR "\n\n*** sub wrap_cmd_$cmd  failed: $@\n" if ($@);
	$codeB = "do_cmd_$cmd";
	do {
	    $bodyB = '"";' if !($bodyB);
	    $codeB = "sub do_cmd_$cmd {" . "\n"
		. 'local($_,$ot) = @_;'."\n"
		. 'local($open_tags_R) = defined $ot ? $ot : $open_tags_R;'."\n"
		. 'local($cmd,$args,$dummy,$pat)=("'.$cmd.'","","","");'."\n"
		. $bodyB
		. (($thisone)? "print \"\\ndo $cmd:\".\$args.\"\\n\";\n" : '')
#		. '$latex_body.="\\n".&revert_to_raw_tex("'."\\\\$cmd$padding".'$args")."\\n\\n";'
		. "\$_;}\n";
	    print STDOUT "\nDO_CMD: $codeB " if ($thisone); # for debugging
	    eval $codeB;
	    print STDERR "\n\n*** sub do_cmd_$cmd  failed: $@\n" if ($@);
	} unless (defined &$codeB );

	# And make sure the main loop will catch it ...
#	$raw_arg_cmds{$cmd} = 1;
	++$raw_arg_cmds{$cmd};
    }
}

sub process_commands_wrap_deferred {
    local($_) = @_;
    local($arg,$thisone);
    foreach (/.*\n?/g) {
	chop;
	local($cmd, @args) = split('#',$_);
	next unless $cmd;
	$cmd =~ s/ //g;
	# Build routine body ...
	local ($bodyA, $codeA, $bodyB, $codeB, $after, $thisone);

	# alter the pattern here to debug particular commands
#	$thisone = 1 if ($cmd =~ /selectlanguage/);

	print "\n$cmd: ".scalar(@args)." arguments" if ($thisone);
	foreach $arg (@args) {
	    print "\nARG: $arg" if ($thisone);
	    if ($arg =~ /\{\}/) {
#		$bodyA .= '$args .= "$`$&" if (s/$any_next_pair_rx//o);';
		$bodyA .= '$args .= "$`$&" if (s/$next_pair_rx//so);';
		$after = $';
		print "\nAFTER:$'" if (($thisone)&&($'));
	    } elsif ($arg =~ /\[\]/) {
		$bodyA .= '($dummy, $pat) = &get_next_optional_argument;' .
		    "\n". '$args .= $pat;';
		$after = $';
		print "\nAFTER:$'" if (($thisone)&&($'));
	    } elsif ($arg =~ /^\s*\\/) {		    
		$bodyA .= '($dummy, $pat) = &get_next_tex_cmd;'
		    . '$args .= $pat;'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
		$bodyA .= $'.";\n" if ($');
	    } elsif (/<<\s*([^>]*)[\b\s]*>>/) {
		local($endcmd, $afterthis) = ($1,$');
		$afterthis =~ s/(^\s*|\s*$)//g;
		$endcmd =~ s/\\/\\\\/g;
		$bodyA .= "\n". 'if (/'.$endcmd.'/) { $args .= $`.$& ; $_ = $\' };';
		$after .= $afterthis if ($afterthis);
		print "\nAFTER:$'" if (($thisone)&&($'));
	    } else { 
		print "\nAFTER:$arg" if (($thisone)&&($arg));
                $bodyB .= $arg.";\n" ; $after = ''
            }
	    $after =~ s/(^\s*|\s*$)//g if ($after);
	    $bodyB .= $after . ";" if ($after);
	    $bodyA .= "\$args .= ".$after . ";" if ($after);
	}
	local($padding) = " ";
	$padding = '' if (($cmd =~ /\W$/)||(!$args)||($args =~ /^\W/));
	# Generate 2 new subroutines
	$codeA = "sub wrap_cmd_$cmd {" . "\n"
	    .'local($cmd, $_) = @_; local ($args, $dummy, $pat) = "";'."\n"
	    . $bodyA #. ($bodyA ? "\n" : '')
	    . (($thisone)? ";print \"\\nwrap $cmd:\".\$args.\"\\n\";\n" : '')
	    .'(&make_deferred_wrapper(1).$cmd.'.$padding
		.'$args.&make_deferred_wrapper(0),$_)}'
	    ."\n";
	print STDERR "\nWRAP_CMD: $codeA " if ($thisone); # for debugging
	eval $codeA;
	print STDERR "\n\n*** sub wrap_cmd_$cmd  failed: $@\n" if ($@);

	#RRM: currently these commands only go to LaTeX or access counters.
	#   They could be implemented more generally, as below with  do_dcmd_$cmd
	#   requiring replacement to be performed before evaluation.
	$codeB = "sub do_dcmd_$cmd {" . "\n"
	    .'local($cmd, $_) = @_; local ($args, $dummy, $pat) = "";'."\n"
	    . $bodyA . "\n" 
            . (($thisone)? ";print \"\\ndo_def $cmd:\".\$args.\"\\n\";\n" : '')
            . $bodyB . "}" . "\n";
	print "\nDEF_CMD: $codeB " if ($thisone); # for debugging
	local($tmp) = "do_cmd_$cmd";
	eval $codeB unless (defined &$tmp);
	print STDERR "\n\n*** sub do_dcmd_$cmd  failed: $@\n" if ($@);

	# And make sure the main loop will catch it ...
#	$raw_arg_cmds{$cmd} = 1;
	++$raw_arg_cmds{$cmd};
    }
}

sub process_commands_inline_in_tex {
    local($_) = @_;
    foreach (/.*\n?/g) {
	chop;
	local($cmd, @args) = split('#',$_);
	next unless $cmd;
	$cmd =~ s/ //g;
	# Build routine body ...
	local ($body, $code, $thisone) = ("", "");

	# uncomment and alter the pattern here to debug particular commands
#	$thisone = 1 if ($cmd =~ /L/);

	print "\n$cmd: ".scalar(@args)." arguments" if ($thisone);
	foreach (@args) {
	    print "\nARG: $_" if ($thisone);
	    if (/\{\}/) {
#		$body .= '$args .= $`.$& if (/$any_next_pair_rx/);' . "\n"
#		    . "\$_ = \$\';\n";
		$body .= '$args .= $`.$& if (s/$next_pair_rx//s);' . "\n"
	    } elsif (/\[\]/) {
		$body .= 'local($dummy, $pat) = &get_next_optional_argument;' .
		    "\n". '$args .= $pat;';
	    } elsif ($arg =~ /^\s*\\/) {		    
		$body .= '($dummy, $pat) = &get_next_tex_cmd;'
		    . '$args .= $pat;'."\n";
		print "\nAFTER:$'" if (($thisone)&&($'));
		$body .= $'.";\n" if ($');
	    } elsif (/<<\s*/) {
		$_ = $';
		if (/\s*>>/) {
                    # MRO: replaced $* with /m
		    $body .= '$args .= "$`$&" if (/\\'.$`.'/m);' . "\n"
			. "\$_ = \$\';\n"
		} else { $body .= $_.";\n" ; }
	    } else { $body .= $_.";\n" ; }
	}
	local($padding) = " ";
	$padding = '' if (($cmd =~ /\W$/)||(!$args)||($args =~ /^\W/));
	# Generate a new subroutine
	my $itype = ($cmd =~ /^f.*box$/ ? 'inline' : 'nomath');
	$code = "sub wrap_cmd_$cmd {" . "\n"
	    .'local($cmd, $_) = @_; local ($args) = "";' . "\n"
	    . $body . "\n"
            . (($thisone)? ";print \"\\ndo $cmd:\".\$args.\"\\n\";\n" : '')
	    .'(&make_'.$itype.'_wrapper(1).$cmd.$padding.$args.'
	    . '&make_'.$itype.'_wrapper(0),$_)}'
	    ."\n";
	print "\nWRAP_CMD:$raw_arg_cmds{$cmd}: $code "
		if ($thisone); # for debugging
	eval $code;
	print STDERR "\n\n*** sub wrap_cmd_$cmd  failed: $@\n" if ($@);
	# And make sure the main loop will catch it ...
#	$raw_arg_cmds{$cmd} = 1;
	++$raw_arg_cmds{$cmd};
    }
}


# Invoked before actual translation; wraps these commands in
# tex2html_wrap environments, so that they are properly passed to
# TeX in &translate_environments ...
# JCL(jcl-del) - new usage of $raw_arg_cmd_rx
sub wrap_raw_arg_cmds {
    local ($processed_text, $cmd, $wrapper, $wrap, $after);
    print "\nwrapping raw arg commands " if ($VERBOSITY>1);
    local($seg, $par_wrap, $teststar, @processed);
#   local(@segments) = split(/\\par\b/,$_);
#   foreach (@segments) {
#      $par_wrap = join('',&make_deferred_wrapper(1), "\\par"
#			, &make_deferred_wrapper(0));
#     push(@processed, $par_wrap ) if ($seg); ++$seg;
    if (%renew_command) {
	local($key);
	foreach $key (keys %renew_command) {
	    $raw_arg_cmds{$key} = 1;
	    $raw_arg_cmd_rx =~ s/^(\(\)\\\\\()/$1$key\|/;
	}
    }
    print "\n" if (/$raw_arg_cmd_rx/);

    # MRO: replaced $* with /m
    while (/$raw_arg_cmd_rx/m) {
	local($star);
	push (@processed, $`); print "\@";
	$after = $';
	#JCL(jcl-del) - status of starred raw arg cmds yet unclear
	($cmd, $star) = ($1.$2,$4);
	if ($star eq '*') { $star = 'star';}
	else { $after = $star.$after; $star = ''; }
	$wrapper = "wrap_cmd_$cmd"; $teststar = $wrapper.'star';
	if ($star && defined &$teststar) { $wrapper = $teststar; $star = '*'; }
        # MRO: make {\bf**} work
	elsif($star) { $after = '*'.$after; $star = '' }
	print "\nWRAPPED: $cmd as $wrapper" if ($VERBOSITY > 5);

	# ensure that the result is separated from following words...
	my $padding = ($after =~ /^[a-zA-Z]/s)? ($cmd =~ /\W$/ ? '':' '):'';

	if ($raw_arg_cmds{$cmd} && defined &$wrapper) {
            #$* = 1;
	    ($wrap, $_) = &$wrapper("\\$cmd$star", $padding . $after);
            #$* = 0;
	    # ...but don't leave an unwanted space at the beginning
	    $_ =~ s/^ //s if($padding && $wrap !~ /\w$/m
	    	&& (length($_) == length($after)+1) );
	    push (@processed, $wrap);
	} elsif ($raw_arg_cmds{$cmd}) {
	    print STDERR "\n*** $wrapper not defined, cannot wrap \\$cmd";
	    &write_warnings("\n*** $wrapper not defined, cannot wrap \\$cmd ");
	    push (@processed, "\\$cmd$padding");
	    $_ = $after;
	} else {
	    push (@processed, "\\$cmd$padding");
	    $_ = $after;
	}
        last unless ($after =~ /\\/);
    }

    # recombine the pieces
    $_ = join('',@processed, $_);
}

#########################################################################

# To make a table of contents, list of figures and list of tables commands
# create a link to corresponding files which do not yet exist.
# The binding of the file variable in each case acts as a flag
# for creating the actual file at the end, after all the information
# has been gathered.

sub do_cmd_tableofcontents { &do_real_tableofcontents(@_) }
sub do_real_tableofcontents {
#    local($_) = @_;
    if ((defined &do_cmd_contentsname)||$new_command{'contentsname'}) {
	local($br_id)=++$global{'max_id'};
	$TITLE = &translate_environments("$O$br_id$C\\contentsname$O$br_id$C");
    } else { $TITLE = $toc_title }
    $toc_sec_title = $TITLE;
    $tocfile = $CURRENT_FILE;  # sets  $tocfile  this globally
    local $toc_head = $section_headings{'tableofcontents'};
    if ($toc_style) {
	$toc_head .= " CLASS=\"$toc_style\"";
	$env_style{"$toc_head.$toc_style"} = " "
	    unless ($env_style{"$toc_head.$toc_style"});
    }
    local($closures,$reopens) = &preserve_open_tags();
    join('', "<BR>\n", $closures
	, &make_section_heading($TITLE, $toc_head), $toc_mark
	, $reopens, @_[0]);
}
sub do_cmd_listoffigures {
    local($_) = @_;
    local($list_type) = ($SHOW_SECTION_NUMBERS ? 'UL' : 'OL' );
    if ((defined &do_cmd_listfigurename)||$new_command{'listfigurename'}) {
	local($br_id)=++$global{'max_id'};
	$TITLE = &translate_environments("$O$br_id$C\\listfigurename$O$br_id$C");
    } else { $TITLE = $lof_title }
    $toc_sec_title = $TITLE;
    $loffile = $CURRENT_FILE;  # sets  $loffile  this globally
    local $lof_head = $section_headings{'listoffigures'};
    local($closures,$reopens) = &preserve_open_tags();
    join('', "<BR>\n", $closures
	 , &make_section_heading($TITLE, $lof_head)
	 , "<$list_type>", $lof_mark, "</$list_type>"
	 , $reopens, $_);
}
sub do_cmd_listoftables {
    local($_) = @_;
    local($list_type) = ($SHOW_SECTION_NUMBERS ? 'UL' : 'OL' );
    if ((defined &do_cmd_listtablename)||$new_command{'listtablename'}) {
	local($br_id)=++$global{'max_id'};
	$TITLE = &translate_environments("$O$br_id$C\\listtablename$O$br_id$C");
    } else { $TITLE = $lot_title }
    $toc_sec_title = $TITLE;
    $lotfile = $CURRENT_FILE;  # sets  $lotfile  this globally
    local $lot_head = $section_headings{'listoftables'};
    local($closures,$reopens) = &preserve_open_tags();
    join('', "<BR>\n", $closures
	 , &make_section_heading($TITLE, $lot_head)
	 , "<$list_type>", $lot_mark, "</$list_type>"
	 , $reopens, $_);
}

# Indicator for where to put the CHILD_LINKS table.
sub do_cmd_tableofchildlinks {
    local($_) = @_;
    local($thismark) = $childlinks_mark;
    local($option,$dum) = &get_next_optional_argument;
    $thismark = &check_childlinks_option($option) if ($option);
    local($pre,$post) = &minimize_open_tags("$thismark\#0\#");
    join('', "<BR>", $pre, $_);
}

# leave out the preceding <BR>
sub do_cmd_tableofchildlinksstar {
    local($_) = @_;
    local($thismark) = $childlinks_mark;
    local($option,$dum) = &get_next_optional_argument;
    $thismark = &check_childlinks_option($option) if ($option);
    local($pre,$post) = &minimize_open_tags("$thismark\#1\#");
    join('', $pre, $_);
}

sub check_childlinks_option {
    local($option) = @_;
    if ($option =~ /none/i) {
	$childlinks_mark = $childlinks_null_mark;
	$childlinks_null_mark }
    elsif ($option =~ /off/i) { $childlinks_null_mark }
    elsif ($option =~ /all/i) {
	$childlinks_mark = $childlinks_on_mark;
	$childlinks_on_mark }
    elsif ($option =~ /on/i) { $childlinks_on_mark }
}

sub remove_child_marks {
    # Modifies $_
    s/($childlinks_on_mark|$childlinks_null_mark)\#\d\#//go;
}


sub do_cmd_htmlinfo {
    local($_) = @_;
    local($option,$dum) = &get_next_optional_argument;
    if ($option =~ /^(off|none)/i) { $INFO = 0; return ($_) }
    local($pre,$post) = &minimize_open_tags($info_title_mark.$info_page_mark);
    join('', "<BR>", $pre, $_);
}
sub do_cmd_htmlinfostar {
    local($_) = @_;
    local($option,$dum) = &get_next_optional_argument;
    if ($option =~ /^(off|none)/i) { $INFO = 0; return ($_) }
    local($pre,$post) = &minimize_open_tags($info_page_mark);
    join('', $pre, $_);
}

# $idx_mark will be replaced with the real index at the end
sub do_cmd_textohtmlindex {
    local($_) = @_;
    if ((defined &do_cmd_indexname )||$new_command{'indexname'}) {
	local($br_id)=++$global{'max_id'};
	$TITLE = &translate_environments("$O$br_id$C\\indexname$O$br_id$C");
    } else { $TITLE = $idx_title }
    $toc_sec_title = $TITLE;
    $idxfile = $CURRENT_FILE;
    if (%index_labels) { &make_index_labels(); }
    if (($SHORT_INDEX) && (%index_segment)) { &make_preindex(); }
    else { $preindex = ''; }
    local $idx_head = $section_headings{'textohtmlindex'};
    local($heading) = join(''
	, &make_section_heading($TITLE, $idx_head)
	, $idx_mark );
    local($pre,$post) = &minimize_open_tags($heading);
    join('',"<BR>\n" , $pre, $_);
}

#RRM: added 17 May 1996
# allows labels within the printable key of index-entries,
# when using  makeidx.perl
sub make_index_labels {
    local($key, @keys);
    @keys = keys %index_labels;
    foreach $key (@keys) {
	if (($ref_files{$key}) && !($ref_files{$key} eq "$idxfile")) {
	    local($tmp) = $ref_files{$key};
	    &write_warnings("\nmultiple label $key , target in $idxfile masks $tmp ");
	}
	$ref_files{$key} .= "$idxfile";
    }
}
#RRM: added 17 May 1996
# constructs a legend for the SHORT_INDEX, with segments
# when using  makeidx.perl
sub make_preindex { &make_real_preindex }
sub make_real_preindex {
    local($key, @keys, $head, $body);
    $head = "<HR>\n<H4>Legend:</H4>\n<DL COMPACT>";
    @keys = keys %index_segment;
    foreach $key (@keys) {
	local($tmp) = "segment$key";
	$tmp = $ref_files{$tmp};
	$body .= "\n<DT>$key<DD>".&make_named_href('',$tmp,$index_segment{$key});
#	$body .= "\n<DT>$key<DD>".&make_named_href('',
#		$tmp."\#CHILD\_LINKS",$index_segment{$key})
#	             unless ($CHILD_STAR);
    }
    $preindex = join('', $head, $body, "\n</DL>") if ($body);
}

sub do_cmd_printindex { &do_real_printindex(@_); }
sub do_real_printindex {
    local($_) = @_;
    local($which) = &get_next_optional_argument;
    $idx_name = $index_names{$which}
	if ($which && $index_names{$which});
    @_;
}

sub do_cmd_newindex {
    local($_) = @_;
    local($dum,$key,$title);
    $key = &missing_braces unless (
	(s/$next_pair_pr_rx/$key=$2;''/eo)
	||(s/$next_pair_rx/$key=$2;''/eo));
    $dum = &missing_braces unless (
	(s/$next_pair_pr_rx/$dum=$2;''/eo)
	||(s/$next_pair_rx/$dum=$2;''/eo));
    $dum = &missing_braces unless (
	(s/$next_pair_pr_rx/$dum=$2;''/eo)
	||(s/$next_pair_rx/$dum=$2;''/eo));
    $title = &missing_braces unless (
	(s/$next_pair_pr_rx/$title=$2;''/eo)
	||(s/$next_pair_rx/$title=$2;''/eo));
    $index_names{$key} = $title if ($key && $title);
    @_;
}

# FOOTNOTES , also within Mini-page environments
# allow easy way to override and inherit; e.g. for frames 

sub do_cmd_footnotestar { &do_real_cmd_footnote(@_) }
sub do_cmd_footnote { &do_real_cmd_footnote(@_) }
sub do_real_cmd_footnote {
    local($_) = @_;
    local($cnt,$marker,$smark,$emark)=('', $footnote_mark);
    local($mark,$dum) = &get_next_optional_argument;
    local($anchor_name);

    $footfile = "${PREFIX}$FOOT_FILENAME$EXTN"
	unless ($footfile||$MINIPAGE||$NO_FOOTNODE);

    if ($mark) { 
	$cnt = $mark;
	if ($MINIPAGE) { $global{'mpfootnote'} = $cnt }
	else { $global{'footnote'} = $cnt }
    } else {
	$cnt = (($MINIPAGE)? ++$global{'mpfootnote'} : ++$global{'footnote'});
    }
    local($br_id, $footnote)=(++$global{'max_id'},'');
    $footnote = &missing_braces unless (
        (s/$next_pair_pr_rx/${br_id}=$1; $footnote=$2;''/eo)
	||(s/$next_pair_rx/${br_id}=$1; $footnote=$2;''/eo));
    $br_id = "mp".$br_id if ($MINIPAGE);
    $marker = &get_footnote_mark($MINIPAGE);
    local($last_word) = &get_last_word();
    local($href) = &make_href("$footfile#foot$br_id",$marker);
    if ($href =~ /NAME="([^"]*)"/) { $anchor_name=$1 }
    $last_word .= $marker unless ($anchor_name);
    &process_footnote($footnote,$cnt,$br_id,$last_word,$mark
	      ,($MINIPAGE? $marker : '')
	      ,($MINIPAGE? '' : "$marker:$anchor_name") );
    # this may not work if there is a <BASE> tag and !($file) !!! #
#   join('',&make_href("$file#foot$br_id",$marker),$_);
    $href . $_ 
}

sub process_image_footnote {
    # MRO: modified to use $_[0]
    # local(*math) = @_;
    local($in_image, $keep, $pre, $this_anchor, $out, $foot_counters_recorded, @foot_anchors) = (1,'','');
    local($image_contents) = $_[0];
    $image_contents =~ s/\\(begin|end)(($O|$OP)\d+($C|$CP))tex2html_\w+\2//go;
    $image_contents =~ s!(\\footnote(mark\b\s*(\[[^\]]*\])?|\s*(\[[^\]]*\])?\s*(($O|$OP)\d+($C|$CP))(.*)\5))!
	$keep = $`; $out = '\footnotemark '.$3.$4;
        #MRO: $*=1; local($saveRS) = $/; $/='';
	if ($8) {
	    $this_anchor = &do_cmd_footnote($2);
	} else {
	    $this_anchor = &do_cmd_footnotemark($3);
	}
        #MRO: $*=0; $/ = $saveRS;
	$foot_counters_recorded = 1;
	push(@foot_anchors, $this_anchor);
	$out!oesg;
    $_[0] = $image_contents;
    @foot_anchors;
}

sub do_cmd_thanks { &do_cmd_footnote(@_); }

sub get_footnote_mark {
    local($mini) = @_;
    return($footnote_mark) if ($HTML_VERSION < 3.0 );
    local($cmd,$tmp,@tmp,$marker);
    $cmd = "the". (($mini)? 'mp' : '') . "footnote";
    if ($new_command{$cmd}) {
	$tmp = "do_cmd_$cmd";
	@tmp = split (':!:', $new_command{$cmd});
	pop @tmp; $tmp = pop @tmp;
	if ($tmp =~ /$O/) {
###	    local($_) = &translate_commands($tmp);
	    $marker = &translate_commands(&translate_environments($tmp));
	    &make_unique($marker);
###	    $marker = $_;
	} else { $marker = &translate_commands(&translate_environments($tmp)); }
    } elsif ($mini) {
    	$marker = &translate_commands('\thempfootnote');
    } elsif ((defined &do_cmd_thefootnote)||$new_command{'thefootnote'}) { 
	local($br_id)=++$global{'max_id'};
	$marker = &translate_environments("$O$br_id$C\\thefootnote$O$br_id$C");
    } else { $marker = $footnote_mark; }
    join('','<SUP>',$marker,'</SUP>');
}

sub make_numbered_footnotes {
    eval "sub do_cmd_thefootnote {\&numbered_footnotes}" }
sub numbered_footnotes { &do_cmd_arabic('<<0>>footnote<<0>>');}

# default numbering style for minipage notes
sub do_cmd_thempfootnote { &do_cmd_arabic('<<0>>mpfootnote<<0>>'); }

sub do_cmd_footnotemark { &do_real_cmd_footnotemark(@_) }
sub do_real_cmd_footnotemark {
    local($_) = @_;
    local($br_id, $footnote,$marker,$mpnote,$tmp,$smark,$emark);
    # Don't use ()'s for the optional argument!
    local($mark,$dum) = &get_next_optional_argument;
    local ($cnt,$text_known) = ('','');
    if ($mark) {
	$cnt = (($mark =~ /\\/)? &translate_commands($mark) : $mark);
	if (($MINIPAGE)&&($mpfootnotes{$cnt})) {
	    $mpnote = 1;
	    $br_id  = $mpfootnotes{$cnt};
	    $text_known = 1;
	} else {
	    $global{'footnote'} = $cnt;
	    local($tmp) = $footnotes{$cnt};
	    if ($tmp) {
		$br_id  = $tmp;
		$text_known = 1;
	    } else { $footnotes{$cnt} = $br_id }
	}
    } else {
	$cnt = ++$global{'footnote'};
	$text_known = 1 if ($footnotes{$cnt});
    }
    if ($text_known) {
	$br_id = ($MINIPAGE ? $mpfootnotes{$cnt} : $footnotes{$cnt});
	$marker = &get_footnote_mark($mpnote);
	return (join('', &make_href("$footfile#foot$br_id",$marker),$_));
    }
    
    local($last_word) = &get_last_word() unless ($mpnote);

    # Try to find a  \footnotetext  further on.
    do {
	if (s/\\footnotetext\s*\[\s*$cnt\s*]*\]\s*$any_next_pair_pr_rx//o) {
	    ($br_id, $footnote) = ($2, $3);  
	} else { 
	    $br_id = "fnm$cnt";
	    $footnotes{$cnt} = $br_id;
	}
    } unless ($br_id);

    $marker = &get_footnote_mark($mpnote);
    $last_word .= $marker unless ($marker =~ /$footnote_mark/ );
    if ($footnote) {
	# found a  \footnotetext  further on
	&process_footnote($footnote,$cnt,$br_id,$last_word,$mark);
	join('',&make_named_href("foot$br_id","$footfile#$br_id",$marker),$_);
    } elsif ($br_id =~ /fnm/) {
	# no  \footnotetext  yet, so make the entry in $footnotes
	&process_footnote('',$cnt,$br_id,$last_word,$mark);
	# this may not work if there is a <BASE> tag and !($footfile) !!! #
	join('',&make_named_href("foot$br_id","$footfile#$br_id",$marker),$_);
    } elsif ($br_id) {
	# \footnotetext  already processed
	if ($mpnote) {
	    $mpfootnotes =~ s/(=\"$br_id\">...)(<\/A>)/$1$last_word$3/
		if ($last_word);
	    # this may not work if there is a <BASE> tag !!! #
	    join('',&make_named_href("foot$br_id","#$br_id",$marker),$_);
	} else {
	    $footnotes =~ s/(=\"$br_id\">...)(<\/A>)/$1$last_word$3/;
	    # this may not work if there is a <BASE> tag and !($footfile) !!! #
	    join(''
		,&make_named_href("foot$br_id","$footfile#$br_id",$marker),$_);
	}
    } else { 
	print "\nCannot find \\footnotetext for \\footnotemark $cnt";
	# this may not work if there is a <BASE> tag and !($footfile) !!! #
	join('',&make_named_href("foot$br_id","$footfile",$marker),$_);
    }
}

# Under normal circumstances this is never executed. Any commands \footnotetext
# should have been processed when the corresponding \footnotemark was
# encountered. It is possible however that when processing pieces of text
# out of context (e.g. \footnotemarks in figure and table captions)
# the pair of commands gets separated. Until this is fixed properly,
# this command just puts the footnote in the footnote file in the hope
# that its context will be obvious ....
sub do_cmd_footnotetext {
    local($_) = @_;
    local($mark,$dum) = &get_next_optional_argument;
    local($br_id, $footnote, $prev, $key)=(1,'','','');
    $footnote = &missing_braces unless (
	(s/$next_pair_pr_rx/($br_id,$footnote)=($1,$2);''/eo)
	||(s/$next_pair_rx/($br_id,$footnote)=($1,$2);''/eo));

    $mark = $global{'footnote'} unless $mark;
    $prev = $footnotes{$mark};
    if ($prev) {
	$prev = ($MINIPAGE ? 'mp' : '') . $prev;
	# first prepare the footnote-text
	$footnote = &translate_environments("${OP}$br_id$CP$footnote${OP}$br_id$CP")
            if ($footnote);
	$footnote = &translate_commands($footnote) if ($footnote =~ /\\/);

	# now merge it onto the Footnotes page
	$footnotes =~ s/(=\"$prev\">\.\.\.)(.*<\/A>)(<\/DT>\n<DD>)\n/
		$1.'<html_this_mark>'.$3.$footnote/e;
	local($this_mark) = $2;
	$this_mark =~ s|(<SUP>)(?:<#\d+#>)?(\d+)(?:<#\d+#>)?(<\/SUP>)(<\/A>)$|
		"$4<A\n HREF=\"$CURRENT_FILE\#foot$prev\">$1$2$3$4"|e;
	$footnotes =~ s/<html_this_mark>/$this_mark/;
    } else {
	&process_footnote($footnote,$mark,$br_id,'','') if $footnote;
    }
    $_;
}


sub process_footnote {
    # Uses $before
    # Sets $footfile defined in translate
    # Modifies $footnotes defined in translate
    local($footnote, $cnt, $br_id, $last_word, $mark, $mini, $same_page) = @_;
    local($target) = $target;

    # first prepare the footnote-text
    local($br_idd, $fcnt); $br_id =~ /\D*(\d+)/; $br_idd = $1;
    $footnote = &translate_environments("$O$br_idd$C$footnote$O$br_idd$C")
	if ($footnote);
    $footnote = &translate_commands($footnote) if ($footnote =~ /\\/);

    local($space,$sfoot_style,$efoot_style) = ("\n",'','');
    if ((!$NO_FOOTNODE)&&(!$mini)&&(!$target)) {
	$footfile = "${PREFIX}$FOOT_FILENAME$EXTN";
	$space = ".\n" x 30;
	$space = "\n<PRE>$space</PRE>";
    } elsif ($target) {
	$target = $frame_body_name
	    if (($frame_body_name)&&($target eq $frame_foot_name));
	$sfoot_style = '<SMALL>';
	$efoot_style = '</SMALL>';
    }

    if ($mark) {
	if ($mini) {
	    $cnt = $mpfootnotes{$mark};
	    if ($in_image) {
		$fcnt = $global{'mpfootnote'}; --$fcnt if $fcnt;
		$latex_body .= '\setcounter{mpfootnote}{'.($fcnt||"0")."}\n"
		    unless ($foot_counters_recorded);
	    }
	} else {
	    $cnt = $footnotes{$mark};
	    if ($in_image) {
		$fcnt = $global{'footnote'}; --$fcnt if $fcnt;
		$latex_body .= '\setcounter{footnote}{'.($fcnt||"0")."}\n"
		    unless ($foot_counters_recorded);
	    }
	}
	if ($cnt) { 
	    &write_warnings("\nredefined target for footnote $mark" )
		unless ( $cnt eq $br_id )
	}
	if ($mini) { $mpfootnotes{$mark} = "$br_id" }
	elsif ($br_id =~ /fnm\d+/) {
	    $mark = "$footnotes{$cnt}";
	    $footnotes{$cnt} = "$br_id";
#	    $footnotes .= "\n<DT>$sfoot_style<A NAME=\"foot$br_id\">..."
	    $footnotes .= "\n<DT>$sfoot_style<A NAME=\"$br_id\">..."
		. $last_word . "</A>$efoot_style</DT>\n<DD>\n"
		. $space . "\n</DD>";
	    return;
	} else { $footnotes{$mark} = "$br_id" }
    } else {
	if ($mini) {
	    $mpfootnotes{$cnt} = "$br_id";
	    if ($in_image) {
		$fcnt = $global{'mpfootnote'}; --$fcnt if $fcnt;
		$latex_body .= '\setcounter{mpfootnote}{'.($fcnt||"0")."}\n"
		    unless ($foot_counters_recorded);
	    }
	} else {
	    $footnotes{$cnt} = "$br_id";
	    if ($in_image) {
		$fcnt = $global{'footnote'}; --$fcnt if $fcnt;
		$latex_body .= '\setcounter{footnote}{'.($fcnt||"0")."}\n"
		    unless ($foot_counters_recorded);
	    }
	}
    }

    # catch a \footnotemark *after* the \footnotetext
    if ((!$footnote)&&($last_word)&&(!$mini)) {
#	$footnotes .= "\n<DT>$sfoot_style<A NAME=\"foot$br_id\">..."
	$footnotes .= "\n<DT>$sfoot_style<A NAME=\"$br_id\">..."
	    . $last_word
	    . "</A>$efoot_style</DT>\n<DD>\n" . $space . "\n</DD>";

    } elsif ($mini) {
	if ($HTML_VERSION < 3.0) { $mini .= "." }
	$mpfootnotes .= "\n<DD>$sfoot_style<A NAME=\"foot$br_id\">$mini</A> " .
	    $footnote . $efoot_style . "\n</DD>\n";
    } elsif ($same_page) {
	local($link,$text);
	$same_page =~ s/:/$text=$`;$link=$';''/e;
	$same_page = &make_named_href("","$CURRENT_FILE\#$link",$text) if($link);
	$footnotes .= "\n<DT>$sfoot_style<A NAME=\"foot$br_id\">...$last_word</A>"
	    . $same_page . $efoot_style . "</DT>\n<DD>" . $sfoot_style
	    . $footnote . $efoot_style . "\n". $space . "\n</DD>";
    } else {
	$footnotes .= "\n<DT>$sfoot_style<A NAME=\"foot$br_id\">...$last_word</A>"
		. $efoot_style . "</DT>\n<DD>" . $sfoot_style
		. $footnote . "$efoot_style\n" . $space . "\n</DD>";
    }
}


sub do_cmd_appendix {
    $latex_body .= "\\appendix\n";
    if ($section_commands{$outermost_level} == 3) {
	$global{'section'} = 0;
	&reset_dependents('section');
	eval "sub do_cmd_thesection{ &do_cmd_the_appendix(3,\@_) }";
    } else {
	$global{'chapter'} = 0;
	&reset_dependents('chapter');
	eval "sub do_cmd_thechapter{ &do_cmd_the_appendix(2,\@_) }";
    }
    $_[0];
}

sub do_cmd_the_appendix {
    local($val,$level) = (0,$_[0]);
    if ($level == 3) { $val=$global{'section'} }
    elsif ($level == 2) { $val=$global{'chapter'} }
    join('', &fAlph($val), '.', $_[1]);
}

sub do_cmd_appendixname { $app_title . $_[0] }
sub do_cmd_abstractname { $abs_title . $_[0] }
sub do_cmd_keywordsname { $key_title . $_[0] }
sub do_cmd_subjclassname { $sbj_title . $_[0] }
sub do_cmd_indexname { $idx_title . $_[0] }
sub do_cmd_contentsname { $toc_title . $_[0] }
sub do_cmd_datename { $date_name . $_[0] }
sub do_cmd_refname { $ref_title . $_[0] }
sub do_cmd_bibname { $bib_title . $_[0] }
sub do_cmd_figurename { $fig_name . $_[0] }
sub do_cmd_listfigurename { $lof_title . $_[0] }
sub do_cmd_tablename { $tab_name . $_[0] }
sub do_cmd_listtablename { $lot_title . $_[0] }
sub do_cmd_partname { $part_name . $_[0] }
sub do_cmd_chaptername { $chapter_name . $_[0] }
sub do_cmd_sectionname { $section_name . $_[0] }
sub do_cmd_subsectionname { $subsection_name . $_[0] }
sub do_cmd_subsubsectionname { $subsubsection_name . $_[0] }
sub do_cmd_paragraphname { $paragraph_name . $_[0] }
sub do_cmd_thmname { $thm_title . $_[0] }
sub do_cmd_proofname { $prf_name . $_[0] }
sub do_cmd_footnotename { $foot_title . $_[0] }
sub do_cmd_childlinksname { '<STRONG>'.$child_name.'</STRONG>'. $_[0] }
sub do_cmd_infopagename { $info_title . $_[0] }


sub do_cmd_ref {
    local($_) = @_;
    &process_ref($cross_ref_mark,$cross_ref_mark);
}

sub do_cmd_eqref {
    local($_) = @_;
    join('','(',&process_ref($cross_ref_mark,$cross_ref_mark,'',')'));
}

sub do_cmd_pageref {
    local($_) = @_;
    &process_ref($cross_ref_mark,$cross_ref_visible_mark);
}

# This is used by external style files ...
sub process_ref {
    local($ref_mark, $visible_mark, $use_label, $after_label) = @_;
    $use_label = &balance_inner_tags($use_label) 
	if $use_label =~ (/<\/([A-Z]+)>($math_verbatim_rx.*)<\1>/);
    $use_label = &translate_environments($use_label);
    $use_label = &simplify(&translate_commands($use_label))
	if ($use_label =~ /\\/ );
    local($label,$id);
    local($pretag) = &get_next_optional_argument;
    $pretag = &translate_commands($pretag) if ($pretag =~ /\\/);    
    $label = &missing_braces unless (
	(s/$next_pair_pr_rx/($id, $label) = ($1, $2);''/eo)
	||(s/$next_pair_rx/($id, $label) = ($1, $2);''/eo));
    if ($label) {
	$label =~ s/<[^>]*>//go ; #RRM: Remove any HTML tags
	$label =~ s/$label_rx/_/g;	# replace non alphanumeric characters

	$symbolic_labels{"$pretag$label$id"} = $use_label if ($use_label);
	if (($symbolic_labels{$pretag.$label})&&!($use_label)) {
	    $use_label = $symbolic_labels{$pretag.$label}
	}
#	if (!($use_label eq $label)) {
#	    $symbolic_labels{"$label$id"} = $use_label;
#	};
     	# if $use_label is empty then $label is used as the cross_ref_mark
	# elseif $use_label is a string then $use_label is used
        # else the usual mark will be used
	$use_label = ( (!$use_label && $label) || $use_label);

	print "\nLINK: $ref_mark\#$label\#$id  :$use_label:" if ($VERBOSITY > 3);
	# The quotes around the HREF are inserted later
	join('',"<A HREF=$ref_mark#$label#$id>$visible_mark<\/A>",$after_label, $_);
    }
    else {
	print "Cannot find label argument after <$last_word>\n" if $last_word;
	$after_label . $_;
    }
}

#RRM:  This removes unbalanced tags, due to closures for math inside 
#      the label-text for an <A> anchor.
sub balance_inner_tags {
    local($text) = @_;
    return($text) unless ($text =~ /<\/([A-Z]+)>(\s*$math_verbatim_rx.*)(<\1( [^>]*)?>)/);
    local($beforeT,$afterT,$tag,$math_verb,$stag) = ($`,$',$1,$2,$3);
    if (!($beforeT =~ /<$tag>/)) { 
	$text = join('', $beforeT, $math_verb, $afterT);
	return (&balance_inner_tags($text));
    }
    local(@pieces) = split (/<$tag>/, $beforeT );
    $beforeT = shift (@pieces);
    local($cnt,$this) = (0,'');
    while (@pieces) {
	$this = shift @pieces;
	$cnt++;
	$beforeT .= "<$tag>".$this;
	$cnt = $cnt - ($this =~ /<\/$tag>/g);
    }
    if ($cnt) { 
	$beforeT .= "<\/$tag>" . $math_verb . $stag;
	$text = $beforeT . $afterT;
    } else {
	$beforeT .= $math_verb;
	$text = join('', $beforeT, $math_verb, $afterT);
	return (&balance_inner_tags($text));
    }
    $text;
}

# Uses $CURRENT_FILE defined in translate
sub do_cmd_label {
    local($_) = @_;
    local($label);
    $label = &missing_braces unless (
	(s/$next_pair_pr_rx\n?/$label = $2;''/eo)
	||(s/$next_pair_rx\n?/$label = $2;''/eo));
    &anchor_label($label,$CURRENT_FILE,$_);
}

# This subroutine is also used to process labels in undefined environments
sub anchor_label { &real_anchor_label(@_) }
sub real_anchor_label {
    # Modifies entries in %ref_files defined in translate
    local($label,$filename,$context) = @_;
    $label =~ s/<[^>]*>//go;	#RRM: Remove any HTML tags
    $label =~ s/$label_rx/_/g;	# replace non alphanumeric characters
    # Associate the label with the current file
    if ($ref_files{$label} ne $filename) {
	$ref_files{$label} = $filename;
	$noresave{$label} = 0; $changed = 1; }
    print "<LABEL: $label>" if ($VERBOSITY > 3);
    join('',"<A NAME=\"$label\">$anchor_mark</A>",$context);
}

sub do_cmd_cite {
    local($_) = @_;
    &process_cite('','');
}


# This just creates a link from a label (yet to be determined) to the
# cite_key in the citation file.
sub process_cite { &process_real_cite(@_) }
sub process_real_cite {
    local($mode,$text) = @_;
    my $has_text = (($text)? 1 : 0);
#    local($target) = 'contents';print "\nCITE:$text";
    # process the text from \htmlcite or \hypercite
    if ($has_text) {
	$text = &balance_inner_tags($text) 
	    if $use_label =~ (/<\/([A-Z]+)>($math_verbatim_rx.*)<\1>/);
	$text = &translate_environments($text);
	$text = &simplify(&translate_commands($text))
	    if ($use_label =~ /\\/ );
    }

    my $label, $cite_key, $pretag, @cite_keys;
    local($optional_text,$dummy) =  &get_next_optional_argument;
    if ($mode =~ /external/) {
#	$target = '';
	$pretag = $optional_text; $optional_text = '';
	$pretag = &translate_commands($pretag) if ($pretag =~ /\\/);
    } else {
	$optional_text = ", $optional_text" if $optional_text;
    }
    s/^\s*\\space//o;		# Hack - \space is inserted in .aux
    s/$next_pair_pr_rx//o||s/$next_pair_rx//o;
    if (!($cite_key = $2)) {
	print "\n *** Cannot find citation argument\n";
	return ($_);
    }
    @cite_keys = (split(/,/,$cite_key));
    my ($citations, $join) = ('',',');
    $join  = '' if ($text);
    foreach $cite_key (@cite_keys) {
	$cite_key =~ s/(^\s+|\s+$)//g;
	$cite_key =~ s/(^\s+|\s+$)//g;
    # RRM:  if the URL and printable-key are known already, then use them...
	$cite_key =~ s/$label_rx/_/g;
	$label = $cite_key;
	if ($mode eq "nocite") {
	    # nothing more to do, no citations
	} elsif ( ($SEGMENT) && ($cite_info{$cite_key})
		&& ($ref_files{"cite_$cite_key"}) ) {
	    $join  = "," unless ($text);
	    $text = $cite_info{$cite_key} unless ($text);
	    $citations .= join('', $join
		, &make_named_href($label,$ref_files{'cite_'."$cite_key"},$text));
	} elsif (($mode eq "external")&&($external_labels{$pretag."cite_$cite_key"})) {
	    $join  = "," unless ($text);
	    $text = $cross_ref_visible_mark unless ($text);
	    $citations .= join('', $join
		, &make_named_href($label
		    , $external_labels{$pretag.'cite_'."$cite_key"}."\#$label"
		    , $text)
		);
	} elsif ($mode eq 'external') {
	    $join  = "," unless ($text);
	    &write_warnings("\nExternal reference missing for citation: $pretag$cite_key");
	    $citations .= "$text$join#!$pretag$cite_key!#";
        } else {
	    $join  = "," unless ($text);
	    #Replace the key...
	    $citations .= "$join#$cite_key#$cite_mark#$bbl_nr#$text#$cite_mark#";
        }
	$text = '';
    }
    $citations =~ s/^\s*,\s*//;
    if ($has_text) { join('', $citations,  $optional_text, $_) }
    else { join('', "[", $citations,  $optional_text, "]", $_) }
}

sub do_cmd_index { &do_real_index(@_) }
sub do_real_index {
    local($_) = @_;
    local($br_id, $str);
    local($idx_option) = &get_next_optional_argument;
    $str = &missing_braces unless (
	(s/$next_pair_pr_rx/($br_id, $str) = ($1, $2);''/eo)
	||(s/$next_pair_rx/($br_id, $str) = ($1, $2);''/eo));
    join('',&make_index_entry($br_id,$str),$_);
}
sub do_cmd_indexstar { &do_cmd_index(@_) }

# RRM: \bibcite supplies info via the .aux file; necessary with segmented docs.
sub do_cmd_bibcite {
    local($_) = @_;
    local($br_id, $cite_key,$print_key);
    $cite_key = &missing_braces unless (
	(s/$next_pair_pr_rx/($br_id, $cite_key) = ($1, $2);''/eo)
	||(s/$next_pair_rx/($br_id, $cite_key) = ($1, $2);''/eo));
    $print_key = &missing_braces unless (
	(s/$next_pair_pr_rx/($br_id, $print_key) = ($1, $2);''/eo)
	||(s/$next_pair_rx/($br_id, $print_key) = ($1, $2);''/eo));
    $cite_key =~ s/$label_rx/_/g;
    $cite_info{$cite_key} = $print_key;
    $_;
}

# This command will only be encountered inside a thebibliography environment.
sub do_cmd_bibitem { &do_real_bibitem($CURRENT_FILE, @_) }
sub do_real_bibitem {
    local($thisfile, $_) = @_;
    # The square brackets may contain the label to be printed
    local($label, $dummy) = &get_next_optional_argument;
    # Support for the "named" bibliography style
    if ($label) {
 	$label =~ s/\\protect//g;
 	$label = &translate_commands($label) if ($label =~ /\\/);
    }
    local($cite_key);
    $cite_key = &missing_braces unless (
	( s/$next_pair_pr_rx/$cite_key=$2;''/e )
	||( s/$next_pair_rx/$cite_key=$2;''/e ));

    $cite_key =~ s/$label_rx/_/g;
    $label = $cite_info{$cite_key} unless $label; # read from .aux file
    $label = ++$bibitem_counter unless $label; # Numerical labels

    if ($cite_key) {
	# Associate the cite_key with the printed label.
	# The printed label will be substituted back into the document later.
	$cite_info{$cite_key} = &translate_commands($label);
	if (!($ref_files{'cite_'."$cite_key"} eq $thisfile)) {
	    $ref_files{'cite_'."$cite_key"} = $thisfile;
	    $changed = 1; }

        #RRM: apply any special styles, as defined below
	$label = &bibitem_style($label) if (defined &bibitem_style);
	# Create an anchor around the citation
	join('',"<P></P><DT><A NAME=\"$cite_key\">$label</A>\n<DD>", $_);

    } else {
	print "Cannot find bibitem labels: $label\n";

	#RRM: apply any special styles, as defined below
	$label = &bibitem_style($label) if (defined &bibitem_style);
	join('',"<P></P><DT>$label\n<DD>", $_); # AFEB added this line
    }
}

#RRM: override this with a personal style, defined in  .latex2html-init
#sub bibitem_style { join('','<STRONG>',$_[0],'</STRONG>') }
sub bibitem_style {
    return ($_[0]) unless $BIBITEM_STYLE;
    local($text) = join(''
	,"${O}0$C",$BIBITEM_STYLE,"${O}1$C", @_, "${O}1$C","${O}0$C");
    $text = &translate_environments($text);
    &translate_commands($text);
}

sub do_cmd_newblock {
    "<BR>".$_[0]
}

# This just reads in the $FILE.bbl file if it is available and appends
# it to the items that are still to be processed.
# The $FILE.bbl should contain a thebibliography environment which will
# cause its contents to be processed later in the appropriate way.
# (Note that it might be possible for both the \bibliography command and
# the thebibliography environment to be present as the former may have been
# added by the translator as a sectioning command. In this case (both present)
# the $citefile would have already been set by the thebibliography environment)

sub do_cmd_bibliography { &do_real_bibliography($CURRENT_FILE, @_) }
sub do_real_bibliography {
    local($thisfile, $after) = @_;
    if ((defined &do_cmd_bibname)||$new_command{'bibname'}) {
	local($br_id)=++$global{'max_id'};
	$TITLE = &translate_environments("$O$br_id$C\\bibname$O$br_id$C");
    } else { $TITLE = $bib_title }
    $toc_sec_title = $TITLE;
    return($_[0]) if ($making_name);
    local($bibfile);
    $bibfile = &missing_braces unless (
	($after =~ s/$next_pair_rx/$bibfile=$2;''/eo)||
	($after =~ s/$next_pair_rx_rx/$bibfile=$2;''/eo));

    do {
	unless ($citefile) {
	    $citefile = $thisfile;
	    if (&process_ext_file("bbl")) { # *** BINDS $_ as a side effect ***
		$after = join('',$_,$after);}
	    else {
		print "\nCannot open $FILE.bbl $!\n";
		&write_warnings("\nThe bibliography file was not found.");
		$after = join('',"\n<H2>No References!</H2>", $after);
	    }
	}
    print "\n";
    } if $bibfile;
    $after;
}

# allow for customised info-pages, for different languages
sub do_cmd_textohtmlinfopage {
    local($_) = @_;
    local($linfo) = $TITLES_LANGUAGE . '_infopage';
    if (defined &$linfo) { eval "&$linfo"; }
    else { &default_textohtmlinfopage }
}

sub default_textohtmlinfopage {
    local($_) = @_;
    local($argv) = $argv;
    if (-f "../$argv") { $argv = &make_href ("../$argv", $argv, ); }
    $_ = ($INFO && $INFO =~ /^\d+$/
      ? join('', $close_all
	, "<STRONG>$t_title</STRONG><P>\nThis document was generated using the\n"
	, "<A HREF=\"$TEX2HTMLADDRESS\"><STRONG>LaTeX</STRONG>2<tt>HTML</tt></A>"
	, " translator Version $TEX2HTMLVERSION\n"
	, "<P>Copyright &#169; 1993, 1994, 1995, 1996,\n"
	, "<A HREF=\"$AUTHORADDRESS\">Nikos Drakos</A>, \n"
	, "Computer Based Learning Unit, University of Leeds.\n"
	, "<BR>Copyright &#169; 1997, 1998, 1999,\n"
	, "<A HREF=\"$AUTHORADDRESS2\">Ross Moore</A>, \n"
	, "Mathematics Department, Macquarie University, Sydney.\n"
	, "<P>The command line arguments were: <BR>\n "
	, "<STRONG>latex2html</STRONG> <TT>$argv</TT>\n"
	, (($SHOW_INIT_FILE && ($INIT_FILE ne ''))?
	   "\n<P>with initialization from: <TT>$INIT_FILE</TT>\n$init_file_mark\n" :'')
	, "<P>The translation was initiated by $address_data[0] on $address_data[1]"
	, $open_all, $_)
      : join('', $close_all, "$INFO\n", $open_all, $_));
    $_;
}


# Try to translate LaTeX vertical space in a number of <BR>'s.
# Eg. 1cm results in one + two extra <BR>'s.
# To help the browser rendering is quite ugly, but why not.
#
sub get_vspace {
    local($_) = @_;
    local($vh) = 0;

    return("<BR>") if /-/;

    $vh = int($1 * $vspace_12pt{$2} + 0.5)
	if (/([0-9.]+)\s*([a-z]+)/);
    join('',"<BR>","\n<BR>" x $vh);
}

sub do_cmd_vskip {
    local($_) = @_;
    &ignore_numeric_argument;
    join('',&get_vspace($1),$_);
}

sub do_cmd_break {
    local($_) = @_;
    join('',"<BR>",$_);
}

sub do_cmd_vspace {
    local($_) = @_;
    local($how_much);
    $how_much = &missing_braces unless (
	(s/$next_pair_pr_rx/$how_much = $2;''/e)
	||(s/$next_pair_rx/$how_much = $2;''/e));
    join('',&get_vspace($how_much),$_);
}

sub do_cmd_vspacestar {
    &do_cmd_vspace;
}

sub do_cmd_d_backslash {
    local($_) = @_;

    # Eat space from &pre_process.
    # We could also modifiy $single_cmd_rx and %normalize, but why not here.
    s/^ \*?//;
    local($spc,$dum)=&get_next_optional_argument;
    # If the [...] occurs on the next line, then it is *not* an argument to \\ .
    # MRO: replaced $* with /m
    if ($dum =~ /\n/m) { 
	$spc = $`;
        $spc =~ s/\s//gm;
        $_ = $'.$_ 
    }
    join('',(($spc)? &get_vspace($spc): "\n<BR>"),$_);
}


################## Commands used in the $FILE.aux file #######################

sub do_cmd_jobname { $FILE . $_[0] }

# This is used in $FILE.aux
sub do_cmd_newlabel {
    local($_) = @_;
    local($label,$val,$tmp);
    $label = &missing_braces unless (
	(s/$next_pair_pr_rx/$label = $2;''/eo)
	||(s/$next_pair_rx/$label = $2;''/eo));
    $tmp = &missing_braces unless (
	(s/$next_pair_pr_rx/$tmp=$2;''/eo)
	||(s/$next_pair_rx/$tmp=$2;''/eo));
    $val = &missing_braces unless (
	($tmp =~ s/$next_pair_pr_rx/$val=$2;''/eo)
	||($tmp =~ s/$next_pair_rx/$val=$2;''/eo));
    $val =~ s/(^\s+|\s+$)//gs;
    $label =~ s/$label_rx/_/g;	# Replace non alphanumeric characters
    $latex_labels{$label} = $val;
    &do_labels_helper($label);
    $_;
}
sub do_cmd_oldnewlabel { &do_cmd_newlabel(@_) }

#
# Sets %encoded_(section|figure|table)_number, which maps encoded
# section titles to LaTeX numbers
# .= \$number . \"$;\"";
sub do_cmd_oldcontentsline { &do_cmd_contentsline(@_) }
sub do_cmd_contentsline {
    local($_) = @_;
    local($arg,$after,$title,$number,$hash,$stype,$page);
    # The form of the expression is:
    # \contentsline{SECTION} {... {SECTION_NUMBER} TITLE}{PAGE}
    $stype = &missing_braces unless (
        (s/$next_pair_pr_rx/$stype = $2;''/e)
        ||(s/$next_pair_rx/$stype = $2;''/e));
    $arg = &missing_braces unless (
        (s/$next_pair_pr_rx/$arg = $2;''/e)
        ||(s/$next_pair_rx/$arg = $2;''/e));
    $page = &missing_braces unless (
        (s/$next_pair_pr_rx/$page = $2;''/e)
        ||(s/$next_pair_rx/$page = $2;''/e));

#    s/$any_next_pair_pr_rx/$stype = $2;''/eo; # Chop off {SECTION}
#    s/$any_next_pair_pr_rx/$arg   = $2;''/eo; # Get {... {SECTION_NUMBER} TITLE}
#    s/$any_next_pair_pr_rx/$page  = $2;''/eo; # Get page number
    $hash = $stype if (($stype =~ /^(figure|table)$/)||($SHOW_SECTION_NUMBERS));
    $hash =~ s/(sub)*(section|chapter|part)/section/;
    $after = $_;
    if ($hash) {
	if ($arg =~ /^$OP/) {
	    $number = &missing_braces unless (
		($arg =~ s/$next_pair_pr_rx/$number = $2;''/eo)
		||($arg =~ s/$next_pair_rx/$number = $2;''/eo));
	}	
	if ($stype eq "part") {
 	    while ($arg =~ s/$next_pair_pr_rx//o) {};
  	    $number =~ tr/a-z/A-Z/;
   	    $number = "Part $number:"}
	# This cause problem when picking figure numbers...
	# while ($tmp =~ s/$next_pair_pr_rx//o) {};
	$number = -1 unless $number;
#JCL(jcl-tcl)
##	$_ = $arg;
#	$title = &sanitize($arg);
##	&text_cleanup;
##	$title = &encode_title($_);
##
	#remove surrounding brace-numbering
	$arg =~ s/^($O|$OP)\d+($C|$CP)|($O|$OP)\d+($C|$CP)$//g;
	$arg =~ s/\\footnote(mark|text)?//g;
	# \caption arguments should have had environments translated already
	$arg = &translate_environments($arg) if ($arg =~ /\\begin/);
	#replace image-markers by the image params
	$arg =~ s/$image_mark\#([^\#]+)\#/&purify_caption($1)/e;

	#RRM: resolve any embedded cross-references first
	local($checking_caption) = 1;
	$title = &simplify($arg);
	$title = &sanitize($title);
	$checking_caption = '';
	eval "\$encoded_${hash}_number{\$title} .= \$number . \"$;\"";
    }
    $after;
}

#
#  Before normalizing this was \@input.  Used in .aux files.
#
sub do_cmd__at_input {
    local ($_) = @_;
    local ($file, $after);
    $file = &missing_braces unless (
	(s/$next_pair_pr_rx/$file=$2;''/eo)
	||(s/$next_pair_rx/$file=$2;''/eo));
    local($prefix, $suffix) = split(/\./, $file);
    $after = $_;
    local($EXTERNAL_FILE) = $prefix;
    &process_ext_file($suffix);
    $after;
}


########################### Counter Commands #################################
# Removes the definition from the input string, adds to the preamble
# and stores the body in %new_counter;
sub get_body_newcounter {
#    local(*_) = @_;
    local($after_R) = @_;
    local($_) = $$after_R;
    local($within,$ctr,$cmd,$tmp,$body,$pat);
    local($new_ctr) = 'counter';
    ($ctr,$pat) = &get_next(1);	# Get counter name
    &write_warnings ("\n*** LaTeX Error: backslash found in counter-name: $ctr")
	if ($pat =~ s/\\//);
    $ctr =~ s/^\s*\\//; 
    $new_ctr .= $pat;

    ($within,$pat) = &get_next(0);	# Get optional within, currently ignored
    &addto_dependents($within,$ctr);
    $new_ctr .= $pat;
    do {
###	local($_) = "\\arabic<<1>>$ctr<<1>>";
	$body = "\\arabic<<1>>$ctr<<1>>";
	&make_unique($body);
	$cmd = "the$ctr";
	$tmp = "do_cmd_$cmd";
	$new_command{$cmd} = join(':!:',0,$body,'}') unless (defined &$tmp);
	    &write_mydb("new_command", $cmd, $new_command{$cmd});
	undef $body;
    };
    &do_body_newcounter($ctr);

    $$after_R = $_;
    if (!$PREAMBLE) {
	my $new_cmd = join(''
	    , "counter{$ctr}", ($within ? "[$within]" : '') );
	&add_to_preamble('counter','\\new'.$new_cmd);
	return ();
    }
    'newed'.$new_ctr;
}

sub do_body_newcounter {
    local($ctr) = @_;
    $latex_body .= &revert_to_raw_tex("\\newcounter{$ctr}\n")
	unless ($preamble =~ /\\new(counter|theorem){$ctr}/);
    $global{$ctr} = 0;
    &process_commands_wrap_deferred("the$ctr ");
    $_;
}


#RRM: This doesn't work properly yet.
#     The new booleans need to be stored for use in all partitions.
#     \if... \else  \fi  is not yet implemented.

sub get_body_newboolean {
#    local(*_) = @_;
    local($after_R) = @_;
    local($_) = $$after_R;
    my $bool;
    $bool = &missing_braces unless (
	(s/$next_pair_pr_rx/$bool=$2;''/e)
	||(s/$next_pair_rx/$bool=$2;''/e));
    $bool =  &process_body_newif('',$bool);
    $$after_R = $_;
    'newed'.$bool;
}

sub get_body_newif {
#    local(*_) = @_;
    local($after_R) = @_;
    local($_) = $$after_R;
    local($bool);
    if (!(s/^\s*\\if([a-zA-Z]+)//)) {
	$$after_R = $_;
	return();
    }
    $bool = $1;
    $$after_R = $_;
    join('','newed', &process_body_newif('', $bool));
}


sub process_body_newif {
    local($texif, $bool) = @_;
    local($body,$ifbool,$cmd,$tmp,$pat);
   
#    ($bool,$pat) = &get_next(1);	# Get boolean name

#    # change the brace-type around the command-name
#    $pat =~ s/$O/$OP/; $pat =~ s/$C/$CP/; $new_cmd .= $pat;

    $ifbool = "if".$bool;
    $global{$ifbool} = 0;

    do {
	$body = "\$global{'$ifbool'} = 1;";
	$cmd = $bool."true";
	$code = "sub do_cmd_$cmd { ".$body." \$_[0];}";
	eval $code;
	print STDERR "\n*** sub do_cmd_$cmd failed:\n$@\n" if ($@);
	$raw_arg_cmds{$cmd} = 1;

	$body = "\$global{$ifbool} = 0;";
	$cmd = $bool."false";
	$code = "sub do_cmd_$cmd { ".$body." \$_[0];}";
	eval $code;
	print STDERR "\n*** sub do_cmd_$cmd failed:\n$@\n" if ($@);
	$raw_arg_cmds{$cmd} = 1;

	undef $body;
    };
    &process_commands_wrap_deferred("${bool}true\n${bool}false\nif$bool\n");

#    $latex_body .= &revert_to_raw_tex("\\newif\\$ifbool\n")
#	unless ($preamble =~ /\\newif\s*\\$ifbool/);

    if (!$PREAMBLE) {
	local($new_cmd) = "boolean{\\$bool}";
	&add_to_preamble ('newif', "\\new$new_cmd" );
	return ();
    }
    local($br_id) = ++$global{'max_id'};
    'boolean'."$O$br_id$C$bool$O$br_id$C";
}


sub do_cmd_value {
    local($_) = @_;
    local($ctr,$val);
    $ctr = &missing_braces
	unless ((s/$next_pair_pr_rx/$ctr = $2;''/eo)
	      ||(s/$next_pair_rx/$ctr = $2;''/eo));
    $val = &get_counter_value($ctr);
    if ($val) { $val.$_ }
    else { join(''," 0",$_) }
}

sub do_cmd_boolean {
    local($_) = @_;
    local($bool,$val);
    $bool = &missing_braces
	unless ((s/$next_pair_pr_rx/$bool = $2;''/eo)
	      ||(s/$next_pair_rx/$bool = $2;''/eo));
    $val = &get_boolean_value($bool);
    if ($val) { $val.$_ }
    else { "0".$_ }
}

sub get_counter_value {
    local($ctr) = @_;
    local($val,$index);
    $ctr = 'eqn_number' if ($ctr eq "equation");
    $index = $section_commands{$ctr};

    if (defined $global{$ctr}) { $val= $global{$ctr}; }
    elsif (($SEGMENT)&&($index)) { 
	$val = $segment_sec_id[$index]
#    if ($index) { 
#	if ($SEGMENT) { $val = $segment_sec_id[$index] }
#	else { $val = $curr_sec_id[$index] }
    } else {
	&write_warnings ("\ncounter $ctr not defined");
	$val= 0;
    }
    print "\nVAL:$ctr: $val " if ($VERBOSITY > 3);
    $val;
}

sub get_boolean_value {
    local($bool) = @_;
    local($val,$index);
    if (defined $global{$bool}) { $val= $global{$bool} }
    else {
	&write_warnings ("boolean $bool not defined\n");
	$val="0";
    }
    print "\nBOOL:$bool: $val " if ($VERBOSITY > 3);
    $val;
}

sub do_cmd_addtocounter {
    local($_) = @_;
    local($ctr,$num,$index);
    $ctr = &missing_braces
	unless ((s/$next_pair_rx/$ctr = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$ctr = $2;''/eo));
    $num = &missing_braces
	unless ((s/$next_pair_rx/$num = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$num = $2;''/eo));

    $num = &translate_commands($num) if ($num =~ /\\/);
    if ($num !~ /^\s*(\+|-)?\d+\s*$/) {
        print STDERR "\n*** cannot set counter $ctr to $num ***\n";
        return($_);
    }

    $latex_body .= &revert_to_raw_tex("\\addtocounter{$ctr}{$num}\n");
    $index = $section_commands{$ctr};

    if (defined $global{$ctr}) { $global{$ctr} += $num }
    elsif ($index) { 
	if ($SEGMENT) { $segment_sec_id[$index] += $num }
	else { $curr_sec_id[$index] += $num }
	$global{$ctr} += $num;
    } elsif ($ctr eq "equation") {
	$global{'eqn_number'} += $num
    } else { $global{$ctr} += $num };
    print "\nADD:$ctr:+$num= ". $global{$ctr}." " if ($VERBOSITY > 3);
#    &reset_dependents($ctr) if ($dependent{$ctr});
    $_;
}

sub do_cmd_setcounter {
    local($_) = @_;
    local($ctr,$num,$index,$sctr);
    $ctr = &missing_braces
	unless ((s/$next_pair_rx/$ctr = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$ctr = $2;''/eo));
    $num = &missing_braces
	unless ((s/$next_pair_rx/$num = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$num = $2;''/eo));

    $num = &translate_commands($num) if ($num =~ /\\/);
    if ($num !~ /^\s*(\+|-)?\d+\s*$/) {
	print STDERR "\n*** cannot set counter $ctr to $num ***\n";
	return($_);
    }
    if ($ctr =~ /^l/) {
	$sctr = $';
	$ctr = $sctr if $section_commands{$sctr};
    }
    if (! $AUX_FILE && !($ctr =~ /page/ )) {
	$latex_body .= &revert_to_raw_tex("\\setcounter{$ctr}{$num}\n");
	$index = $section_commands{$ctr};
	if ($index) { 
	    if ($curr_sec_id[$index] <= $num ) {
		$curr_sec_id[$index] = $num
	    } else {
		print "\nignoring \\setcounter{$ctr}{$num} currently at ",$curr_sec_id[$index] ;
		&write_warnings(join('',"\n\\setcounter{$ctr}{$num} ignored,"
			," cannot reduce from ",$curr_sec_id[$index]));
	    }
	    $global{$ctr} = $num;
	} elsif ($ctr eq "equation") {$global{'eqn_number'} = $num }
	else { $global{$ctr} = $num };
    }
    print "\nSET:$ctr: = $num" if ($VERBOSITY > 3);
#    &reset_dependents($ctr) if ($dependent{$ctr});
    $_;
}

sub do_cmd_setlength {
    local($_) = @_;
    local($dimen,$value,$index,$sctr);
    $dimen = &missing_braces
	unless ((s/$next_pair_rx/$dimen = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$dimen = $2;''/eo));
    $value = &missing_braces
	unless ((s/$next_pair_rx/$value = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$value = $2;''/eo));

    # recognise specific length-parameters
    if ($dimen =~ /captionwidth/) {
	local($pxs,$len) = &convert_length($value, $MATH_SCALE_FACTOR);
	$cap_width = $pxs if ($pxs &&($dimen =~ /captionwidth/));
    }
    if ((! $AUX_FILE)&&(! $PREAMBLE)) {
	$latex_body .= &revert_to_raw_tex("\\setlength{$dimen}{$value}\n");
	print "\nSETLENGTH:$dimen = $value" if ($VERBOSITY > 3);
    }
    $_;
}

sub do_cmd_setboolean {
    local($_) = @_;
    local($bool,$val);
    $bool = &missing_braces
	unless ((s/$next_pair_rx/$bool = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$bool = $2;''/eo));
    $val = &missing_braces
	unless ((s/$next_pair_rx/$val = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$val = $2;''/eo));
    if (! $AUX_FILE) {
	$latex_body .= &revert_to_raw_tex("\\setboolean{$bool}{$val}\n");
	$global{"if$bool"} = (($val = ~/true/) ? 1 : 0);
	print "\nSETBOOL:$bool = $val" if ($VERBOSITY > 3);
    }
    $_;
}

sub do_cmd_endsegment {
    local($_) = @_;
    local($ctr,$dum) = &get_next_optional_argument;
    local($index,$steps) = ('',1);
#    $steps = &missing_braces unless (
#	(s/$next_pair_pr_rx/$steps = $2;''/e)
#	||(s/$next_pair_rx/$steps = $2;''/e));
    $index = $section_commands{$ctr} if $ctr;
#    if ($index) { $curr_sec_id[$index] += $steps }
#    if ($index) { ($after_segment,$after_seg_num) = ($index,$steps) }
    if ($index) { ($after_segment,$after_seg_num) = ($index,1) }
    $_;
}

sub do_cmd_stepcounter {
    local($_) = @_;
    local($ctr,$index);
    $ctr = &missing_braces
	unless ((s/$next_pair_rx/$ctr = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$ctr = $2;''/eo));
    if (! $AUX_FILE) {
	$latex_body .= &revert_to_raw_tex("\\stepcounter{$ctr}\n");
	$index = $section_commands{$ctr};
	if ($index) {
#	    if ($SEGMENT) { $segment_sec_id[$index] += 1 }
#	    else { $curr_sec_id[$index] += 1 }
	    $global{$ctr} += 1;
	} elsif ($ctr eq "equation") { $global{'eqn_number'} += 1 }
	else { $global{$ctr} += 1 };
    }
    print "\nSTP:$ctr:+1" if ($VERBOSITY > 3);
    &reset_dependents($ctr) if ($dependent{$ctr});
    $_;
}

#RRM:   dependent counters are stored as a comma-separated list
#       in the %dependent hash.
sub reset_dependents {
    local($ctr) = @_;
    local($dep,$subdep,%dependents);
    @dependents = (split($delim, $dependent{$ctr}));
    print "\n" if (($VERBOSITY > 3)&&(@dependents));
    while (@dependents) {
	$dep = pop(@dependents);
	print "RESET $dep to 0\n" if ($VERBOSITY > 3);
	if ($global{$dep}) { $global{$dep} = 0 }
	elsif ($dep =~ /equation/) { $global{'eqn_number'} = 0 }
	if ($dependent{$dep}) {
	    push(@dependents,split($delim,$dependent{$dep}));
	}
    }
}

sub do_cmd_numberwithin {
    local($_) = @_;
    local($ctr,$within);
    $ctr = &missing_braces
	unless ((s/$next_pair_rx/$ctr = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$ctr = $2;''/eo));
    $within = &missing_braces
	unless ((s/$next_pair_rx/$within = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$within = $2;''/eo));

    # record the counter dependency
    &addto_dependents($within,$ctr) if ($within);
    local($newsub) = "sub do_cmd_the$ctr {"
	. "\$global{'max_id'}++;\n"
#        . "local(\$super)=\&do_cmd_the$within();\n"
	. "local(\$super)=\&translate_commands('\\the$within');\n"
	. "\$super .= '.' unless (\$super =~/\\.\$/);\n"
	. "\$super .\&do_cmd_value('<<'.\$global{'max_id'}.'>>"
	. $ctr . "<<'.\$global{'max_id'}.'>>')}\n";
    eval $newsub;
    print " *** sub do_cmd_the$ctr unchanged *** $@ " if ($@);
    $_;
}

sub do_cmd_refstepcounter {
    local($_) = @_;
    local($ctr);
    $ctr = &missing_braces
	unless ((s/$next_pair_rx/$ctr = $2;''/eo)
	      ||(s/$next_pair_pr_rx/$ctr = $2;''/eo));
    if (! $AUX_FILE) {
	$latex_body .= &revert_to_raw_tex("\\refstepcounter{$ctr}\n");
	$index = $section_commands{$ctr};
	if (defined $global{$ctr}) { $global{$ctr} += 1 }
	elsif ($index) {
	    if ($SEGMENT) { $segment_sec_id[$index] += 1 }
	    else { $curr_sec_id[$index] += 1 }
	} elsif ($ctr eq "equation") { $global{'eqn_number'} += 1 }
	else { $global{$ctr} += 1 };
    }
    print "\nSTP: $ctr : +1" if ($VERBOSITY > 3);
    &reset_dependents($ctr) if ($dependent{$ctr});
    $_;
}

sub read_counter_value {
    local($_) = @_;
    local($ctr,$br_id,$val);
    $ctr = &missing_braces
        unless ((s/$next_pair_pr_rx/$br_id = $1; $ctr = $2;''/eo)
              ||(s/$next_pair_rx/$br_id = $1; $ctr = $2;''/eo));
    $val = &get_counter_value($ctr);
    ($ctr, $val, $br_id, $_)
}

sub styled_number_text {
    local($num_style, $val, $txtID) = @_;
    if ($USING_STYLES) {
        $txt_style{$num_style} = " " unless ($txt_style{$num_style});
        join('',"<SPAN CLASS=\"$num_style\">", $val, "</SPAN>", $_);
    } else { $val.$_ }
}

sub do_cmd_arabic {
    local($ctr, $val, $id, $_) = &read_counter_value($_[0]);
    $val = ($val ? &farabic($val) : "0");
    &styled_number_text('arabic', $val, $id);
}
    
sub do_cmd_roman {
    local($ctr, $val, $id, $_) = &read_counter_value($_[0]);
    if ($val < 0 ) { $val = join('',"-",&froman(-$val)); }
    elsif ($val) { $val = &froman($val) }
    else { $val = "0"; }
    &styled_number_text('roman', $val, $id);
}

sub do_cmd_Roman {
    local($ctr, $val, $id, $_) = &read_counter_value($_[0]);
    if ($val < 0 ) { $val = join('',"-",&fRoman(-$val)); }
    elsif ($val) { $val = &fRoman($val) }
    else { $val = "0"; }
    &styled_number_text('Roman', $val, $id);
}

sub do_cmd_alph {
    local($ctr, $val, $id, $_) = &read_counter_value($_[0]);
    if ($val < 0 ) { $val = join('',"-",&falph(-$val)); }
    elsif ($val) { $val = &falph($val) }
    else { $val = "0"; }
    &styled_number_text('alph', $val, $id);
}

sub do_cmd_Alph {
    local($ctr, $val, $id, $_) = &read_counter_value($_[0]);
    if ($val < 0 ) { $val = join('',"-",&fAlph(-$val)); }
    elsif ($val) { $val = &fAlph($val) }
    else { $val = "0"; }
    &styled_number_text('Alph', $val, $id);
}


sub do_cmd_fnsymbol {
    local($ctr, $val, $id, $_) = &read_counter_value($_[0]);
    $val = &process_in_latex_helper($ctr, $val, "fnsymbol{$ctr}");
    &styled_number_text('Alph', $val, $id);
}



# This is a general command for getting counter values;
# e.g. for section-numbers.

sub do_cmd_thecounter {
    local($_) = @_;
    # Uses $counter bound by the caller
    local($val) = &get_counter_value($counter);
    $val = &process_in_latex_helper($counter,$val,"the$counter");
    &styled_number_text($counter, $val, '');
#   join('',&process_in_latex_helper($counter,$val,"the$counter"),$_[0]);
}


################# Special Naming Macros ##################################

sub do_cmd_LaTeX {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'LaTeX'} = ' ' unless ($env_style{'LaTeX'});
	$env_style{'logo-LaTeX'} = ' ' unless ($env_style{'logo-LaTeX'});
	join('',"<SPAN CLASS=\"logo,LaTeX\">",$Laname, $TeXname,"</SPAN>",$_);
    } else { join('',$Laname, $TeXname, $_); }
}

sub do_cmd_LaTeXe {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'LaTeX2e'} = ' ' unless ($env_style{'LaTeX2e'});
	$env_style{'logo-LaTeX2e'} = ' ' unless ($env_style{'logo-LaTeX2e'});
	join('',"<SPAN CLASS=\"logo,LaTeX2e\">"
		,$Laname, $TeXname,'2<SUB>e</SUB>',"</SPAN>",$_);
    } else { join('',$Laname,$TeXname
		,(($HTML_VERSION >= 3.0)? '2<SUB>e</SUB>':'2e'),$_);
    }
}

sub do_cmd_latextohtml {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'LaTeX2HTML'} = ' ' unless ($env_style{'LaTeX2HTML'});
	$env_style{'logo-LaTeX2HTML'} = ' ' unless ($env_style{'logo-LaTeX2HTML'});
	join('',"<SPAN CLASS=\"logo,LaTeX2HTML\">"
		,$Laname, $TeXname,"2<TT>HTML</TT>","</SPAN>",$_);
    } else { join('',$Laname,$TeXname,"2<TT>HTML</TT>",$_);}
}

sub do_cmd_TeX {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'logo-TeX'} = ' ' unless ($env_style{'logo-TeX'});
	join('',"<SPAN CLASS=\"logo-TeX\">",$TeXname,"</SPAN>",$_);
    } else { join('',$TeXname, $_);}
}

sub do_cmd_MF {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'logo-Metafont'} = ' ' unless ($env_style{'logo-Metafont'});
	join('',"<SPAN CLASS=\"logo-Metafont\">",$MFname,"</SPAN>",$_);
    } else { join('', $MFname, $_);}
}

sub do_cmd_Xy {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'logo-Xy-pic'} = ' ' unless ($env_style{'logo-Xy-pic'});
	join('',"<SPAN CLASS=\"logo-Xy-pic\">",$Xyname,"</SPAN>",$_);
    } else { join('',$Xyname, $_);}
}

sub do_cmd_AmS {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'logo-AMS'} = ' ' unless ($env_style{'logo-AMS'});
	join('',"<SPAN CLASS=\"logo-AMS\">",$AmSname,"</SPAN>",$_);
    } else { join('',$AmSname, $_);}
}

sub do_cmd_AmSTeX {
    local($_) = @_;
    if ($USING_STYLES) {
	$env_style{'logo-AMS'} = ' ' unless ($env_style{'logo-AMS'});
	join('',"<SPAN CLASS=\"logo-AMS\">",$AmSname,"-$TeXname","</SPAN>",$_);
    } else { join('',$AmSname, "-", $TeXname, $_);}
}

sub do_cmd_char {
    local($_) = @_;
# some special characters are already turned into l2h internal
# representation.
# Get its represention from the table and use it like as regexp form.
    local($spmquot) = &escape_rx_chars($html_specials{'"'});
# Get all internal special char representations as implied during
# preprocessing.
    local($spmrx) = join("\000",values %html_specials);
# escape regexp special chars (not really necessary yet, but why not)
    $spmrx = &escape_rx_chars($spmrx); #~ s:([\\(){}[\]\^\$*+?.|]):\\$1:g;
    $spmrx =~ s/\000/|/g;
    $spmrx = "(.)" unless $spmrx =~ s/(.+)/($1|.)/;

    s/^[ \t]*(\d{1,3})[ \t]*/&#$1;/ &&
	return($_);

    s/^[ \t]*\'(\d{1,3})[ \t]*/"&#".oct($1).";"/e &&
	return($_);

    s/^[ \t]*$spmquot(\d{1,2})[ \t]*/"&#".hex($1).";"/e &&
	return($_);

# This is a kludge to work together with german.perl. Brrr.
    s/^[ \t]*\'\'(\d{1,2})[ \t]*/"&#".hex($1).";"/e &&
	return($_);
# If l2h's special char marker represents more than one character,
# it's already in the &#xxx; form. Else convert the single character
# into &#xxx; with the ord() command.
    s/^[ \t]*\`\\?$spmrx[ \t]*/
	(length($html_specials_inv{$1}) > 1 ?
	 $html_specials_inv{$1} : "&#".ord($html_specials_inv{$1}||$1).";")/e &&
	     return($_);
    &write_warnings(join('',
			 "Could not find character number in \\char",
			 (/\n/ ? $` : $_), " etc.\n"));
    $_;
}


sub do_cmd_symbol {
    local($_) = @_;
    local($char);
    $char = &missing_braces
	unless ((s/$next_pair_pr_rx/$char = $2;''/eo)
		||(s/$next_pair_rx/$char = $2;''/eo));
    join('',&do_cmd_char($char),$_);
}

################# Accent and Special Symbols ##################################

# Generate code for the accents handling commands that are never
# applied to i or j.
# MEH: Now all accents are safe for dotless i or j
# MEH: Math accents supported as well
sub generate_accent_commands {
    local($accent,$accent_cmd);
    local(%accents) = ("c", "cedil", "pc", "cedil", "d", "bdot", "b", "b",
		       "tilde", "tilde", "dot", "dot", "bar", "macr",
		       "hat", "circ", "u", "breve", "v", "caron",
		       "H", "dblac", "t", "t", "grave", "grave",
		       "acute", "acute", "ddot", "uml", "check", "caron",
		       "breve", "breve", "vec", "vec",
		       "k", "ogon", "r", "ring");
    foreach $accent (keys(%accents))  {
	$accent_cmd = "sub do_cmd_$accent {" . 'local($_) = @_;'  .
	    "&accent_safe_for_ij('$accents{$accent}','$accent');" . '$_}';
	eval $accent_cmd;
	$accent_cmd = "do_cmd_$accent";
	print STDERR "\n*** sub do_cmd_$accent failed:\nPERL: $@\n" if ($@);
    }
}

# These handle accents, taking care of the dotless i's and j's that
# may follow (even though accented j's are not part of any alphabet
# that I know).
#
# Note that many forms of accents over dotless i's and j's are
# handled:
#   "\^\i rest"
#   "\^\i
#    rest"
#   "\^{\i}rest"
#   "\^\i{}rest"
# They all produce "&#238;rest".
# MEH: now also handles
#   "\^{}rest"
#   "\^,rest"
# and many more

sub accent_safe_for_ij {
    local($type,$acc_cmd) = @_;
    local($arg, $first_char,$ij_cmd);
    #print STDOUT "\nACCENT: $type <$_>\n" ;
    s/^[ \t]*\n?[ \t]*(\S)/$1/;	# Remove whitespace
    if (s/^\\([ij])([^a-zA-Z]|$)/$2/) {
	# Accent of this form: "\^\i rest" or "\^\i{}rest"
	($arg) =  $1; $ij_cmd = "\\$1";
	s/^[ \t]+//o;		# Get rid of whitespaces after \i
	if (substr($_, 0, 2) =~ /[\n\r][^\n\r]/) {
	    $_ = substr($_, 1); # Get rid of 1 newline after \i
	}
    } else {
	# Accent of this form: "\^{\i}rest" or not an accent on i nor j
	($arg) =  &get_next_pair_or_char_pr;
    }
    $arg =~ s/([^\s\\<])/$first_char = $1; ''/eo;
#   print STDOUT "\nACCENT1 type:$type arg:|${arg}| first_char: |$first_char| $ij_cmd 
#	, $ACCENT_IMAGES\n";

    local($aafter) = $_;
    local($iso) = &iso_map($first_char,$type); 
    if ($iso) { $_ = join('', $iso, $arg, $aafter) }
    elsif ((!($ACCENT_IMAGES))&&(!($ij_cmd))) {
	local($err_string) = 
	    "\nNo available accent for $first_char$type , using just \"$first_char$arg\"";
	print $err_string if ($DEBUG||$VERBOSITY > 1);
	&write_warnings("\n ...set \$ACCENT_IMAGES  to get an image ");
	$_ = join('', $first_char, $arg, $aafter) }
    else { 
	print ", making image of accent: $first_char$type " if ($VERBOSITY > 1);
	$_ = join('', &mbox_accent($acc_cmd, $first_char, $ij_cmd) , $arg, $aafter)
    }
}

sub mbox_accent {
    local($type, $char, $ij_cmd) = @_;
    if (length($type) > 1 ) {
	if ($text_accent{$type}) {
	    $type = $text_accent{$type};
	} elsif ($type =~ /^(math)?accent/) {
	} else {
	    print "\n unrecognised accent $type for `$char' ";
	    return $char;
	}
    }
    local(@styles);
    local($cmd,$style,$bstyle,$estyle) = ('','','','');
    local(@styles) = split(',',$ACCENT_IMAGES);
    foreach $style (@styles) {
	$style =~ s/(^\s*\\|\s*)//g; 
	$cmd = "do_cmd_$style";
	if (defined &$cmd) { 
	    $bstyle .= "\\$style\{" ;
	    $estyle .= "\}";
	} else {
	    &write_warnings("\nunrecognized style \\$style for accented characters");
	}
    }
    if (!($bstyle)) {
	$bstyle = "\{";
	$estyle = "\}";
    } elsif ($bstyle =~ /textit|itshape/) {
	$bstyle = '\raise.5pt\hbox{' . $bstyle ;	
	$estyle .= "\}";
    }
    $char = $ij_cmd if ($ij_cmd);
    print STDOUT "\nACCENT: $type, $char" if ($VERBOSITY > 2);
    local($afterkern); # serifs extend too far on some letters...
    $afterkern = "\\kern.05em" if (($char =~ /m|n/)||($type=~/[Hv]/));
    # ...or the accent is wider than the letter, so pad it out a bit
    $afterkern = "\\kern.15em" if ($char =~ /i|l/); #||($type=~/v/));

    &process_undefined_environment("tex2html_accent_inline"
        , ++$global{'max_id'}, "${bstyle}\\${type}\{$char\\/\}$estyle$afterkern");
}

# MEH: Actually tries to find a dotless i or j
sub do_cmd_i { join('',&iso_map('i', 'nodot') || 'i', $_[0]) }
sub do_cmd_j { join('',&iso_map('j', 'nodot') || 'j', $_[0]) }

sub do_cmd_accent {
    local($_) = @_;
    local($number);
    if (s/\s*(\d+)\s*//o) {$number = $1}
    elsif (s/\s*&SMPquot;(\d)(\d)\s*//o) { $number = $1*16 + $2 }
    elsif (s/\s*\'(\d)(\d)(\d)\s*//o) { $number = $1*64 + $2*8 + $3 }
    else { s/\s*(\W\w+)([\s\W])/$2/o;  $number = $1 }
    local($type) = $accent_type{uc($number)};
    #print STDOUT "\ndo_cmd_accent: $number ($type) |$_|\n";
    if (! $type) {
	&write_warnings("Accent number $number is unknown.\n");
	return $_;
    }
    &accent_safe_for_ij($type , 'accent$number' );
    $_;
}

sub do_cmd_ae { join('', &iso_map("ae", "lig"), $_[0]);}
sub do_cmd_AE { join('', &iso_map("AE", "lig"), $_[0]);}
sub do_cmd_aa { join('', &iso_map("a", "ring"), $_[0]);}
sub do_cmd_AA { join('', &iso_map("A", "ring"), $_[0]);}
sub do_cmd_o { join('', &iso_map("o", "slash"), $_[0]);}
sub do_cmd_O { join('', &iso_map("O", "slash"), $_[0]);}
sub do_cmd_ss { join('', &iso_map("sz", "lig"), $_[0]);}
sub do_cmd_DH { join('', &iso_map("ETH", ""), $_[0]);}
sub do_cmd_dh { join('', &iso_map("eth", ""), $_[0]);}
sub do_cmd_TH { join('', &iso_map("THORN", ""), $_[0]);}
sub do_cmd_th { join('', &iso_map("thorn", ""), $_[0]);}

sub do_cmd_pounds { join('', &iso_map("pounds", ""), $_[0]);}
sub do_cmd_S { join('', &iso_map("S", ""), $_[0]);}
sub do_cmd_copyright { join('', &iso_map("copyright", ""), $_[0]);}
sub do_cmd_P { join('', &iso_map("P", ""), $_[0]);}


sub brackets { ($OP, $CP);}

sub get_date {
    local($format,$order) = @_;
    local(@lt) = localtime;
    local($d,$m,$y) = @lt[3,4,5];
    if ($format =~ /ISO/) {
	sprintf("%4d-%02d-%02d", 1900+$y, $m+1, $d);
    } elsif ($format) {
	if ($order) { eval "sprintf(".$format.",".$order.")"; }
	else { sprintf($format, $d, $m+1, 1900+$y); }
    } else { sprintf("%d/%d/%d", $m+1, $d, 1900+$y); }
}

sub address_data {
    local($user, $date, $_);
    local($format,$order) = @_;
    # Get author, (email address) and current date.
    ($user = L2hos->fullname()) =~ s/,.*//;
    ($user, &get_date($format,$order));
}


#################################### LaTeX2e ##################################

sub missing_braces {
#    local($cmd) = @_;
    local($next, $revert, $thisline);
    local($this_cmd) = $cmd;
    $this_cmd =~ s/^\\// unless ($cmd eq "\\");
    &write_warnings("\n? brace missing for \\$this_cmd");
    if (/^[\s%]*([^\n]*)\n/ ) {
	$thisline = &revert_to_raw_tex($1)
    } else { 
	$thisline = &revert_to_raw_tex($_); 
    }
    print "\n\n*** no brace for \\$this_cmd , before:\n$thisline";
    s/^\s*//;
    if ($_ =~ s/$next_token_rx//) { $next = $& };
    $next =~ s/$comment_mark(\d+\n?)?//g;
#    $next = &translate_commands($next) if ($next =~ /^\\/);
    if ($next =~ /^\\(\W|\d|[a-zA-z]*\b)/) {
	$revert = $next = "\\".$1;
    } elsif ($next =~ /\W/) {
	$revert = &revert_to_raw_tex($next);
    } else { $revert = $next };
    print "\n*** using \"$revert\" as the argument instead; is this correct?  ***\n\n";
    $next;
}

#RRM:
#     &styled_text_chunk  provides an interface for pieces of styled text,
# within a single paragraph. The visual markup can be obtained through either
# 1. link to a stylesheet (CSS)
# 2. direct markup placed into the output
# 3. calling another function to process the text
# 
# parameters (in order):
#  $def_tag   : markup tag to be used, unless $USING_STYLES or no $property given,
#		attributes can be included, only 1st word is used for closing-tag;
#  $prefix    : prefix for the Unique ID identifier, defaults to 'txt'
#           OR  contains  CLASS= identifier  when $property is empty(see below);
#  $type      : general type of the style-sheet information
#  $class     : specific type of the style-sheet information
#  $property  : value to be set, applicable to the $type & $class
#  $alt_proc  : name of procedure to use, if $USING_STYLES == 0, and no $def_tag
#  $_         : current data-stream
#  $open_tags_R : current open-tags (not used in this procedure)

sub styled_text_chunk {
    local($def_tag, $prefix, $type, $class, $property, $alt_proc, $_,
        $ot) = @_;
    local($open_tags_R) = defined $ot ? $ot : $open_tags_R;
    local($text, $env_id, $def_end);
    local($span_tag) = 'SPAN';
    $text = &missing_braces
        unless ((s/$next_pair_pr_rx/$text = $2; $env_id = $1;''/eo)
	    || (s/$next_pair_rx/$text = $2; $env_id = $1;''/eo));
    $text = &balance_inner_tags($text);

    #start from no open tags
    local(@save_open_tags) = ();
    local($open_tags_R) = [];

#    local($decl); 
#    if ($prefix =~ /CLASS="(\w+)"/ ) {
#	$decl=$1;
#	push (@$open_tags_R, $decl);
#    }
#    push (@$open_tags_R, $color_env) if $color_env;
    if (!$inside_math) {
	$text = &translate_environments($text);
	$text = &translate_commands($text) if ($text =~ /\\/);
	$text .= &balance_tags;
    }
    
    if (($USING_STYLES)&&($env_id =~ /^\d+$/)&&($property)) { 
	$prefix = 'txt' unless ($prefix);
	$env_id = $prefix.$env_id;
	$styleID{$env_id} = join('',"$type", ($class ? "-$class" : '')
				 ,": ", $property,"; ");
	return(join('',"<$span_tag ID=\"$env_id\">",$text,"<\/$span_tag>", $_));
    }

    if (($USING_STYLES)&&($prefix =~ /($span_tag )?CLASS=\"(\w+)\"/o)) {
	local($span_class) = $2;
	$def_tag = (($1)? $1 : $span_tag." ");
	$txt_style{$span_class} = "$type: $class "
	    unless ($txt_style{$span_class});
	return(join('',"<$def_tag CLASS=\"$span_class\">"
		, $text,"<\/$span_tag>", $_));
    }

    if (($def_tag) && (!$USING_STYLES)) {
	$def_tag =~ s/^($span_tag)?CLASS=\"(\w+)\"$// ;
    }

    if ($def_tag =~ /^(\w+)/) {
	$def_end = $1;
	return(join('',"<$def_tag>",$text,"<\/$def_end>", $_));
    }

    return (join('', eval ("&$alt_proc(\$text)") , $_)) if (defined "&$alt_proc");

    &write_warnings(
	"\ncannot honour request for $type-$class:$property style at br$env_id");
    join('', $text, $_);
}

sub multi_styled_text_chunk {
    local($def_tag, $prefix, $type, $class, $property, $_, $ot) = @_;
    local($open_tags_R) = defined $ot ? $ot : $open_tags_R;
    $prefix = 'txt' unless ($prefix);
    my(@def_tags) = split(',',$def_tag);
    my(@types) = split(',',$type);
    my(@classes) = split(',',$class);
    my(@properties) = split(',',$property);
    $text = &missing_braces
        unless ((s/$next_pair_pr_rx/$text = $2; $env_id = $1;''/eo)
	    || (s/$next_pair_rx/$text = $2; $env_id = $1;''/eo));
    if (($USING_STYLES)&&($env_id =~ /^\d+$/)&&($property)) { 
        # $1 contains the bracket-id
	$env_id = $prefix.$env_id;
	while (@properties) {
	    $class = shift @classes;
	    $property = shift @properties;
	    $styleID{$env_id} .= join(''
		, shift @types,
		, ($class ? "-".$class : '')
		, ($property ? " : $property" : ''), " ; ");
	    $styleID{$env_id} .= "\n\t\t  " if (@properties);
	}
    }
    join('',"<SPAN ID=\"$env_id\">",$text,"<\/SPAN>", $_);
}

#RRM: 
#   This one takes care of commands with argument that really should be
#   environments; e.g.  \centerline, \rightline, etc.
#   Note that styles are inherited also from the existing @$open_tags_R.
#
sub styled_text_block {
    local($def_tag, $attrib, $value, $class, $_, $ot) = @_;
    local($open_tags_R) = defined $ot ? $ot : $open_tags_R;
    local($text, $env_id, $attribs);
    if ($attribs =~ /,/ ) {
        local(@attribs) = split(',',$attrib);
	local(@values) = split(',',$value);
	while (@attribs) { 
            $attribs .= join('', " " , shift @attribs 
	        ,"=\"" , shift @values, "\"") }
    } elsif($value) { 
        $attribs = join(''," ",$attrib,"=\"",$value,"\"")
    } else { $attribs = " " . $attrib }

    local(@save_open_tags) = @$open_tags_R;
    local($closures) = &close_all_tags();
    local($reopens)=&balance_tags();
    $text = &missing_braces
        unless ((s/$next_pair_pr_rx/$text = $2; $env_id = $1;''/eo)
	    || (s/$next_pair_rx/$text = $2; $env_id = $1;''/eo));
    if (($USING_STYLES)&&($env_id =~ /^\d+$/)) {
	$env_id = ++$global{'max_id'};
	$env_id = "par".$env_id;
	$styleID{$env_id} = " ";
	$env_style{$class} = " " if (($class)&&!($env_style{$class}));
	$class = " CLASS=\"$class\"" if ($class);
	$env_id = " ID=\"$env_id\"";
    } else { $class = ''; $env_id = '' };

    $text = &translate_environments($text);
    $text = &translate_commands($text);

    local($closuresA)=&close_all_tags();
    local($reopensA) = &balance_tags();
    $text =~ s/^\n?/\n/o; 
    join('', $closures
        , "<$def_tag$class$env_id$attribs>"
        , $reopens, $text, $closuresA
        , "</$def_tag>\n", $reopensA,  $_);
}


# this gives a separate ID for each instance
#sub do_cmd_textbf { &styled_text_chunk('B','','font','weight'
#		    ,'bold', '', @_); }
#
# this uses a single CLASS for all instances
sub do_cmd_textbf { &styled_text_chunk('B','CLASS="textbf"'
		    ,'font-weight','bold', '', '', @_); }


# this gives a separate ID for each instance
sub do_cmd_texttt { &styled_text_chunk('TT','','font','','', '', @_); }

# this uses a single CLASS for all instances
#sub do_cmd_textit { &styled_text_chunk('TT','CLASS="textit"'
#		    ,'font-family','monospace', '', '', @_); }
#
# this gives a separate ID for each instance
#sub do_cmd_textit { &styled_text_chunk('I','','font','style'
#		    ,'italic', '', @_); }
#
# this uses a single CLASS for all instances
sub do_cmd_textit { &styled_text_chunk('I','CLASS="textit"'
		    ,'font-style','italic', '', '', @_); }



# this gives a separate ID for each instance
#sub do_cmd_textsl { &styled_text_chunk('I','','font','style'
#		    ,'oblique', '', @_); }
#
# this uses a single CLASS for all instances
#sub do_cmd_textsl { &styled_text_chunk('I','CLASS="textsl"'
#		    ,'font-style','oblique', '', '', @_); }
#
# ... NS4 implements Italic, not oblique
sub do_cmd_textsl { &styled_text_chunk('I','CLASS="textsl"'
		    ,'font-style','italic', '', '', @_); }


# this gives a separate ID for each instance
#sub do_cmd_textsf { &styled_text_chunk('I','','font','family'
#		    ,'sans-serif', '', @_); }
#
# this uses a single CLASS for all instances
#sub do_cmd_textsf { &styled_text_chunk('I','CLASS="textsf"'
#		    ,'font-family','sans-serif', '', '', @_); }
#
# ... NS4 doesn't implement sans-serif
sub do_cmd_textsf { &styled_text_chunk('I','CLASS="textsf"'
		    ,'font-style','italic', '', '', @_); }


#sub do_cmd_textsc {
#    local($_) = @_;
#    local($text, $next, $scstr, $before, $special);
#    $text = &missing_braces
#        unless ((s/$next_pair_pr_rx/$text = $2;''/eo)
#	    || (s/$next_pair_rx/$text = $2;''/eo));
#    join('', &process_smallcaps($text), $_);
#}

sub lowercase_entity {
    local($char) = @_;
    local($exent);
    if ($exent = $low_entities{$char}) { "\&#$exent;" }
    elsif ($exent = $extra_small_caps{$char}) { $exent }
    else { "\&#$char;" }
}

sub process_smallcaps {
    local($text) = @_;
    local($next, $scstr, $scbef, $special, $char);
    # is this enough for \sc and \scshape ?
    $text = &translate_environments($text);

    # MRO: replaced $* with /m
    while ($text =~ /(\\[a-zA-Z]+|[&;]SPM\w+;|<[^>]+>)+/m ) {
	$scbef = $`; $special = $&; $text = $';
	while ( $scbef =~ /(&#\d+;|[a-z$sclower])+[a-z\W\d$sclower]*/m) {
	    $scstr .= $`; $scbef = $';
	    $next = $&; 
	    $next =~ s/&#(\d+);/&lowercase_entity($1)/egm;
	    eval "\$next =~ $scextra" if ($scextra);
	    eval "\$next =~ tr/a-z$sclower/A-Z$scupper/";
	    $scstr .= "<SMALL>" . $next ."<\/SMALL>";
	}
	$scstr .= $scbef . $special;
    }
    if ($text) {
	while ( $text =~ /(&#\d+;|[a-z$sclower])+[a-z\W\d$sclower]*/m) {
	    $scstr .= $`; $text = $';
	    $next = $&;
	    $next =~ s/&#(\d+);/&lowercase_entity($1)/egm;
	    eval "\$next =~ $scextra" if ($scextra);
	    eval "\$next =~ tr/a-z$sclower/A-Z$scupper/";
	    $scstr .= "<SMALL>" . $next ."<\/SMALL>";
	}
	$scstr .= $text;
    }
    $scstr;
}

# this gives a separate ID for each instance
#sub do_cmd_textsc { &styled_text_chunk('','','font','variant'
#		    ,'small-caps', 'process_smallcaps', @_); }
#
# this uses a single CLASS for all instances
#sub do_cmd_textsc { &styled_text_chunk('', 'CLASS="textsc"'
#		    ,'font-variant','small-caps','', 'process_smallcaps', @_); }
#
# ...but NS 4.03 doesn't implement  small-caps !!!
sub do_cmd_textsc { &styled_text_chunk('',''
		    ,'font-variant','small-caps','', 'process_smallcaps', @_); }


#sub do_cmd_emph { &styled_text_chunk('EM','em','font','variant','','', @_); }


# this gives a separate ID for each instance
#sub do_cmd_underline { &styled_text_chunk('U','','text','decoration','underline','', @_); }

# this uses a single CLASS for all instances
sub do_cmd_underline { &styled_text_chunk('U','CLASS="underline"'
		       ,'text-decoration','underline','','', @_); }
sub do_cmd_underbar { &do_cmd_underline(@_) }


# this gives a separate ID for each instance
#sub do_cmd_strikeout { &styled_text_chunk('STRIKE',''
#		       ,'text','decoration','line-through','', @_); }

# this uses a single CLASS for all instances
sub do_cmd_strikeout { &styled_text_chunk('STRIKE','CLASS="strikeout"',
		       'text-decoration','line-through','','', @_); }


sub do_cmd_uppercase {
    local($_) = @_;
    local($text,$next,$done,$special,$after);
    $text = &missing_braces unless (
	    (s/$next_pair_pr_rx/$text = $2;''/eo)
	    ||(s/$next_pair_rx/$text = $2;''/eo));
    $after = $_;
    while ($text =~ /(\\[a-zA-Z]+|[&;]SPM\w+;)/ ) {
	$next = $`;
	$special = $&;
	$text = $';
	$next =~ tr /a-z/A-Z/ if ($next);
	$done .= $next . $special;
    }
    $text =~ tr /a-z/A-Z/ if ($text);
    $done .= $text;
    $done = &convert_iso_latin_chars($done) if ($done);
    join('',$done,$after);
}

sub do_cmd_lowercase {
    local($_) = @_;
    local($text,$next,$done,$special,$after);
    $text = &missing_braces
        unless ((s/$next_pair_pr_rx/$text = $2;''/seo)
	    || (s/$next_pair_rx/$text = $2;''/seo));
    $after = $_;
    while ($text =~ /(\\[a-zA-Z]+|[&;]SPM\w+;)/ ) {
	$next = $`;
	$special = $&;
	$text = $';
	$next =~ tr /A-Z/a-z/ if ($next);
	$done .= $next . $special;
    }
    $text =~ tr /A-Z/a-z/ if ($text);
    $done .= $text;
    $done = &convert_iso_latin_chars($done) if ($done);
    join('',$done,$after);
}

sub do_cmd_MakeUppercase { &do_cmd_uppercase(@_) }
sub do_cmd_MakeLowercase { &do_cmd_lowercase(@_) }



sub do_cmd_ensuremath {
    local($_) = @_;
    local ($id, $value);
    $value = &missing_braces unless (
	(s/$next_pair_pr_rx/$value=$2;''/eo)
	||(s/$next_pair_rx/$value=$2;''/eo));
    join('', &simple_math_env($value), $');
}

#
#  This is mainly for \special{header=PostScript_Prologue},
#	and \graphicspath{path} which occur OUTSIDE of an environment
#	passed to TeX.  \special's INSIDE such environments are, of
#	course, left alone.

sub do_cmd_special {
    local($_) = @_;
    local ($id, $value);
    $value = &missing_braces unless (
	(s/$next_pair_pr_rx/$value=$2;''/eo)
	||(s/$next_pair_rx/$value=$2;''/eo));
    local($special_cmd) = &revert_to_raw_tex($value);
    &add_to_preamble($cmd,"\\$cmd\{$special_cmd\}");
    $_;
}


########################## Input and Include commands #########################

sub do_cmd_input {
    local($_) = @_;
    local($file,$output);
    (s/\s*(.*)\s*\n/$file =$1;''/s) unless (
	(s/$next_pair_pr_rx/$file=$2;''/eo)
	||(s/$next_pair_rx/$file=$2;''/eo));
    local($after) = $_;
    $file = &revert_to_raw_tex("\\input{$file}\n") if $file;
    if ($PREAMBLE) { &add_to_preamble('include',$file)}
    elsif (!($file=~/^\s*$/)) {
	$output = &process_undefined_environment('center'
		, ++$global{'max_id'},"\\vbox{$file}");
    }
    $output.$after;
}

sub do_cmd_include {
    local($_) = @_;
    local($file,$output);
    $file = &missing_braces unless (
	(s/$next_pair_pr_rx/$file=$2;''/eo)
	||(s/$next_pair_rx/$file=$2;''/eo));
    local($after) = $_;
    $file = &revert_to_raw_tex("\\include{$file}\n") if $file;
    if ($PREAMBLE) { &add_to_preamble('include',$file)}
    else {
	$output = &process_undefined_environment('figure'
		, ++$global{'max_id'},"\\vbox{$file}");
    }
    $output.$after;
}

########################## Messages #########################

sub do_cmd_message {
    local($_) = @_;
    local($message);
    $message = &missing_braces unless (
	(s/$next_pair_pr_rx/$message=$2;''/eo)
	||(s/$next_pair_rx/$message=$2;''/eo));
    local($after) = $_;
    $message = &translate_commands($message);
    $message =~ s/$comment_mark(\d+)//og;
    print STDOUT "\n*** $message ***\n";
    $after;
}

sub do_cmd_typeout {
    print STDOUT "\n";
    local($_) = &do_cmd_message(@_);
    print STDOUT "\n";
    $_;
}

sub do_cmd_expandafter {
    local($_) = @_;
    print "\nEXPANDAFTER: " if ($VERBOSITY >3);
    return($_) unless (s/^\s*(\\\w+)\s*\\//o);
    print " delaying $1 " if ($VERBOSITY >3);
    local($delay,$cmd) = ($1,'');
    s/^(\w+|\W)/$cmd=$1;''/eo;
    local($nextcmd) = "do_cmd_$cmd";
    if (defined &$nextcmd) { $_ = &$nextcmd($_) }
    elsif ($new_command{$cmd}) { 
        local($argn, $body, $opt) = split(/:!:/, $new_command{$cmd});
	do { ### local($_) = $body;
	    &make_unique($body);
	} if ($body =~ /$O/);
	if ($argn) {
	    do {
		local($before) = '';
		local($after) = "\\$cmd ".$_;
		$after = &substitute_newcmd;   # may change $after
                $after =~ s/\\\@#\@\@/\\/o unless ($after);
            };
	} else { $_ = $body . $_; }
    } else { print "\nUNKNOWN COMMAND: $cmd "; }

    # now put the delayed function back for processing
    join('',$delay, " ", $_);
}

sub do_cmd_tracingall {
    print "\nTRACING:\n$ref_contents\n$after\n";
    $VERBOSITY = 8; ""; }

sub do_cmd_htmltracenv { &do_cmd_htmltracing }

sub do_cmd_htmltracing {
    local($_) = @_;
    local($value);
    $value = &missing_braces
        unless ((s/$next_pair_rx/$value = $2;''/eo)
	    ||(s/$next_pair_pr_rx/$value = $2;''/eo));
    if ($value =~ /^\s*(\d+)\s*$/) { 
	$VERBOSITY = $1;
	if ($VERBOSITY) { 
	    print "\n\n *** setting trace-level to $VERBOSITY ***\n";
	} else {
	    print "\n\n *** cancelling all tracing ***\n\n";
	}
    } else {
	&write_warnings("argument to \\htmltracing must be a number");
     }
    $_ ;
}


############################ Initialization ####################################

sub initialise {
    ############################ Global variables ###############################
    $PREAMBLE = 2;		# 1 while translating preamble, 0 while translating body 
    $NESTING_LEVEL = undef;	#counter for TeX group nesting level
    $OUT_NODE = 0;		# Used in making filenames of HTML nodes unique
    $eqno_prefix = '';		# default prefix on equation numbers
    ($O , $C, $OP, $CP) = ('<<' , '>>', '<#', '#>'); # Open/Close Markers
    $href_name = 0;		# Used in the HREF NAME= field
    $wrap_toggle = 'end';
    $delim = '%:%';		# Delimits items of sectioning information
				# stored in a string

    $LATEX2HTML_META = '<META NAME="Generator" CONTENT="LaTeX2HTML v'.$TEX2HTMLV_SHORT.'">'
	. "\n<META HTTP-EQUIV=\"Content-Style-Type\" CONTENT=\"text/css\">"
	      unless ($LATEX2HTML_META);

    $TeXname = (($HTML_VERSION ge "3.0")? "T<SMALL>E</SMALL>X" : "TeX");
    $Laname = (($HTML_VERSION ge "3.0")? "L<SUP><SMALL>A</SMALL></SUP>" : "La");
    $MFname = (($HTML_VERSION ge "3.0")? "M<SMALL>ETAFONT</SMALL>" : "Metafont");
    $Xyname = (($HTML_VERSION ge "3.0")? "X<SUB><BIG>Y</BIG></SUB>" : "Xy");
    $AmSname = (($HTML_VERSION ge "3.0")? "A<SUB><BIG>M</BIG></SUB>S" : "AmS");

    $EQN_TAGS = "R" unless ($EQN_TAGS);
    $EQNO_START = "(";
    $EQNO_END   = ")";

    $AtBeginDocument_hook  = "\$AtBeginDocument_hook\=\'\'; "
	unless $AtBeginDocument_hook;
    $cross_ref_mark = '<tex2html_cr_mark>';
    $external_ref_mark = '<tex2html_ext_cr_mark>';
    $cite_mark = '<tex2html_cite_mark>';
    $hash_mark = '<tex2html_hash_mark>';
    $protected_hash = '<tex2html_protected_hash>';
    $param_mark = '<tex2html_param_mark>';
    $bbl_mark = '<tex2html_bbl_mark>';
    $toc_mark = '<tex2html_toc_mark>';
    $lof_mark = '<tex2html_lof_mark>';
    $lot_mark = '<tex2html_lot_mark>';
    $info_page_mark = '<tex2html_info_page_mark>';
    $info_title_mark = '<tex2html_info_title_mark>';
    $init_file_mark = '<tex2html_init_file_mark>';
    $childlinks_on_mark = '<tex2html_childlinks_mark>';
    $childlinks_null_mark = '<tex2html_childlinks_null_mark>';
    $childlinks_mark = $childlinks_on_mark;
    $more_links_mark = '<tex2html_morelinks_mark>';
    $idx_mark = '<tex2html_idx_mark>';
    $verbatim_mark = '<tex2html_verbatim_mark>';
    $unfinished_mark = '<tex2html_unfinished_mark>';
    $verb_mark = '<tex2html_verb_mark>';
    $verbstar_mark = '<tex2html_verbstar_mark>';
    $image_mark = '<tex2html_image_mark>';
    $mydb_mark =  '<tex2html_mydb_mark>';
    $percent_mark = '<tex2html_percent_mark>';
    $ampersand_mark = '<tex2html_ampersand_mark>';
    $dol_mark = '<tex2html_lone_dollar>';
    $comment_mark = '<tex2html_comment_mark>';
    $caption_mark = '<tex2html_caption_mark>';
    $array_col_mark = '<tex2html_col_mark>';
    $array_row_mark = '<tex2html_row_mark>';
    $array_text_mark = '<tex2html_text_mark>';
    $array_mbox_mark = '<tex2html_mbox_mark>';

    $bibitem_counter = 0;
    $undef_mark = '<tex2html_undef_mark>';
    $file_mark = '<tex2html_file>';
    $endfile_mark = '<tex2html_endfile>';

    # This defines textual markers for all the icons
    # e.g. $up_visible_mark = '<tex2html_up_visible_mark>';
    # They will be replaced with the real icons at the very end.
    foreach $icon (keys %icons) {eval "\$$icon = '<tex2html_$icon>'"};

    # Make sure $HTML_VERSION is in the right range and in the right format.
#    $HTML_VERSION =~ /[\d.]*/;
#    $HTML_VERSION = 0.0 + $&;
#    $HTML_VERSION = 2 if ( $HTML_VERSION < 2 );
#    $HTML_VERSION = 9 if ( $HTML_VERSION > 9 );
#    $HTML_VERSION = sprintf("%3.1f",$HTML_VERSION);

    &banner();
    print "Revised and extended by:"
	. "\n Marcus Hennecke, Ross Moore, Herb Swan and others\n";

    # Collect HTML options and figure out HTML version
    $HTML_OPTIONS = '' unless ($HTML_OPTIONS);
    $HTML_VERSION =~ s/^html|\s+//g;
    local(@HTML_VERSION) = split(/,/, $HTML_VERSION);
    foreach ( @HTML_VERSION ) {
	if (/^[\d\.]+$/) {
	    # Make sure $HTML_VERSION is in the right range and in the right format.
	    $HTML_VERSION = 0.0 + $_;
	    $HTML_VERSION = 2 if ( $HTML_VERSION < 2 );
	    $HTML_VERSION = 9 if ( $HTML_VERSION > 9 );
	    $HTML_VERSION = sprintf("%3.1f",$HTML_VERSION);
	} else {
	    $HTML_OPTIONS .= "$_,";
	}
    }
    $HTML_OPTIONS =~ s/\W$//;  # remove any trailing punctuation

    print "...producing markup for HTML version $HTML_VERSION  ";
    print ($HTML_OPTIONS ? "with $HTML_OPTIONS extensions\n\n\n" : "\n\n\n");

    # load the character defs for latin-1, but don't set the charset yet
    &do_require_extension('latin1');
    $charset = $CHARSET = $PREV_CHARSET = '';

    if ($HTML_VERSION =~ /(2.0|3.0|3.2|4.0|4.1)/) {
	# Require the version specific file 
	do { $_ = "$LATEX2HTMLVERSIONS${dd}html$1.pl";
	     if (!(-f $_)) {  s/(\d).(\d.pl)$/$1_$2/ };
	     if (!(-f $_)) {  s/(\d)_(\d.pl)$/$1-$2/ };
	     require $_ || die "\n*** Could not load $_ ***\n";
	     print "\nHTML version: loading $_\n";
	} unless ($HTML_VERSION =~ /2.0/);
	$DOCTYPE = "-//".(($HTML_VERSION eq "2.0")? "IETF" : "W3C")
	    . "//DTD HTML $HTML_VERSION"
	    .(($HTML_VERSION eq "3.2")? " Final" : "")
	    .(($HTML_VERSION eq "4.0")? " Transitional" : "");

	if ($HTML_OPTIONS) {
	    local($ext);
	    local($loading_extensions) = 1;
	    # Require the option specific files 
	    @HTML_VERSION = split(/,/, $HTML_OPTIONS);
	    foreach $ext ( @HTML_VERSION ) {
		&do_require_extension($ext);
#		do {
#		    print "\nLoading $LATEX2HTMLVERSIONS$dd$ext.pl";
#		    require "$LATEX2HTMLVERSIONS$dd$ext.pl";
#		} if (-f "$LATEX2HTMLVERSIONS$dd$ext.pl");
	    }
	    undef $loading_extensions;
	}
    } else {
	print "\n You specified an invalid version: $HTML_VERSION\n"
	    . "In future please request extensions by name:\n"
	    . "  i18n  table  math  frame  latin1  unicode  etc.\n";

    # Require all necessary version specific files
	foreach ( sort <$LATEX2HTMLVERSIONS${dd}html[1-9].[0-9].pl> ) {
	    last if ( $_ gt "$LATEX2HTMLVERSIONS${dd}html$HTML_VERSION.pl" );
	    do { print "\nloading $_" if ($DEBUG);
		 require $_; } unless (
		($NO_SIMPLE_MATH)&&($_ eq "$LATEX2HTMLVERSIONS${dd}html3.1.pl"));
	};
	$STRICT_HTML = 0;
    }

    # packages automatically implemented, or clearly irrelevant
    %styles_loaded = 
     ( 'theorem' , 1 , 'enumerate', 1 , 'a4paper' , 1 , 'b5paper' , 1
     , '10pt' , 1 , '11pt' , 1 , '12pt' , 1
     , %styles_loaded );


    %declarations =
    ('em' , '<EM></EM>',
     'it' , '<I></I>',
     'bf' , '<B></B>',
     'tt' , '<TT></TT>',
     'sl' , '<I></I>',		# Oops!
     'sf' , '<I></I>',		# Oops!
     'rm' ,  '<></>',
     'rmfamily'   ,'<></>',     # see $fontchange_rx
     'normalfont' ,'<></>',     # see $fontweight_rx and $fontchange_rx
     'mdseries'   ,'<></>',     # see $fontweight_rx
     'upshape'    ,'<></>',     # see $fontchange_rx
     'itshape' ,  '<I></I>',
     'bfseries' , '<B></B>',
     'ttfamily' , '<TT></TT>',
     'slshape' ,  '<I></I>',	# Oops!
     'sffamily' , '<I></I>',	# Oops!
##     'scshape' ,  '<I></I>',	# Oops!
#     'boldmath' , '<B></B>',
#     'quote', '<BLOCKQUOTE></BLOCKQUOTE>',
#     'quotation', '<BLOCKQUOTE></BLOCKQUOTE>',
     %declarations	# Just in case someone extends it in the init file
     );


%declarations = (
     'tiny', '<FONT SIZE="-2"></FONT>',
     'Tiny', '<FONT SIZE="-2"></FONT>',
     'scriptsize', '<FONT SIZE="-2"></FONT>',
     'small', '<FONT SIZE="-1"></FONT>',
     'Small', '<FONT SIZE="-1"></FONT>',
     'SMALL', '<FONT SIZE="-1"></FONT>',
     'smaller', '<SMALL></SMALL>',
     'footnotesize', '<FONT SIZE="-1"></FONT>',
     'larger', '<BIG></BIG>',
     'large', '<FONT SIZE="+1"></FONT>',
     'Large', '<FONT SIZE="+2"></FONT>',
     'LARGE', '<FONT SIZE="+2"></FONT>',
     'huge', '<FONT SIZE="+3"></FONT>',
     'Huge', '<FONT SIZE="+4"></FONT>',
#     'centering', '<DIV ALIGN="CENTER"></DIV>',
#     'center', '<DIV ALIGN="CENTER"></DIV>',
#     'flushleft', '<DIV ALIGN="LEFT"></DIV>',
#     'raggedright', '<DIV ALIGN="LEFT"></DIV>',
#     'flushright', '<DIV ALIGN="RIGHT"></DIV>',
#     'raggedleft', '<DIV ALIGN="RIGHT"></DIV>',
     %declarations
    ) if ($HTML_VERSION > 2.0 );

#  no alignment in HTML 2.0
#%declarations = (
#     'centering', '<P ALIGN="CENTER"></P>',
#     'center', '<P ALIGN="CENTER"></P>',
#     'flushleft', '<P ALIGN="LEFT"></P>',
#     'raggedright', '<P ALIGN="LEFT"></P>',
#     'flushright', '<P ALIGN="RIGHT"></P>',
#     'raggedleft', '<P ALIGN="RIGHT"></P>',

%declarations = (
#     'centering', '<P></P>',
     'center', '<P></P>',
     'flushleft', '<P></P>',
     'raggedright', '<P></P>',
     'flushright', '<P></P>',
     'raggedleft', '<P></P>',
     'quote', '<BLOCKQUOTE></BLOCKQUOTE>',
     'quotation', '<BLOCKQUOTE></BLOCKQUOTE>',
     'verse', '<BLOCKQUOTE></BLOCKQUOTE>',
     'preform', '<PRE></PRE>',
     'unord', '<UL></UL>',
     'ord', '<OL></OL>',
     'desc', '<DL></DL>',
     'list', '',
     'par', '<P></P>'
    ) if ($HTML_VERSION == 2.0 );

    &generate_declaration_subs;	# Generate code to handle declarations

    # ...but these block-level divisions must be handled differently...
%declarations = (
     'quote', '<BLOCKQUOTE></BLOCKQUOTE>',
     'quotation', '<BLOCKQUOTE></BLOCKQUOTE>',
     'verse', '<BLOCKQUOTE></BLOCKQUOTE>',
     'preform', '<PRE></PRE>',
     'unord', '<UL></UL>',
     'ord', '<OL></OL>',
     'desc', '<DL></DL>',
#     'list', '<DIV></DIV>',
     'par', '<P></P>',
     'samepage', '',
#     'centering', '<DIV ALIGN="CENTER"></DIV>',
     'center', '<DIV ALIGN="CENTER"></DIV>',
     'flushleft', '<DIV ALIGN="LEFT"></DIV>',
     'raggedright', '<DIV ALIGN="LEFT"></DIV>',
     'flushright', '<DIV ALIGN="RIGHT"></DIV>',
     'raggedleft', '<DIV ALIGN="RIGHT"></DIV>',
     %declarations
    ) if ($HTML_VERSION > 2.0 );


    %section_commands =
	('partstar' , '1' , 'chapterstar', '2', 'sectionstar', '3'
	, 'subsectionstar', '4', 'subsubsectionstar', '5', 'paragraphstar'
	, '6', 'subparagraphstar', '7'
	, 'part' , '1' , 'chapter', '2', 'section', '3','subsection', '4'
	, 'subsubsection', '5', 'paragraph', '6', 'subparagraph', '7'
	, 'slidehead', '3', %section_commands);
    # The tableofcontents, listoffigures, listoftables, bibliography and
    # textohtmlindex are set after determining what is the outermost level
    # in sub set_depth_levels. Appendix is implemented as a command.

    %standard_section_headings =
	('part' , 'H1' , 'chapter' , 'H1', 'section', 'H1', 'subsection', 'H2'
	, 'subsubsection', 'H3', 'paragraph', 'H4', 'subparagraph', 'H5'
	, %standard_section_headings );

    # Generates code to handle sectioning commands
    # for those sections which take an argument.
    &generate_sectioning_subs;

    %section_headings =
	('partstar' , 'H1' , 'chapterstar' , 'H1', 'sectionstar', 'H1'
	, 'subsectionstar', 'H2', 'subsubsectionstar', 'H3', 'paragraphstar'
	, 'H4', 'subparagraphstar', 'H5', %section_headings);

    # These need their own custom code but are treated as sectioning commands
    %section_headings =
	('tableofcontents', 'H2', 'listoffigures', 'H2', 'listoftables', 'H2'
	, 'bibliography', 'H2', 'textohtmlindex', 'H2'
	, %standard_section_headings
	, %section_headings);

    &generate_accent_commands;	# Code to handle accent commands

    # These are replaced as soon as the text is read in.
    %html_specials = (  '<', ';SPMlt;'
		,  '>', ';SPMgt;'
		,  '&', ';SPMamp;'
#		,  '``', '\lq\lq '  # probably not a good idea
#		,  "''", '\rq\rq ',  # probably not a good idea
		,  '"', ';SPMquot;'
		);

    %html_specials = ( %html_specials
		, '``', ';SPMldquo;', "''", ';SPMrdquo;'
		) if ($HTML_VERSION >= 5 );

    # This mapping is needed in sub revert_to_raw_tex
    # before passing stuff to latex for processing.
    %html_specials_inv = (
    		 ';SPMlt;' ,'<'
		, ';SPMgt;','>'
		, ';SPMamp;','&'
		, ';SPMquot;','"'
		, ';SPMldquo;','``'
		, ';SPMrdquo;',"''"
		, ';SPMdollar;', '$'	# for alltt
		, ';SPMpct;', '%'
		, ';SPMtilde;', '&#126;'
		);

    # normalsize vertical dimension factors for 12pt (1.0 <=> <BR>)
    %vspace_12pt = ('ex', 1.0, 'em', 1.0, 'pt', 0.1, 'pc', 1.0,
	'in', 6.0, 'bp', 0.1, 'cm', 2.3, 'mm', 0.2, 'dd', 0.1,
	'cc', 1.0, 'sp', 0.0);

    # For some commands such as \\, \, etc it is not possible to define
    # perl subroutines because perl does not allow some non-ascii characters
    # in subroutine names. So we define a table and a subroutine to relate
    # such commands to ascii names.
    %normalize = ('\\', 'd_backslash'
		  , '/', 'esc_slash', "`", 'grave'
		  , "'", 'acute', "^", 'hat', '"', 'ddot'
		  , '~', 'tilde', '.', 'dot', '=', 'bar'
		  , '{', 'lbrace' , '}', 'rbrace', '|', 'Vert'
		  , '#', 'esc_hash', '$', 'esc_dollar'
                 );

    %text_accent = (  'cedil','c', 'bdot','d', 'b','b' , 'tilde','~'
                    , 'circ' ,'^', 'hat','^', 'check','v' , 'caron','v'
                    , 'acute','\'' , 'grave','`' , 'dot','.' , 'breve','u'
                    , 'ddot','"' , 'uml','"' , 'bar','=','macr','='
                    , 'dblacc','H' , 't','t' , 'ogon','k' , 'ring','r'
                  );

    # %languages_translations holds for each known language the
    # appropriate translation function. The function is called in
    # slurp_input.
    # The translation functions subtitute LaTeX macros
    # with ISO-LATIN-1 character references
    %language_translations = (
	   'english',	'english_translation'
	 , 'USenglish',	'english_translation'
	 , 'original',	'english_translation'
	 , 'german',	'german_translation'
	 , 'austrian',	'german_translation'
	 , 'finnish',	'finnish_translation'
	 , 'french',	'french_translation'
	 , 'spanish',	'spanish_translation'
	 , 'swedish',	'swedish_translation'
	 , 'turkish',	'turkish_translation'
	);

# Reiner: 
#    $standard_label_rx = 
#	"\\s*[[]\\s*(((\$any_next_pair_rx4)|([[][^]]*[]])|[^]])*)[]]";
#    $enum_label_rx = "^((({[^{}]*})|([^{}]))*)([aAiI1])(.*)";
#    $enum_level = 0;	# level for enumerate (1-4, i-iv)
    %enum = ( 
		'enumi',	0,			# counter for level 1
		'enumii',	0,			# counter for level 2
		'enumiii',	0,
		'enumiv',	0,
		'theenumi',	"&arabic('enumi')",	# eval($enum{"theenumi"})
		'theenumii',	"&alph('enumii')",
		'theenumiii',	"&roman('enumiii')",
		'theenumiv',	"&Alph('enumiv')",
			# e.g. eval("$enum{'labelenumi'}")
		'labelenumi',	'eval($enum{"theenumi"}) . "."', 
		'labelenumii',	'"(" . eval($enum{"theenumii"}) . ")"',	
		'labelenumiii',	'eval($enum{"theenumiii"}) . "."',
		'labelenumiv',	'eval($enum{"theenumiv"}) . "."'
		);

    %RomanI = ( '1',"I",'2',"II",'3',"III",'4',"IV"
		    ,'5',"V",'6',"VI",'7',"VII", '8',"VIII",'9',"IX");
    %RomanX = ( '1',"X",'2',"XX",'3',"XXX",'4',"XL"
		    ,'5',"L",'6',"LX",'7',"LXX", '8',"LXXX",'9',"XC");
    %RomanC = ( '1',"C",'2',"CC",'3',"CCC",'4',"CD"
		    ,'5',"D",'6',"DC",'7',"DCC", '8',"DCCC",'9',"CM");
    %RomanM = ( '1',"M",'2',"MM",'3',"MMM",'4',"MH"
		    ,'5',"H",'6',"HM",'7',"HMM",'8',"HMMM");

    %enum_label_funcs = ( 
	"a", "alph", "A", "Alph", "i", "roman", "I", "Roman", "1", "arabic" );

sub farabic{
    local($_)=@_;
    $_;
}
sub arabic{
    local($_)=@_;
    eval($enum{$_});
}

sub falph{
    local($num)=@_;
#    chr($num+64);
    substr(" abcdefghijklmnopqrstuvwxyz",$num,1)
}
sub alph{
    local($num)=@_;
    &falph(eval($enum{$num}));
}
sub fAlph{
    local($num)=@_;
#    chr($num+32);
    substr(" ABCDEFGHIJKLMNOPQRSTUVWXYZ",$num,1)
}
sub Alph{
    local($num)=@_;
    &falph(eval($enum{$num}));
}

sub Roman{
    local($num)=@_;
    &fRoman(eval($enum{$num}));
}
sub fRoman{
    local($num)=@_;
    local($RmI)= $num%10; ($RmI) = (($RmI) ? $RomanI{"$RmI"} : '' );
    $num = $num/10; local($RmX)= $num%10; ($RmX) = (($RmX) ? $RomanX{"$RmX"} : '' );
    $num = $num/10; local($RmC)= $num%10; ($RmC) = (($RmC) ? $RomanC{"$RmC"} : '' );
    $num = $num/10; local($RmM)= $num%10; ($RmM) = (($RmM) ? $RomanM{"$RmM"} : '' );
    "$RmM" . "$RmC" . "$RmX" . "$RmI";
}
sub froman{
    local($_)=@_;
    $_ = &fRoman($_);
    $_ =~ tr/A-Z/a-z/;
    $_;
}
sub roman{
    local($num)=@_;
    &froman(eval($enum{$num}));
}


    %unitscale = ("in",72,"pt",72.27/72,"pc",12,"mm",72/25.4,"cm",72/2.54
		  ,"\\hsize",100,"\\vsize",100
		  ,"\\textwidth",100,"\\textheight",100
		  ,"\\pagewidth",100,"\\linewidth",100
		  );
    %units = ("in","in","pt","pt","pc","pi","mm","mm","cm","cm"
	      ,"\\hsize","%","\\vsize","%","\\textwidth","%","\\textheight","%");

sub convert_length { # clean
    my ($this,$scale) = @_;
    $scale = 1 unless $scale;
    my ($pxs,$len,$full);
    if ( $this =~ /([\d.]*)\s*(in|pt|pc|mm|cm|\\[hv]size|\\\w+(width|height))?/ ) {
	$len = ($1 ? $1 : 1); $full = $2;
	if ($full &&($full =~ /\\([hv]size|\w+(width|height))/)) { $scale = 1;};
	$pxs = (($full) ? int($len * $unitscale{$full}*$scale + 0.5)
		 : int($len*$scale + .5) );
	if ( $full =~ /\\([hv]size|\w+(width|height))/) { $pxs .= '%';};
    };
    ($pxs,$len);
}
 



    # Inclusion in this list will cause a command or an environment to be ignored.
    # This is suitable for commands without arguments and for environments.
    # If however a do_env|cmd_<env|cmd> exists then it will be used.
    %ignore = ('sloppypar', 1,  'document', 1, 'newblock', 1,
	       ',', 1,  '@', 1, ' ', 1,  '-', 1,
               'sloppy', 1,
	       'hyphen', 1, 'titlepage', 1, 'htmlonly', 1,
	       'flushleft', 1, 'flushright', 1, 'slide', 1,
	       'tiny', 1, 'Tiny', 1, 'scriptsize', 1, 'footnotesize', 1,
	       'small', 1, 'normalsize', 1, 'large', 1, 'Large', 1,
	       'LARGE', 1, 'huge', 1, 'Huge', 1,
	       %ignore);

    # Specify commands with arguments that should be ignored.
    # Arbitrary code can be placed between the arguments
    # to be executed while processing the command.
    #
# Note that some commands MAY HAVE ARGUMENTS WHICH SHOULD BE LEFT AS TEXT
    # EVEN THOUGH THE COMMAND IS IGNORED (e.g. hbox, center, etc)

&ignore_commands( <<_IGNORED_CMDS_);
NeedsTeXFormat # {} # []
ProvidesClass # {} # []
ProvidesFile # {} # []
ProvidesPackage # {} # []
abovedisplayskip # &ignore_numeric_argument
abovedisplayshortskip # &ignore_numeric_argument
addcontentsline # {} # {} # {}
addtocontents # {} # {}
addvspace # {} # &ignore_numeric_argument
and
and # \$_ = join(''," - ",\$_)
backmatter
baselineskip # &ignore_numeric_argument
belowdisplayskip # &ignore_numeric_argument
belowdisplayshortskip # &ignore_numeric_argument
bibdata
bibliographystyle # {}
bibstyle # {}
bigskipamount # &ignore_numeric_argument
smallskipamount # &ignore_numeric_argument
medskipamount # &ignore_numeric_argument
center
citation # {}
citeauthoryear
clearpage
cline # {}
#documentclass # [] # {}
#documentstyle # [] # {}
#end # {}
enlargethispage # {}
evensidemargin # &ignore_numeric_argument
filecontents
filbreak
fil
fill
flushbottom
fontsize # {} # {}
footheight # &ignore_numeric_argument
footskip  # &ignore_numeric_argument
frontmatter
fussy
global
goodbreak
hbox
headheight # &ignore_numeric_argument
headsep # &ignore_numeric_argument
hfil
hfill
hfuzz # &ignore_numeric_argument
hline
hspace # {} # \$_ = join(''," ",\$_)
hspacestar # {} # \$_ = join(''," ",\$_)
html
ifcase
ignorespaces
indent
itemindent # &ignore_numeric_argument
itemsep # &ignore_numeric_argument
labelsep # &ignore_numeric_argument
labelwidth # &ignore_numeric_argument
leavevmode
leftmargin # &ignore_numeric_argument
listparindent # &ignore_numeric_argument
lower # &ignore_numeric_argument
long
mainmatter
makebox # [] # []
makeindex
marginpar # {}
marginparsep # &ignore_numeric_argument
marginparwidth # &ignore_numeric_argument
markboth # {} # {}
markright # {}
mathord
mathbin
mathindent # &ignore_numeric_argument
mathrel
mathop
mathtt
#mdseries
newpage
#newedboolean # {}
#newedcommand # {} # [] # [] # {}
#newedcounter # {} # []
#newedenvironment # {} # [] # [] # {} # {}
#newedtheorem # {} # [] # {} # []
#providedcommand # {} # [] # [] # {}
#renewedcommand # {} # [] # [] # {}
#renewedenvironment # {} # [] # [] # {} # {}
nobreakspace # \$_ = join('',";SPMnbsp;",\$_)
nonbreakingspace # \$_ = join('',";SPMnbsp;",\$_)
noalign
nobreak
nocite # {}
noindent
nolinebreak# []
nopagebreak #[]
normalmarginpar
numberline
oddsidemargin # &ignore_numeric_argument
omit
onecolumn
outer
pagenumbering #{}
pagestyle # {}
parindent # &ignore_numeric_argument
parsep # &ignore_numeric_argument
parskip # &ignore_numeric_argument
partopsep # &ignore_numeric_argument
penalty # &ignore_numeric_argument
phantom # {}
protect
raggedright
raggedbottom
raise # &ignore_numeric_argument
raisebox # {} # [] # []
relax
reversemarginpar
rightmargin # &ignore_numeric_argument
#rmfamily
rule # [] # {} # {}
samepage
selectfont
startdocument # \$SEGMENT=1;\$SEGMENTED=1; \$_
strut
suppressfloats # []
textheight # &ignore_numeric_argument
textwidth # &ignore_numeric_argument
textnormal
#textrm
textup
theorempreskipamount # &ignore_numeric_argument
theorempostskipamount # &ignore_numeric_argument
thispagestyle # {}
topmargin # &ignore_numeric_argument
topsep # &ignore_numeric_argument
topskip # &ignore_numeric_argument
twocolumn
unskip
#upshape
vfil
vfill
vfilll
vline
_IGNORED_CMDS_

    # Commands which need to be passed, ALONG WITH THEIR ARGUMENTS, to TeX.
    # Note that this means that the arguments should *not* be translated,
    # This is handled by wrapping the commands in the dummy tex2html_wrap
    # environment before translation begins ...

    # Also it can be used to specify environments which may be defined
    # using do_env_* but whose contents will be passed to LaTeX and
    # therefore should not be translated.
    # Note that this code squeezes spaces out of the args of psfig;


    # Images are cropped to the minimum bounding-box for these...

&process_commands_in_tex (<<_RAW_ARG_CMDS_);
psfig # {} # \$args =~ s/ //g;
usebox # {}
framebox # [] # [] # {}
_RAW_ARG_CMDS_

    # ... but these are set in a box to measure height/depth 
    # so that white space can be preserved in the images.

&process_commands_inline_in_tex (<<_RAW_ARG_CMDS_);
#etalchar # {} \$args =~ s/(.*)/\$\^\{\$1\}\\\$/o; 
fbox # {}
#frac # [] # {} # {}
dag
ddag
l
L
oe
OE
textexclamdown
textquestiondown
textregistered
textperiodcentered
#textcircled # {}
#raisebox # {} # [] # [] # {}
_RAW_ARG_CMDS_



# These are handled by wrapping the commands in the dummy tex2html_nowrap
# environment before translation begins. This environment will be
# stripped off later, when the commands are put into  images.tex  ...

&process_commands_nowrap_in_tex (<<_RAW_ARG_NOWRAP_CMDS_);
#begingroup
#endgroup
#bgroup
#egroup
errorstopmode
nonstopmode
scrollmode
batchmode
psfigurepath # {}
pssilent
psdraft
psfull
thinlines
thicklines
linethickness # {}
hyphenation # {}
hyphenchar # \\ # &get_numeric_argument
hyphenpenalty # &get_numeric_argument
#let # \\ # <<\\(\\W|\\w+)>>
newedboolean # {}
newedcommand # {} # [] # [] # {}
newedcounter # {} # []
newedenvironment # {} # [] # [] # {} # {}
newedtheorem # {} # [] # {} # []
#providedcommand # {} # [] # [] # {}
#renewedcommand # {} # [] # [] # {}
#renewedenvironment # {} # [] # [] # {} # {}
DeclareMathAlphabet # {} # {} # {} # {} # {}
SetMathAlphabet # {} # {} # {} # {} # {} # {}
DeclareMathSizes # {} # {} # {} # {}
DeclareMathVersion # {}
DeclareSymbolFont # {} # {} # {} # {} # {}
DeclareSymbolFontAlphabet # {} # {}
DeclareMathSymbol # {} # {} # {} # {}
SetSymbolFont # {} # {} # {} # {} # {} # {}
DeclareFontShape # {} # {} # {} # {} # {} # {}
DeclareFontFamily # {} # {} # {}
DeclareFontEncoding # {} # {} # {}
DeclareFontSubstitution # {} # {} # {} # {}
mathversion # {}
#newfont # {} # {}
#normalfont
#rmfamily
#mdseries
newlength # {}
setlength # {} # {}
addtolength # {} # {}
settowidth # {}# {}
settoheight # {} # {}
settodepth # {} # {}
newsavebox # {}
savebox # {} # [] # {}
sbox # {} # {}
setbox # {}
TagsOnLeft  # \$EQN_TAGS = \"L\" if \$PREAMBLE;
TagsOnRight # \$EQN_TAGS = \"R\" if \$PREAMBLE;
_RAW_ARG_NOWRAP_CMDS_


&process_commands_wrap_deferred (<<_RAW_ARG_DEFERRED_CMDS_);
alph # {}
Alph # {}
arabic # {}
author # [] # {}
boldmath
unboldmath
captionstar # [] # {}
caption # [] # {}
#endsegment # []
#segment # [] # {} # {} # {}
fnsymbol # {}
footnote # [] # {}
footnotemark # []
footnotetext # [] # {}
#thanks # {}
roman # {}
Roman # {}
#mbox # {}
parbox # [] # [] # [] # {} # {}
#selectlanguage # [] # {}
setcounter # {} # {}
addtocounter # {} # {}
stepcounter # {}
refstepcounter # {}
value # {}
par
hrule # &ignore_numeric_argument
linebreak # []
pagebreak # []
newfont # {} # {}
smallskip
medskip
bigskip
centering
raggedright
raggedleft
itshape
#textit # {}
upshape
slshape
#scshape
rmfamily
sffamily
ttfamily
mdseries
bfseries
#textbf # {}
em
normalfont
it
rm
sl
bf
tt
sf
Tiny
tiny
scriptsize
footnotesize
small
Small
SMALL
normalsize
large
Large
LARGE
huge
Huge
lowercase # {}
uppercase # {}
MakeLowercase # {}
MakeUppercase # {}
htmlinfo # []
htmlinfostar # []
tableofchildlinks # []
tableofchildlinksstar # []
tableofcontents
listoffigures
listoftables
thepart
thepage
thechapter
thesection
thesubsection
thesubsubsection
theparagraph
thesubparagraph
theequation
htmltracenv # {}
HTMLsetenv # [] # {} # {}
#newedboolean # {}
#newedcounter # {} # []
#newedcommand # {} # [] # [] # {}
#newedtheorem # {} # [] # {} # []
#newedenvironment # {} # [] # [] # {} # {}
providedcommand # {} # [] # [] # {}
renewedcommand # {} # [] # [] # {}
renewedenvironment # {} # [] # [] # {} # {}
url # {}
htmlurl # {}
latextohtml
TeX
LaTeX
LaTeXe
LaTeXiii
Xy
MF
AmS
AmSTeX
textcircled # {}
_RAW_ARG_DEFERRED_CMDS_


#rrm
# implement the XBit-Hack for Apache servers, to handle
# Server-Side Includes (SSIs) with .html filename extension
#
sub check_htaccess {
    my $access_file = '.htaccess';
    my $has_access = '';
    local $_;
    print "\nChecking for .htaccess  file";
    if (-f $access_file) {
	print STDOUT " ... found";
	open(HTACCESS, "<$access_file");
	while (<HTACCESS>) {
	    if (/^\s*XBitHack\s*on\s*$/) {
		print STDOUT " with XBitHack on";
		$has_access =1; last;
	    };
	}
	print STDOUT "\n";
	close HTACCESS;
	return() if $has_access;
	open (HTACCESS, ">>$access_file");
	&write_warnings("appended to .htaccess in $DESTDIR");
    } else {
	open (HTACCESS, ">$access_file");
	chmod 0644, $access_file;
	&write_warnings("created .htaccess file in $DESTDIR");
    }
    print HTACCESS "\nXBitHack on\n";
    close HTACCESS;
}

# This maps the HTML mnemonic names for the ISO-LATIN-1 character references
# to their numeric values. When converting latex specials characters to
# ISO-LATIN-1 equivalents I use the numeric values because this makes any
# conversion back to latex (using revert_raw_tex) more reliable (in case
# the text contains "&mnemonic_name"). Errors may occur if an environment
# passed to latex (e.g. a table) contains the numeric values of character
# references.

# RRM: removed this portion; load from  latin1.pl instead
#&do_require_extension('latin1');

sub make_isolatin1_rx {
    local($list) = &escape_rx_chars(join($CD,(values %iso_8859_1_character_map_inv)));
    $list =~ s/$CD/|/g;
    $isolatin1_rx = "($list)";
}


    ################### Frequently used regular expressions ###################
    # $1 : preamble

    $preamble_rx = "(^[\\s\\S]*)(\\\\begin\\s*$O\\d+$C\\s*document\\s*$O\\d+$C|\\\\startdocument)";

    # \d (number) should sometimes also be a delimiter but this causes
    # problems with command names  that are allowed to contain numbers (eg tex2html)
    # \d is a delimiter with commands which take numeric arguments?
    # JCL: I can't see that. \tex2html is also no valid LaTeX (or TeX).
    # It is parsed \tex 2html, and \tex may take 2html as argument, but this
    # is invalid LaTeX. \d must be treated as delimiter.

# JCL(jcl-del) - Characters to be treated as letters, everything else
# is a delimiter.
    # internal LaTeX command separator, shouldn't be equal to $;
    $CD = "\001";
    &make_cmd_spc_rx; # determines space to follow a letter command
#old    $delimiters = '\'\\s[\\]\\\\<>(=).,#;:~\/!-';
    $letters = 'a-zA-Z';
    $delimiter_rx = "([^$letters])";
#

    # liberalized environment names (white space, optional arg, interpunctuation signs etc.)
    # $1 : br_id, $2 : <environment>
    $begin_env_rx="(\\\\protect)?\\\\begin\\s*(\\[([^\\]]*)])?$O(\\d+)$C\\s*([^'[\\]\\\\#~]+)\\s*$O\\4$C";
    $begin_env_pr_rx="(\\\\protect)?\\\\begin\\s*(\\[([^\\]]*)])?$OP(\\d+)$CP\\s*([^'[\\]\\\\#~]+)\\s*$OP\\4$CP";

    $mbox_rx = "\\\\mbox\\s*";

    $match_br_rx = "\\s*$O\\d+$C\\s*";

    $opt_arg_rx = "\\s*\\[([^\\]]*)\\]\\s*";	# Cannot handle nested []s!
    $optional_arg_rx = "^\\s*\\[([^]]*)\\]";	# Cannot handle nested []s!

    $block_close_rx = "^<\\/(DIV|P|BLOCKQUOTE)>\$";
    $all_close_rx = "^<\\/(BODY|PRE|OL|UL|DL|FORM|ADDRESS)>\$";

    # Matches a pair of matching brackets
    # $1 : br_id
    # $2 : contents
    $next_pair_rx = "^[\\s%]*$O(\\d+)$C([\\s\\S]*)$O\\1$C($comment_mark\\d*\\n?)?";

    # will comments be a problem after these ???
    $any_next_pair_rx = "$O(\\d+)$C([\\s\\S]*)$O\\1$C";
    $any_next_pair_rx4 = "$O(\\d+)$C([\\s\\S]*)$O\\4$C";
    $any_next_pair_pr_rx4 = "$OP(\\d+)$CP([\\s\\S]*)$OP\\4$CP";
    $any_next_pair_rx5 = "$O(\\d+)$C([\\s\\S]*)$O\\5$C";
    $any_next_pair_rx6 = "$O(\\d+)$C([\\s\\S]*)$O\\6$C";

    # used for labels in {enumerate} environments
    $standard_label_rx = 
	"\\s*[[]\\s*((($any_next_pair_rx4)|([[][^]]*[]])|[^]])*)[]]";
    $enum_label_rx = "^((({[^{}]*})|([^{}]))*)([aAiI1])(.*)";
    $enum_level = 0;	# level for enumerate (1-4, i-iv)


    # Matches the \ensuremath command
    $enspair = "\\\\ensuremath\\s*" . $any_next_pair_rx;
#    $enspair = "\\\\ensuremath\\s*$O(\\d+)$C([\\s\\S]*[\\\\\$&]+[\\s\\S]*)$O\\1$C";

    # Matches math comments, from  math.pl
    $math_verbatim_rx = "$verbatim_mark#math(\\d+)#";
    $mathend_verbatim_rx = "$verbatim_mark#mathend([^#]*)#";

    # Matches math array environments
    $array_env_rx = "array|cases|\\w*matrix";

    # initially empty; has a value in HTML 3.2 and 4.0
    $math_class = '' unless ($math_class);
    $eqno_class = '' unless ($eqno_class);

    # Matches to end-of-line and subsequent spaces
    $EOL = "[ \\t]*\\n?";

    # Matches wrapped \par command
    $par_rx = "\\n?\\\\begin(($O|$OP)\\d+($C|$CP))tex2html_deferred\\1\\\\par\\s\*"
        . "\\\\end(($O|$OP)\\d+($C|$CP))tex2html_deferred\\4\\n?";

    # $1 : br_id
    $begin_cmd_rx = "$O(\\d+)$C";

    # $1 : image filename prefix
    $img_rx = "(\\w*T?img\\d+)";

    # $1 : largest argument number
    $tex_def_arg_rx = "^[#0-9]*#([0-9])($O|$OP)";

    #   only some non-alphanumerics are allowed in labels,  Why?
    $label_rx = "[^\\w\.\\\-\\\+\\\:]";

#JCL(jcl-del) - new face, see also &do_cmd_makeatletter et.al.
#    $cmd_delims = q|-#,.~/\'`^"=\$%&_{}@|; # Commands which are also delimiters!
#    $single_cmd_atletter_rx = "\\\\([a-zA-Z\\\@]+\\*?|[$cmd_delims]|\\\\)";
#    $single_cmd_atother_rx = "\\\\([a-zA-Z]+\\*?|[$cmd_delims]|\\\\)";
    # $1 : declaration or command or newline (\\)
    &make_single_cmd_rx;
#

    # $1 : description in a list environment
    $item_description_rx =
#	"\\\\item\\s*[[]\\s*((($any_next_pair_rx4)|([[][^]]*[]])|[^]])*)[]]";
	"\\\\item\\s*[[]\\s*((($any_next_pair_pr_rx4)|([[][^]]*[]])|[^]])*)[]]";

    $fontchange_rx = 'rm|em|it|sl|sf|tt|sc|upshape|normalfont';
    $fontweight_rx = 'bf|mdseries|normalfont';
    $colorchange_rx = "(text)?color\\s*(\#\\w{6})?";
    $sizechange_rx = 'tiny|Tiny|scriptsize|footnotesize|small|Small|SMALL' .
	'|normalsize|large|Large|LARGE|huge|Huge';

#    $image_switch_rx = "makeimage";
    $image_switch_rx = "makeimage|scshape|sc";
    $env_switch_rx = "writetolatex";
    $raw_arg_cmds{'font'} = 1;

    # Matches the \caption command
    # $1 : br_id
    # $2 : contents
     $caption_suffixes = "lof|lot";
#    $caption_rx = "\\\\caption\\s*([[]\\s*((($any_next_pair_rx5)|([[][^]]*[]])|[^]])*)[]])?$O(\\d+)$C([\\s\\S]*)$O\\8$C$EOL";

    $caption_rx = "\\\\(top|bottom|table)?caption\\s*\\\*?\\s*([[]\\s*((($any_next_pair_rx6)|([[][^]]*[]])|[^]])*)[]])?$O(\\d+)$C([\\s\\S]*)$O\\9$C$EOL";
    $caption_width_rx = "\\\\setlength\\s*(($O|$OP)\\d+($C|$CP))\\\\captionwidth\\1\\s*(($O|$OP)\\d+($C|$CP))([^>]*)\\4";

    # Matches the \htmlimage command
    # $1 : br_id
    # $2 : contents
    $htmlimage_rx = "\\\\htmlimage\\s*$O(\\d+)$C([\\s\\S]*)$O\\1$C$EOL";
    $htmlimage_pr_rx = "\\\\htmlimage\\s*$OP(\\d+)$CP([\\s\\S]*)$OP\\1$CP$EOL";

    # Matches the \htmlborder command
    # $1 : optional argument...
    # $2 : ...contents  i.e. extra attributes
    # $3 : br_id
    # $4 : contents i.e. width
    $htmlborder_rx = "\\\\htmlborder\\s*(\\[([^]]*)\\])?\\s*$O(\\d+)$C(\\d*)$O\\3$C$EOL";
    $htmlborder_pr_rx = "\\\\htmlborder\\s*(\\[([^]]*)\\])?\\s*$OP(\\d+)$CP(\\d*)$OP\\3$CP$EOL";

    # Matches a pair of matching brackets
    # USING PROCESSED DELIMITERS;
    # (the delimiters are processed during command translation)
    # $1 : br_id
    # $2 : contents
#    $next_pair_pr_rx = "^[\\s%]*$OP(\\d+)$CP([\\s\\S]*)$OP\\1$CP";
    $next_pair_pr_rx = "^[\\s%]*$OP(\\d+)$CP([\\s\\S]*)$OP\\1$CP($comment_mark\\d*\\n?)?";
    $any_next_pair_pr_rx = "$OP(\\d+)$CP([\\s\\S]*)$OP\\1$CP($comment_mark\\d*\\n?)?";
    $next_token_rx = "^[\\s%]*(\\\\[A-Za-z]+|\\\\[^a-zA-Z]|.)";

    $HTTP_start = 'http:';

    # This will be used to recognise escaped special characters as such
    # and not as commands
    $latex_specials_rx = '[\$]|&|%|#|{|}|_';
    $html_escape_chars = '<>&';

    # This is used in sub revert_to_raw_tex before handing text to be processed
    # by latex.
    $html_specials_inv_rx = join("|", keys %html_specials_inv);

    # These are used for direct replacements in/from  ALT=... strings
    %html_special_entities = ('<','lt','>','gt','"','quot','&','amp');
    %html_spec_entities_inv = ('lt','<','gt','>','quot','"','amp','&');

    # This is also used in sub revert_to_raw_tex
    $character_entity_rx = '(&#(\d+);)';
    $named_entity_rx = '&(\w+);';

    #commands for altering theorem-styles
    $theorem_cmd_rx = 'theorem(style|(header|body)font)';


    # Matches a \begin or \end {tex2html_wrap}. Also used by revert_to_raw_tex
    $tex2html_wrap_rx = '\\\\(begin|end)\\s*\{\\s*(tex2html_(wrap|nowrap|deferred|nomath|preform|\\w*_inline)[_a-z]*|makeimage)\\s*\}'."($EOL)";
    $tex2html_deferred_rx = '\\\\(begin|end)(<<\\d+>>)tex2html_deferred\\2';
    $tex2html_deferred_rx2 = '\\\\(begin|end)(<<\\d+>>)tex2html_deferred\\4';
    $tex2html_envs_rx = "\\\\(begin|end)\\s*(($O|$OP)\\d+($C|$CP))\\s*(tex2html_(wrap|nowrap|deferred|nomath|preform|\w+_inline)[_a-z]*||makeimage)\\s*\\2";

    # The first empty parenthese pair is for non-letter commands.
    # $2: meta command, $4: delimiter (may be empty)  ignore the *-version distinction
#    $meta_cmd_rx = "()\\\\(providecommand|renewcommand|renewenvironment|newcommand|newenvironment|newtheorem|newcounter|newboolean|newif|let)(([^$letters$cmd_spc])|$cmd_spcs_rx)";
    $meta_cmd_rx = "()\\\\(providecommand|renewcommand|renewenvironment|newcommand|newenvironment|newtheorem|newcounter|newboolean|newif|DeclareRobustCommand|DeclareMathOperator\\*?)\\\*?(([^$letters$cmd_spc])|$cmd_spcs_rx)";

    &make_counters_rx;

    # Matches a label command and its argument
    $labels_rx = "\\\\label\\s*$O(\\d+)$C([\\s\\S]*)$O\\1$C$EOL";
    $labels_rx8 = "\\\\label\\s*$O(\\d+)$C([\\s\\S]*)$O\\8$C$EOL";

    # Matches environments that should not be touched during the translation
#   $verbatim_env_rx = "\\s*{(verbatim|rawhtml|LVerbatim)[*]?}";
    $verbatim_env_rx = "\\s*(\\w*[Vv]erbatim|rawhtml|imagesonly|tex2html_code)[*]?";
    $image_env_rx = "\\s*(picture|xy|diagram)[*]?";
    $keepcomments_rx = "\\s*(picture|makeimage|xy|diagram)[*]?";

    # names of different math environment types
    $display_env_rx = "displaymath|makeimage|eqnarray|equation";
    $inline_env_rx = "inline|indisplay|entity|xy|diagram";
    $sub_array_env_rx = "array|(small|\\w)\?matrix|tabular|cases";

    # Matches environments needing pre-processing for images
    $pre_processor_env_rx = "\\\\(begin|end)\\s*(($O|$OP|\{)\\d+($C|$CP|\}))pre_(\\w+)\\2";

    # Matches icon markers
    $icon_mark_rx = "<tex2html_(" . join("|", keys %icons) . ")>";

    $start_time = time;
    print STDOUT join(" ", "Starting at", $start_time, "seconds\n")
        if ($TIMING||$DEBUG||($VERBOSITY>2));

}	# end of &initialise

# Frequently used regular expressions with arguments
sub make_end_env_rx {
    local($env) = @_;
    $env = &escape_rx_chars($env);
    "\\\\end\\s*$O(\\d+)$C\\s*$env\\s*$O\\1$C".$EOL;
}

sub make_begin_end_env_rx {
    local($env) = @_;
    $env = &escape_rx_chars($env);
    "\\\\(begin|end)\\s*$O(\\d+)$C\\s*$env\\s*$O\\3$C(\\s*\$)?";
}

sub make_end_cmd_rx {
    local($br_id) = @_;
    "$O$br_id$C";
}

#JCL(jcl-del) - see also &tokenize.
# Arrange commands into a regexp for tokenisation.
# Any letter command will gobble spaces, but avoids to match
# on ensuing letters (\foo won't match on \foox).
# Any non-letter command retains spaces and matches always
# by itself (\| matches \|... regardless of ...).
#
# This all is a huge kludge. The commands names should stay fix,
# regardless of changing catcodes. If we have \makeatletter,
# and LaTeX2HTML marks \@foo, then \@foo will be expanded
# properly before \makeatother, but does weird things on \@foo
# after \makeatother (\@foo in LaTeX is then \@ and foo, which
# isn't recognized as such).
# The reason is that the text to match the command \@foo
# in LaTeX mustn't be \@foo at all, because any text in LaTeX
# is also attributed with the category codes.
#
# But at least we have proper parsing of letter and non-letter
# commands as long as catcoding won't upset LaTeX2HTML too much.
#
sub make_new_cmd_rx {
    return("") if $#_ < 0; # empty regexp if list is empty!

    # We have a subtle treatment of ambivalent commands like
    # \@foo in situations depicted above!
    # Get every command that contains no letters ...
    local($nonlettercmds) =
	&escape_rx_chars(join($CD, grep(!/[$letters]/,@_)));
    # and every command that contains a letter
    local($lettercmds) =
	&escape_rx_chars(join($CD, grep(/[$letters]/,@_)));

    if (%renew_command) {
	local($renew);
	foreach $renew (keys %renew_command) {
	    $lettercmds =~ s/(^|$CD)$renew//; }
        $lettercmds =~ s/^$CD$//;
    }

    # replace the temporary $CD delimiter (this enables eg. \| command)
    $nonlettercmds =~ s/$CD/|/g;
    $lettercmds =~ s/$CD/|/g;

    # In case we have no non-letter commands, insert empty parentheses
    # to align match strings.
    #
    $nonlettercmds =~ s/^\||\|$//g;
    $lettercmds =~ s/^\||\|$//g;
    local($rx) = (length($nonlettercmds) ? "\\\\($nonlettercmds)" : "");
    if (length($lettercmds)) {
	$rx .= ( length($rx) ? "|" : "()" );
	$rx .= "\\\\($lettercmds)(([^$letters$cmd_spc])|$cmd_spcs_rx|\$)";
    }
    # $1: non-letter cmd, $2: letter cmd, $4: delimiter
    # Eg. \\(\@|...|\+)|\\(abc|...|xyz)(([^a-zA-Z \t])|[ \t]+)
    # $1 and $2 are guaranteed to alternate, $4 may be empty.
    $rx;
}

# Build a simple regexp to use after tokenisation for
# faster translation.
sub make_new_cmd_no_delim_rx {
    return("") if $#_ < 0; # empty regexp if list is empty!
    # Get every command that contains no letters ...
    local($_) = &escape_rx_chars(join($CD, @_));
    s/$CD/|/g;

    join('',"\\\\(",$_,")");
}


#JCL(jcl-del) - new face: w/o arg (was 'begin' only), escapes env names
sub make_new_env_rx {
    local($envs) = &escape_rx_chars(join($CD, keys %new_environment));
    $envs =~ s/$CD/|/g;
    length($envs) ? "\\\\begin\\s*$O(\\d+)$C\\s*($envs)\\s*$O\\1$C\\s*" : "";
}

sub make_new_end_env_rx {
    local($envs) = &escape_rx_chars(join($CD, keys %new_environment));
    $envs =~ s/$CD/|/g;
    length($envs) ? "\\\\end\\s*$O(\\d+)$C\\s*($envs)\\s*$O\\1$C\\s*" : "";
}

#JCL(jcl-del) - $delimiter_rx -> ^$letters
# don't care for $cmd_spc_rx; space after sectioning commands
# is unlikely and I don't want to try too much new things
#
sub make_sections_rx {
    local($section_alts) = &get_current_sections;
    # $section_alts includes the *-forms of sectioning commands
    $sections_rx = "()\\\\($section_alts)(([^$letters$cmd_spc])|$cmd_spcs_rx|\$)";
#    $sections_rx = "()\\\\($section_alts)([^$letters])";
}

sub make_order_sensitive_rx {
    local(@theorem_alts, $theorem_alts);
    @theorem_alts = ($preamble =~ /\\newtheorem\s*{([^\s}]+)}/og);
    $theorem_alts = join('|',@theorem_alts);
#
#  HWS: Added kludge to require counters to be more than 2 characters long
#	in order to be flagged as order-sensitive.  This will permit equations
#	with \theta to remain order-insensitive.  Also permit \alpha and
#	the eqnarray* environment to remain order-insensitive.
#
    $order_sensitive_rx =
#        "(equation|eqnarray[^*]|\\\\caption|\\\\ref|\\\\the[a-z]{2,2}[a-z]|\\\\stepcounter" .
        "(\\\\caption|\\\\ref|\\\\the[a-z]{2,2}[a-z]|\\\\stepcounter" .
        "|\\\\arabic|\\\\roman|\\\\Roman|\\\\alph[^a]|\\\\Alph|\\\\fnsymbol)";
    $order_sensitive_rx =~ s/\)/|$theorem_alts)/ if $theorem_alts;
}

sub make_language_rx {
    local($language_alts) = join("|", keys %language_translations);
#    $setlanguage_rx = "\\\\se(lec)?tlanguage\\s*{\\\\?($language_alts)}";
    $setlanguage_rx = "\\\\setlanguage\\s*{\\\\?($language_alts)}";
    $language_rx = "\\\\($language_alts)TeX";
    $case_change_rx = "(\\\\(expandafter|noexpand)\s*)?\\\\((Make)?([Uu]pp|[Ll]ow)ercase)\s*";
}

sub addto_languages {
    local($lang) = @_;
    local($trans) = "main'".$lang.'_translation';
    if (defined &$trans) {
	$language_translations {$lang} = $lang.'_translation';
    }
}

# JCL(jcl-del) - new rexexp type
sub make_raw_arg_cmd_rx {
    # $1 or $2 : commands to be processed in latex (with arguments untouched)
    # $4 : delimiter
    $raw_arg_cmd_rx = &make_new_cmd_rx(keys %raw_arg_cmds);
    $raw_arg_cmd_rx;
}

# There are probably more.
# Interferences not checked out yet, thus in makeat... only.
sub make_letter_sensitive_rx {
    $delimiter_rx = "([^$letters])";
    &make_sections_rx;
    &make_single_cmd_rx;
    &make_counters_rx;
}

#JCL(jcl-del) - this could eat one optional newline, too.
# But this might result in large lines... anyway, it *should* be
# handled. A possible solution would be to convert adjacent newlines
# into \par's in preprocessing.
sub make_cmd_spc_rx {
    $cmd_spc = " \\t";
    $cmd_spc_rx = "[ \\t]*"; # zero or more
    $cmd_spcs_rx = "[ \\t]+"; # one or more
}

sub make_single_cmd_rx {
    $single_cmd_rx = "\\\\([^$letters])|\\\\([$letters]+\\*?)(([^$letters$cmd_spc])|$cmd_spcs_rx|\n|\$)";
}

sub make_counters_rx {
    # Matches counter commands - these are caught early and are appended to the
    # file that is passed to latex.
#JCL(jcl-del) - $delimiter_rx -> ^$letters
    $counters_rx = "()\\\\(newcounter|addtocounter|setcounter|refstepcounter|stepcounter|arabic|roman|Roman|alph|Alph|fnsymbol)(([^$letters$cmd_spc])|$cmd_spcs_rx|\$)";
}


# Creates an anchor for its argument and saves the information in
# the array %index;
# In the index the word will use the beginning of the title of
# the current section (instead of the usual pagenumber).
# The argument to the \index command is IGNORED (as in latex)
sub make_index_entry { &make_real_index_entry(@_) }
sub make_real_index_entry {
    local($br_id,$str) = @_;
    local($this_file) = $CURRENT_FILE;
    $TITLE = $saved_title if (($saved_title)&&(!($TITLE)||($TITLE eq $default_title)));
    # Save the reference
    $str = "$str###" . ++$global{'max_id'}; # Make unique
    $index{$str} .= &make_half_href($this_file."#$br_id");
    "<A NAME=\"$br_id\">$anchor_invisible_mark<\/A>";
}

sub image_message { # clean
    print <<"EOF";

To resolve the image conversion problems please consult
the "Troubleshooting" section of your local User Manual
or read it online at
   http://www-texdev.ics.mq.edu.au/l2h/docs/manual/

EOF
}

sub image_cache_message { # clean
   print <<"EOF";

If you are having problems displaying the correct images with Mosaic,
try selecting "Flush Image Cache" from "Options" in the menu-bar
and then reload the HTML file.
EOF
}

__DATA__

# start of POD documentation

=head1 NAME

latex2html - Translate LaTeX files to HTML (HyperText Markup Language)

=head1 SYNOPSIS

B<latex2html> S<[ B<-help> | B<-h> ]> S<[ B<-version> | B<-V> ]>

B<latex2html> S<[ B<-split> I<num> ]>
S<[ B<-link> I<num> ]>
S<[ B<-toc_depth> I<num> ]>
S<[ B<->(B<no>)B<toc_stars> ]>
S<[ B<->(B<no>)B<short_extn> ]>
S<[ B<-iso_language> I<lang> ]>
S<[ B<->(B<no>)B<validate> ]>
S<[ B<->(B<no>)B<latex> ]>
S<[ B<->(B<no>)B<djgpp> ]>
S<[ B<->(B<no>)B<fork> ]>
S<[ B<->(B<no>)B<external_images> ]>
S<[ B<->(B<no>)B<ascii_mode> ]>
S<[ B<->(B<no>)B<lcase_tags> ]>
S<[ B<->(B<no>)B<ps_images> ]>
S<[ B<-font_size> I<size> ]>
S<[ B<->(B<no>)B<tex_defs> ]>
S<[ B<->(B<no>)B<navigation> ]>
S<[ B<->(B<no>)B<top_navigation> ]>
S<[ B<->(B<no>)B<buttom_navigation> ]>
S<[ B<->(B<no>)B<auto_navigation> ]>
S<[ B<->(B<no>)B<index_in_navigation> ]>
S<[ B<->(B<no>)B<contents_in_navigation> ]>
S<[ B<->(B<no>)B<next_page_in_navigation> ]>
S<[ B<->(B<no>)B<previous_page_in_navigation> ]>
S<[ B<->(B<no>)B<footnode> ]>
S<[ B<->(B<no>)B<numbered_footnotes> ]>
S<[ B<-prefix> I<output_filename_prefix> ]>
S<[ B<->(B<no>)B<auto_prefix> ]>
S<[ B<-long_titles> I<num> ]>
S<[ B<->(B<no>)B<custom_titles> ]>
S<[ B<-title>|B<-t> I<top_page_title> ]>
S<[ B<->(B<no>)B<rooted> ]>
S<[ B<-rootdir> I<output_directory> ]>
S<[ B<-dir> I<output_directory> ]>
S<[ B<-mkdir> ]>
S<[ B<-address> I<author_address> | B<-noaddress> ]>
S<[ B<->(B<no>)B<subdir> ]>
S<[ B<-info> I<0> | I<1> | I<string> ]>
S<[ B<->(B<no>)B<auto_link> ]>
S<[ B<-reuse> I<num> | B<-noreuse> ]>
S<[ B<->(B<no>)B<antialias_text> ]>
S<[ B<->(B<no>)B<antialias> ]>
S<[ B<->(B<no>)B<transparent> ]>
S<[ B<->(B<no>)B<white> ]>
S<[ B<->(B<no>)B<discard> ]>
S<[ B<-image_type> I<type> ]>
S<[ B<->(B<no>)B<images> ]>
S<[ B<-accent_images> I<type> | B<-noaccent_images> ]>
S<[ B<-style> I<style> ]>
S<[ B<->(B<no>)B<parbox_images> ]>
S<[ B<->(B<no>)B<math> ]>
S<[ B<->(B<no>)B<math_parsing> ]>
S<[ B<->(B<no>)B<latin> ]>
S<[ B<->(B<no>)B<entities> ]>
S<[ B<->(B<no>)B<local_icons> ]>
S<[ B<->(B<no>)B<scalable_fonts> ]>
S<[ B<->(B<no>)B<images_only> ]>
S<[ B<->(B<no>)B<show_section_numbers> ]>
S<[ B<->(B<no>)B<show_init> ]>
S<[ B<-init_file> I<Perl_file> ]>
S<[ B<-up_url> I<up_URL> ]>
S<[ B<-up_title> I<up_title> ]>
S<[ B<-down_url> I<down_URL> ]>
S<[ B<-down_title> I<down_title> ]>
S<[ B<-prev_url> I<prev_URL> ]>
S<[ B<-prev_title> I<prev_title> ]>
S<[ B<-index> I<index_URL> ]>
S<[ B<-biblio> I<biblio_URL> ]>
S<[ B<-contents> I<toc_URL> ]>
S<[ B<-external_file> I<external_aux_file> ]>
S<[ B<->(B<no>)B<short_index> ]>
S<[ B<->(B<no>)B<unsegment> ]>
S<[ B<->(B<no>)B<debug> ]>
S<[ B<-tmp> I<path> ]>
S<[ B<->(B<no>)B<ldump> ]>
S<[ B<->(B<no>)B<timing> ]>
S<[ B<-verbosity> I<num> ]>
S<[ B<-html_version> I<num> ]>
S<[ B<->(B<no>)B<strict> ]>
I<file.tex> S<[ I<file2.tex> ... ]>

=head1 DESCRIPTION

I<LaTeX2HTML> is a Perl program that translates LaTeX source files into
HTML. For each source file given as an argument the translator will create
a directory containing the corresponding HTML files.

=head1 OPTIONS

Many options can be specified in a true/false manner. This is indicated by
I<(no)>, e.g. to enable passing unknown environments to LaTeX, say "-latex",
to disable the feature say "-nolatex" or "-no_latex" (portability mode).

=over 4

=item B<-help> | B<-h>

Print this online manual and exit.

=item B<-version> | B<-V>

Print the LaTeX2HTML release and version information and exit.

=item B<-split> I<num>

Stop making separate files at this depth (say "-split 0" for one huge HTML
file).

=item B<-link> I<num>

Stop showing child nodes at this depth.

=item B<-toc_depth> I<num>

MISSING_DESCRIPTION

=item B<->(B<no>)B<toc_stars>

MISSING_DESCRIPTION

=item B<->(B<no>)B<short_extn>

If this is set all HTML file will have extension C<.htm> instead of
C<.html>. This is helpful when shipping the document to PC systems.

=item B<-iso_language> I<lang>

MISSING_DESCRIPTION

=item B<->(B<no>)B<validate>

When this is set true, the HTML validator specified in F<l2hconf.pm>
will run.

=item B<->(B<no>)B<latex>

Pass unknown environments to LaTeX. This is the default.

=item B<->(B<no>)B<djgpp>

Specify this switch if you are running DJGPP on DOS and need to avoid
running out of filehandles.

=item B<->(B<no>)B<fork>

Enable/disable forking. The default is reasonable for this platform.

=item B<->(B<no>)B<external_images>

If set, leave the images outside the document.

=item B<->(B<no>)B<ascii_mode>

This is different from B<-noimages>.
If this is set, B<LaTeX2HTML> will show textual tags rather than
images, both in navigation panel and text (Eg. C<[Up]> instead the up
icon).
You could use this feature to create simple text from your
document, eg. with 'Save as... Text' from B<Netscape> or with
B<lynx -dump>.

=item B<->(B<no>)B<lcase_tags>

writes out HTML tag names using lowercase letters, rather than uppercase.

=item B<->(B<no>)B<ps_images>

If set, use links to external postscript images rather than inlined bitmaps.

=item B<-font_size> I<size>

To set the point size of LaTeX-generated GIF files, specify the desired
value (i.e., C<10pt>, C<11pt>, C<12pt>, etc.).
The default is to use the point size of the original LaTeX document.
This value will be magnified by I<$FIGURE_SCALE_FACTOR> and
I<$MATH_SCALE_FACTOR> defined in F<l2hconf.pm>.

=item B<->(B<no>)B<tex_defs>

Enable interpretation of raw TeX commands (default).
Note: There are many variations of C<\def> that B<LaTeX2HTML> cannot process
correctly!

=item B<->(B<no>)B<navigation>

Put a navigation panel at the top of each page (default).

=item B<->(B<no>)B<top_navigation>

Enables navigation links at the top of each page (default).

=item B<->(B<no>)B<buttom_navigation>

Enables navigation links at the buttom of each page.

=item B<->(B<no>)B<auto_navigation>

Put navigation links at the top of each page. If the page exceeds
I<$WORDS_IN_PAGE> number of words then put one at the bottom of the page.

=item B<->(B<no>)B<index_in_navigation>

Put a link to the index page in the navigation panel.

=item B<->(B<no>)B<contents_in_navigation>

Put a link to the table of contents in the navigation panel.

=item B<->(B<no>)B<next_page_in_navigation>

Put a link to the next logical page in the navigation panel.

=item B<->(B<no>)B<previous_page_in_navigation>

Put a link to the previous logical page in the navigation panel.

=item B<->(B<no>)B<footnode>

Puts all footnotes onto a separate HTML page, called F<footnode.html>,
rather than at the bottom of the page where they are referenced.

=item B<->(B<no>)B<numbered_footnotes>

If true, you will get every footnote applied with a subsequent number, else
with a generic hyperlink icon.

=item B<-prefix> I<output_filename_prefix>

Set the output file prefix, prepended to all C<.html>, C<.gif> and C<.pl>
files. See also B<-auto_prefix>.

=item B<->(B<no>)B<auto_prefix>

Set this to automatically insert the equivalent of B<-prefix >C<basename->",
where "basename" is the base name of the file being translated.

=item B<-long_titles> I<num>

MISSING_DESCRIPTION

=item B<->(B<no>)B<custom_titles>

MISSING_DESCRIPTION

=item B<-title>|B<-t> I<top_page_title>

The title (displayed in the browser's title bar) the document shall get.

=item B<->(B<no>)B<rooted>

MISSING_DESCRIPTION

=item B<-rootdir> I<output_directory>

MISSING_DESCRIPTION

=item B<-dir> I<output_directory>

Put the result in this directory instead of parallel to the LaTeX file,
provided the directory exists, or B<-mkdir> is specified.

=item B<-mkdir>

Allow directory specified with B<-dir> to be created if necessary.

=item B<-address> I<author_address> | B<-noaddress>

Supply your own string if you don't like the default 
"E<lt>NameE<gt> E<lt>DateE<gt>". B<-noaddress> suppresses the
generation of an address footer.

=item B<->(B<no>)B<subdir>

If set (default), B<LaTeX2HTML> creates (or reuses) another file directory.
When false, the generated HTML files will be placed in the current
directory.

=item B<-info> I<0> | I<1> | I<string>

=item B<-noinfo>

If 0 is specified (or B<-noinfo> is used), do not generate an I<"About this
document..."> section. If 1 is specified (default), the standard info page is
generated. If a custom string is given, it is used as the info page.

=item B<->(B<no>)B<auto_link>

MISSING_DESCRIPTION

=item B<-reuse> I<num> | B<-noreuse>

If false, do not reuse or recycle identical images generated in previous
runs. If the html subdirectory already exists, start the interactive session.
If I<num> is nonzero, do recycle them and switch off the interactive session.
If 1, only recycle images generated from previous runs.
If 2, recycle images from the current and previous runs (default).

=item B<->(B<no>)B<antialias_text>

Use anti-aliasing in the generation of images of typeset material;
e.g. mathematics and text, e.g. in tables and {makeimage} environments.

=item B<->(B<no>)B<antialias>

Use anti-aliasing in the generation of images of figures. This usually
results in "sharper" bitmap images.

=item B<->(B<no>)B<transparent>

If this is set to false then any inlined images generated from "figure" 
environments will NOT be transparent.

=item B<->(B<no>)B<white>

This sets the background of generated images to white for anti-aliasing.

=item B<->(B<no>)B<discard>

if true, the PostScript file created for each generated image
is discarded immediately after its image has been rendered and saved in the
required graphics format. This can lead to significant savings in disk-space,
when there are a lot of images, since otherwise these files are not discarded 
until the end of all processing.

=item B<-image_type> I<type>

Specify the type of bitmap images to be generated. Depending on your setup,
B<LaTeX2HTML> can generate B<gif> or B<png> images. Note: Gif images have
certain legal restrictions, as their generation involves an algorithm
patented by Unisys.

=item B<->(B<no>)B<images>

If false, B<LaTeX2HTML> will not attempt to produce any inlined images.
The missing images can be generated "off-line" by restarting B<LaTeX2HTML>
with B<-images_only>.

=item B<-accent_images> I<type> | B<-noaccent_images>

MISSING_DESCRIPTION

=item B<-style> I<style>

MISSING_DESCRIPTION

=item B<->(B<no>)B<parbox_images>

MISSING_DESCRIPTION

=item B<->(B<no>)B<math>

By default the special MATH extensions are not used
since they do not conform with the HTML 3.2 standard.

=item B<->(B<no>)B<math_parsing>

MISSING_DESCRIPTION

=item B<->(B<no>)B<latin>

MISSING_DESCRIPTION

=item B<->(B<no>)B<entities>

MISSING_DESCRIPTION

=item B<->(B<no>)B<local_icons>

Set this if you want to copy the navigation icons to each document directory
so that the document directory is self-contained and can be dropped into
another server tree without further actions.

=item B<->(B<no>)B<scalable_fonts>

MISSING_DESCRIPTION

=item B<->(B<no>)B<images_only>

When true, B<LaTeX2HTML> will only try to convert the inlined images in the
file F<images.tex> which should have been generated automatically during
previous runs. This is very useful for correcting "bad LaTeX" in this file.

=item B<->(B<no>)B<show_section_numbers>

When this is set true, the section numbers are shown. The section numbers
should then match those that would have been produced by LaTeX.
The correct section numbers are obtained from the $FILE.aux file generated 
by LaTeX.
Hiding the section numbers encourages use of particular sections 
as standalone documents. In this case the cross reference to a section 
is shown using the default symbol rather than the section number.

=item B<->(B<no>)B<show_init>

MISSING_DESCRIPTION

=item B<-init_file> I<Perl_file>

MISSING_DESCRIPTION

=item B<-up_url> I<up_URL>, B<-up_title> I<up_title>

=item B<-down_url> I<down_URL>, B<-down_title> I<down_title>

=item B<-prev_url> I<prev_URL>, B<-prev_title> I<prev_title>

=item B<-index> I<index_URL>,

=item B<-contents> I<toc_URL>

=item B<-biblio> I<biblio_URL>

If both of the listed two options are set then the "Up" ("Previous" etc.)
button of the navigation panel in the first node/page of a converted
document will point to I<up_URL> etc. I<up_title> should be set
to some text which describes this external link.
Similarly you might use these options to link external documents
to your navigation panel.

=item B<-external_file> I<external_aux_file>

MISSING_DESCRIPTION

=item B<->(B<no>)B<short_index>

If this is set then B<makeidx.perl> will construct codified names
for the text of index references.

=item B<->(B<no>)B<unsegment>

Use this to translate a segmented document as if it were not
segmented.

=item B<->(B<no>)B<debug>

If this is set then intermediate files are left for later inspection and
a lot of diagnostic output is produced. This output may be useful when
searching for problems and/or submitting bug reports to the developers.
Temporary files include F<$$_images.tex> and F<$$_images.log> created during
image conversion. Caution: Intermediate files can be I<enormous>!

=item B<-tmp> I<path>

Path for temporary files. This should be a local, fast filesystem because it is heavily used during image generation. The default is set in F<l2hconf.pm>.

=item B<->(B<no>)B<ldump>

This will cause LaTeX2HTML to produce a LaTeX dump of images.tex which is read
in on subsequent runs and speeds up startup time of LaTeX on the images.tex
translation. This actually consumes additional time on the first run, but pays
off on subsequent runs. The dump file will need about 1 Meg of disk space.

=item B<->(B<no>)B<timing>

MISSING_DESCRIPTION

=item B<-verbosity> I<num>

The amount of message information printed to the screen during processing
by B<LaTeX2HTML> is controlled by this setting.
By increasing this value, more information is displayed.
Here is the type of extra information that is shown at each level:

  0   no extra information
  1   section types and titles
  2   environment
  3   command names
  4   links, labels and internal sectioning codes

=item B<-html_version> I<list>

Which HTML version should be generated. Currently available are:
C<2.0>, C<3.0>, C<3.2>, C<4.0>. Some additional options that may be
added are: C<math> (parse mathematics), C<i18n> (?), 
C<table> (generate tables), C<frame> (generate frames),
C<latin1>...C<latin9> (use ISO-Latin-x encoding),
C<unicode> (generate unicode characters). Separate the options with ',',
e.g. C<4.0,math,frame>.

=item B<->(B<no>)B<strict>

MISSING_DESCRIPTION

=back

=head1 FILES

=over 4

=item F<$LATEX2HTMLPLATDIR/l2hconf.pm>

This file holds the global defaults and configuration settings for
B<LaTeX2HTML>.

=item F<$HOME/.latex2html-init>

=item F<./.latex2html-init>

These files may contain settings that override the global defaults, just
like specifying command line switches.

=back

=head1 ENVIRONMENT

=over 4

=item LATEX2HTMLDIR

Path where LaTeX2HTML library files are found. On this installation
LATEX2HTMLDIR is F</usr/share/latex2html>

=item PERL5LIB

Set by the B<latex2html> program to find perl modules.

=item L2HCONFIG

An alternative configuration filename. The standard configuration file
is F<$LATEX2HTMLPLATDIR/l2hconf.pm>. You may specify a sole filename (searched
for in F<$LATEX2HTMLPLATDIR> (and F<$PERL5LIB>) or a complete path.

=item L2HINIT_NAME

The standard user-specific configuration filename is F<.latex2html-init>.
This environment variable will override this name.

=item HOME

Evaluated if the system does not know about "home" directories (like
DOS, WinXX, OS/2, ...) to determine the path to F<$L2HINIT_NAME>.

=item TEXE_DONT_INCLUDE, TEXE_DO_INCLUDE

Used internally for communication with B<texexpand>.

=item TEXINPUTS

Used to find TeX includes of all sorts.

=back

=head1 PROBLEMS

For information on various problems and remedies see the WWW online
documentation or the documents available in the distribution.
An online bug reporting form and various archives are available at
F<http://www.latex2html.org/>

There is a mailing list for discussing B<LaTeX2HTML>: C<latex2html@tug.org>

=head1 AUTHOR

Nikos Drakos,  Computer Based Learning Unit, University of Leeds
E<lt>nikos@cbl.leeds.ac.ukE<gt>. Several people have contributed
suggestions, ideas, solutions, support and encouragement.

The B<pstoimg> script was written by Marek Rouchal 
E<lt>marek@saftsack.fs.uni-bayreuth.deE<gt>
as a generalisation of the B<pstogif> utility to allow graphic formats
other than GIF to be created. Various options and enhancements have
been added by Ross Moore.
Some of the code is based upon the pstoppm.ps postscript program 
originally written by Phillip Conrad (Perfect Byte, Inc.)
and modified by L. Peter Deutsch (Aladdin Enterprises).

=head1 SEE ALSO

See the WWW online documentation or the F<$LATEX2HTMLDIR/doc/manual.ps>
file for more detailed information and examples.

L<pstoing>, L<texexpand>

=cut

