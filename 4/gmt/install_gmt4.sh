#!/bin/sh
#	$Id: install_gmt.sh 10118 2013-11-01 22:13:06Z pwessel $
#
#	Automatic installation of GMT4
#	Suitable for the Bourne shell (or compatible)
#
#	Paul Wessel
#	1-JULY-2018
#--------------------------------------------------------------------------------
# GLOBAL VARIABLES
VERSION=4.5.18
GSHHG=2.3.7
GMT_FTP_TEST=0
GMT_SIZE=38
GSHHG_SIZE=45
#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
#	FUNCTIONS
#--------------------------------------------------------------------------------
# Get the functionality of echo -n
#--------------------------------------------------------------------------------
if [ x`echo -n` = x ]; then	# echo -n works
	echon()
	{
		echo -n "$*" 
	}
elif [ x`echo -e` = x ]; then	# echo -e works
	echon()
	{
		echo -e "$*"'\c'
	}
else				# echo with escapes better work
	echon()
	{
		echo "$*"'\c'
	}
fi
# Question poser, return answer
#--------------------------------------------------------------------------------
get_answer()
{
# Arg1 is question
echon "==> $1: " >&2
read answer
echo $answer
}
#--------------------------------------------------------------------------------
# Question poser with default answer, return answer
#--------------------------------------------------------------------------------
get_def_answer()
{
# Arg1 is question, Argv2 is default answer
echon "==> $1 [$2]: " >&2
read answer
echo $answer $2 | awk '{print $1}'
}
check_for_bzip2()
{
if [ `bzip2 -h 2>&1 | wc -l` -lt 10 ]; then	# Dont have bzip2
	echo "ERROR: bzip2 not installed - exits" >&2
	exit
fi
}
#--------------------------------------------------------------------------------
# INTERACTIVE GMT4 PARAMETER REQUEST SESSION
#--------------------------------------------------------------------------------
prep_gmt()
{
#--------------------------------------------------------------------------------
cat << EOF > gmt_install.ftp_site
1. SOEST, U of Hawaii [GMT Home], Honolulu, Hawaii, USA
2. NOAA, Lab for Satellite Altimetry, College Park, Maryland, USA
3. IRIS, Incorporated Research Institutions for Seismology, Seattle, Washington, USA
4. IAG-USP, Dept of Geophysics, U. of Sao Paulo, BRAZIL
5. TENET, Tertiary Education & Research Networks of South Africa, SOUTH AFRICA
EOF

cat << EOF >&2
====>>>> Interactive installation of GMT4 <<<<====
		  
We first need a questions and answer session to determine how
and where GMT4 is to be installed.  Then, when all parameters
have been assembled, we will run the installation (unless you
chose -n when starting this script).

This script will install the latest version of GMT $VERSION.

EOF
GMT_version=$VERSION
N_EXAMPLES=30
topdir=`pwd`
os=`uname -s`
if [ "$os" = "Darwin" ]; then	# Set default paths for OSX
	if [ -d /sw/lib ]; then
		# fink
		LIBINC_DEF=/sw
	else
		# macports
		LIBINC_DEF=/opt/local
	fi
else
	LIBINC_DEF=/usr/local
fi
#--------------------------------------------------------------------------------
# See if user has defined NETCDFHOME, if so use it as default path
#--------------------------------------------------------------------------------

netcdf_path=${NETCDFHOME:-}

check_for_bzip2

suffix="bz2"
expand="bzip2 -dc"

#--------------------------------------------------------------------------------
#	MAKE UTILITY
#--------------------------------------------------------------------------------

GMT_make=`get_def_answer "Enter make utility to use" "make"`

#--------------------------------------------------------------------------------
#	FTP MODE
#--------------------------------------------------------------------------------
passive_ftp=n
if [ $do_ftp_qa -eq 1 ]; then
	cat << EOF >&2

If you are behind a firewall you will need to use a passive ftp session.
Only if you have some very old ftp client, you may have to resort to active ftp
(which involves the server connecting back to the client).

EOF
	passive_ftp=`get_def_answer "Do you want passive ftp transmission (y/n)" "y"`
fi

#--------------------------------------------------------------------------------
#	NETCDF SETUP
#--------------------------------------------------------------------------------

def=${NETCDFHOME:-$LIBINC_DEF}
netcdf_path=`get_def_answer "Enter directory with netcdf lib and include" "$def"`
	
#--------------------------------------------------------------------------------
#	GDAL SETUP
#--------------------------------------------------------------------------------

cat << EOF >&2

GMT4 offers experimental and optional support for other grid formats
and plotting of geotiffs via GDAL.  To use this option you must already
have the GDAL library and include files installed.

EOF
use_gdal=`get_def_answer "Use experimental GDAL grid input in GMT4 (y/n)" "y"`
if [ "$use_gdal" = "y" ]; then	# Must get the path
	cat <<- EOF >&2

	If the dirs include and lib both reside in the same parent directory,
	you can specify that below.  If not, leave blank and manually set
	the two environmental parameters GDAL_INC and GDAL_LIB.

	EOF
	def=${GDALHOME:-$LIBINC_DEF}
	gdal_path=`get_def_answer "Enter directory with GDAL lib and include" "$def"`
else
	gdal_path=
fi

#--------------------------------------------------------------------------------
#	GSHHG SETUP
#--------------------------------------------------------------------------------

cat << EOF >&2

GMT4 requires the GSHHG coastlines, borders, and rivers netCDF file to operate.
GSHHG is a separate installation as it does not change as often as GMT4 itself.
If you already have GSHHG version $GSHHG then you just need to specify its
directory; otherwise say yes to obtain GSHHG via ftp and install it.

EOF
GSHHG_install=d
GSHHG_ftp=n
GSHHG_install=`get_def_answer "Install GSHHG version $GSHHG? (y/n)" "y"`
if [ $do_ftp_qa -eq 1 ]; then
	GSHHG_ftp=`get_def_answer "Get the GSHHG version $GSHHG archive ($GSHHG_SIZE Mb) via ftp? (y/n)" "y"`
fi
if [ "$GSHHG_install" = "n" ]; then
	GSHHG_path=`get_def_answer "Enter directory where GSHHG version $GSHHG can be found" "$topdir"`
else
	GSHHG_path=`get_def_answer "Enter directory where GSHHG version $GSHHG should be placed" "$topdir"`
fi

#--------------------------------------------------------------------------------
#	GMT4 FTP SECTION
#--------------------------------------------------------------------------------

GMT_ftpsite=1
GMT_ftp=n
GMT_inst_gmt=`get_def_answer "Install GMT version $GMT_version? (y/n)" "y"`
if [ $do_ftp_qa -eq 1 ]; then
	GMT_ftp=`get_def_answer "Get the GMT version $GMT_version archive ($GMT_SIZE Mb) via ftp? (y/n)" "y"`
fi

if [ "$GMT_ftp" = "y" ] || [ "$GSHHG_ftp" = "y" ]; then
	cat << EOF >&2

We offer $N_FTP_SITES different ftp sites.  Choose the one nearest
you in order to minimize net traffic and transmission times.
The sites are:

EOF
	cat gmt_install.ftp_site >&2
	echo " " >&2
	GMT_ftpsite=`get_def_answer "Enter your choice" "1"`
	if [ $GMT_ftpsite -eq 0 ]; then
		echo " [Special GMT4 guru testing site selected]" >&2
		GMT_ftpsite=1
		GMT_FTP_TEST=1
	elif [ $GMT_ftpsite -lt 0 ] || [ $GMT_ftpsite -gt $N_FTP_SITES ]; then
		GMT_ftpsite=1
		echo " Error in assigning site, using default site." >&2
	else
		echo " You selected site number $GMT_ftpsite:" >&2
		sed -n ${GMT_ftpsite}p gmt_install.ftp_site >&2
	fi
	echo " " >&2
	ftp_ip=`sed -n ${GMT_ftpsite}p gmt_install.ftp_ip`
	is_dns=`sed -n ${GMT_ftpsite}p gmt_install.ftp_dns`
	if [ $is_dns -eq 1 ]; then
		cat << EOF >&2
		
This anonymous ftp server $ftp_ip only accepts
connections from computers on the Internet that are registered
in the Domain Name System (DNS).  If you encounter a problem
connecting because your computer is not registered, please
either use a different computer that is registered or see your
computer systems administrator (or your site DNS coordinator)
to register your computer.

EOF
	fi
else
	echo " " >&2
	echo "Since ftp mode is not selected, the install procedure will" >&2
	echo "assume the compressed archives are in the current directory." >&2
fi

echo "GMT4 can use two different algorithms for Delauney triangulation." >&2
echo " " >&2
echo "   Shewchuk [1996]: Modern and very fast, copyrighted." >&2
echo "   Watson [1982]  : Older and slower, public domain." >&2
echo " " >&2
echo "Because of the copyright, GMT4 uses Watson's routine by default." >&2
echo "However, most will want to use the optional Shewchuk routine." >&2
GMT_triangle=`get_def_answer "Use optional Shewchuk's triangulation routine (y/n)?" "y"`
	
cat << EOF >&2

The installation will install all GMT4 components in several subdirectories
under one root directory. On most Unix systems this root directory will be
something like /usr/local or /sw, under which the installation will add
bin, lib, share, etc.  Below you are asked to select to location of each
of the subdirectories.

EOF
GMT_bin=`get_def_answer "Directory for GMT4 executables?" "$topdir/gmt-${GMT_version}/bin"`
GMT_prefix=`echo $GMT_bin | sed 's!/bin!!'`
GMT_lib=`get_def_answer "Directory for GMT4 linkable libraries?" "$GMT_prefix/lib"`
GMT_include=`get_def_answer "Directory for GMT4 include files?" "$GMT_prefix/include"`
GMT_share=`get_def_answer "Directory for GMT4 data resources?" "$GMT_prefix/share"`

cat << EOF >&2

Unix man pages are usually stored in /usr/man/manX, where X is
the relevant man section.  Below, you will be asked for the /usr/man part;
the /manX will be appended automatically, so do not answer /usr/man/man1.

EOF
GMT_man=`get_def_answer "Directory for GMT4 man pages?" "$GMT_prefix/man"`
GMT_doc=`get_def_answer "Directory for GMT4 doc pages?" "$GMT_prefix/share/doc/gmt"`

cat << EOF >&2

At run-time GMT4 will look in the directory $GMT_share to find configuration
and data files.  That directory may appear with a different name to remote users
if a different mount point or a symbolic link is set.
GMT4 can use the environment variable \$GMT_SHAREDIR to point to the right place.
If users see a different location for the shared data files, specify it here.
(It will be used only to remind you at the end of the installation to set
the enronment variable \$GMT_SHAREDIR).

EOF
GMT_sharedir=`get_def_answer "Enter value of GMT_SHAREDIR selection" "$GMT_share"`

cat << EOF >&2

The answer to the following question will modify the GMT4 defaults.
(You can always change your mind by editing share/gmt.conf)

EOF
answer=`get_def_answer "Do you prefer SI or US default values for GMT4 (s/u)" "s"`
if [ "$answer" = "s" ]; then
	GMT_si=y
else
	GMT_si=n
fi

cat << EOF >&2

The answer to the following question will modify the GMT4 defaults.
(You can always change your mind later by using gmtset)

PostScript (PS) files may contain commands to set paper size, pick
a specific paper tray, or ask for manual feed.  Encapsulated PS
files (EPS) are not intended for printers (but will print ok) and
can be included in other documents.  Both formats will preview
on most previwers (out-of-date Sun pageview is an exception).

EOF
answer=`get_def_answer "Do you prefer PS or EPS as default PostScript output (p/e)" "p"`
if [ "$answer" = "p" ]; then
	GMT_ps=y
else
	GMT_ps=n
fi

cat << EOF >&2

Building the GMT4 libraries as shared instead of static will
reduce executable sizes considerably.  GMT4 supports shared
libraries under Linux, Mac OS X, SunOS, Solaris, IRIX, HPUX,
and FreeBSD.  Under other systems you may have to manually
configure macros and determine what specific options to use
with ld.

EOF
GMT_sharedlib=`get_def_answer "Try to make and use shared libraries? (y/n)" "n"`
cat << EOF >&2

If you have more than one C compiler you need to specify which,
otherwise just hit return to use the default compiler.

EOF
GMT_cc=`get_answer "Enter name of C compiler (include path if not in search path)"`
cat << EOF >&2

GMT4 can be built as 32-bit or 64-bit.  We do not recommend to
explicitly choose 32-bit or 64-bit, as the netCDF install is
not set up to honor either of these settings. The default is
to compile without sending any 32-bit or 64-bit options to the
compiler, which generally create 32-bit versions on older systems,
and 64-bit versions on newer systems, like OS X Snow Leopard.

EOF

answer=`get_def_answer "Explicitly select 32- or 64-bit executables? (y/n)" "n"`
if [ $answer = y ]; then
	GMT_64=`get_def_answer "Force 64-bit? (y/n) " "y"`
else
	GMT_64=
fi

cat << EOF >&2

GMT4 passes information about previous GMT4 commands onto later
GMT4 commands via a hidden file (.gmtcommands).  To avoid that
this file is updated by more than one program at the same time
(e.g., when connecting two or more GMT4 programs with pipes) we
use POSIX advisory file locking on the file.  Apparently, some
versions of the Network File System (NFS) have not implemented
file locking properly.  Although the behavior may be undefined
in this case, it should be safe to activate this option.

EOF
GMT_flock=`get_def_answer "Use POSIX Advisory File Locking in GMT4 (y/n)" "y"`

GMT_run_examples=`get_def_answer "Want to test GMT4 by running the $N_EXAMPLES examples? (y/n)" "y"`
GMT_delete=`get_def_answer "Delete all tar files after install? (y/n)" "n"`

# export CONFIG_SHELL=`type sh | awk '{print $NF}'`

GMT_suppl_mex=d
GMT_suppl_xgrid=d
if [ ! "X$MATLAB" = "X" ]; then
	MATDIR=$MATLAB
elif [ "$os" = "Darwin" ]; then	# Pick one from Applications folder
	(echo /Applications/MATLAB* | grep -v '\*' | head -1 > /tmp/$$.matlab) 2> /dev/null
	if [ ! -s /tmp/$$.matlab ]; then
		MATDIR=`cat /tmp/$$.matlab`
	else
		MATDIR=/usr/local/matlab
	fi
	rm -f /tmp/$$.matlab
else
	MATDIR=/usr/local/matlab
fi

if [ ! $GMT_get_suppl = "n" ]; then

cat << EOF >&2

Several supplemental packages are included in the archive:

------------------------------------------------------------------------------
dbase:     Extracting data from NGDC DEM and other grids
gshhg:     Global Self-consistent Hierarchical High-resolution Geography extractor
imgsrc:    Extracting grids from global altimeter files (Sandwell/Smith)
meca:      Plotting special symbols in seismology and geodesy
mex:       Interface for reading/writing GMT grdfiles (REQUIRES MATLAB or OCTAVE)
mgd77:     Programs for handling MGD77 data files
mgg:       Programs for making, managing, and plotting .gmt files
misc:      Digitize or stitch line segments, read netCDF 1-D tables, and more
EOF
if [ $SERIES -eq 5 ]; then
	cat <<- EOF >&2
	potential: Geopotential tools
	EOF
fi
cat << EOF >&2
segyprogs: Plot SEGY seismic data files
sph:       Spherical triangulation, Voronoi construction and interpolation
spotter:   Plate tectonic backtracking and hotspotting
x2sys:     New (Generic) Track intersection (crossover) tools
x_system:  Old (MGG-specific) Track intersection (crossover) tools
xgrid:     An X11-based graphical editor for netCDF-based .nc files
------------------------------------------------------------------------------

Supplements that only depend on GMT4 will be installed.  Because others depend on
libraries outside GMT4 we ask if you want to install these supplements separately.
EOF

	GMT_suppl_mex=`get_def_answer "Install the mex supplemental package? (y/n)?" "y"`
	GMT_suppl_xgrid=`get_def_answer "Install the xgrid supplemental package? (y/n)?" "y"`
	if [ "$GMT_suppl_mex" = "y" ]; then
		echo " " >&2
		echo "The mex supplement requires Matlab or Octave." >&2
		GMT_mex_type=`get_def_answer "Specify matlab or octave" "octave"`
		if [ "$GMT_mex_type" = "matlab" ];then
			MATDIR=`get_def_answer "Enter MATLAB system directory" "$MATDIR"`
		fi
		echo "Hit return for default paths or provide the alternative paths for matlab/Octave files:" >&2
		mex_mdir=`get_def_answer "Enter Install directory for .m functions" ""`
		mex_xdir=`get_def_answer "Enter Install directory for .mex functions" ""`	
	fi
fi

file=`get_def_answer "Enter name of the parameter file that will now be created" "GMT4param.txt"`

if [ $GMT_FTP_TEST -eq 1 ]; then
	GMT_ftpsite=0
fi

#--------------------------------------------------------------------------------
# SAVE SESSION SETTINGS TO INSTALL.PAR
#--------------------------------------------------------------------------------

cat << EOF > $file
# This file contains parameters needed by the install script
# for GMT4 Version ${GMT_version}.  Give this parameter file
# as the argument to the install_gmt.sh script and the whole
# installation process can be placed in the background.
# Default answers will be selected where none is given.
# You can edit the values, but do not remove definitions!
#
# This script was created by install_gmt.sh on
#
EOF
date | awk '{printf "#\t%s\n", $0}' >> $file
cat << EOF >> $file
#
# Do NOT add any spaces around the = signs.  The
# file MUST conform to Bourne shell syntax
#---------------------------------------------
#       GMT4 VERSION TO INSTALL
#---------------------------------------------
VERSION=$GMT_version
#---------------------------------------------
#       SYSTEM UTILITIES AND FTP SETTING
#---------------------------------------------
GMT_make=$GMT_make
passive_ftp=$passive_ftp
#---------------------------------------------
#       NETCDF SECTION
#---------------------------------------------
netcdf_path=$netcdf_path
#---------------------------------------------
#       GSHHG SECTION
#---------------------------------------------
GSHHG_install=$GSHHG_install
GSHHG_ftp=$GSHHG_ftp
GSHHG_path=$GSHHG_path
#---------------------------------------------
#       GDAL SECTION
#---------------------------------------------
use_gdal=$use_gdal
gdal_path=$gdal_path
#---------------------------------------------
#       GMT4 & GSHHG FTP SECTION
#---------------------------------------------
GMT_ftp=$GMT_ftp
GMT_inst_gmt=$GMT_inst_gmt
GMT_ftpsite=$GMT_ftpsite
#---------------------------------------------
#       GMT4 SUPPLEMENTS SELECT SECTION
#---------------------------------------------
GMT_suppl_mex=$GMT_suppl_mex
GMT_suppl_xgrid=$GMT_suppl_xgrid
#---------------------------------------------
#       GMT4 ENVIRONMENT SECTION
#---------------------------------------------
GMT_si=$GMT_si
GMT_ps=$GMT_ps
GMT_prefix=$GMT_prefix
GMT_bin=$GMT_bin
GMT_lib=$GMT_lib
GMT_share=$GMT_share
GMT_include=$GMT_include
GMT_man=$GMT_man
GMT_doc=$GMT_doc
GMT_sharedir=$GMT_sharedir
#---------------------------------------------
#       COMPILING & LINKING SECTION
#---------------------------------------------
GMT_sharedlib=$GMT_sharedlib
GMT_cc=$GMT_cc
GMT_64=$GMT_64
GMT_triangle=$GMT_triangle
GMT_flock=$GMT_flock
#---------------------------------------------
#       TEST & PRINT SECTION
#---------------------------------------------
GMT_run_examples=$GMT_run_examples
GMT_delete=$GMT_delete
#---------------------------------------------
#       MEX SECTION
#---------------------------------------------
MATDIR=$MATDIR
mex_mdir=$mex_mdir
mex_xdir=$mex_xdir
EOF

echo "Session parameters written to file $file" >&2
echo $file
}
#--------------------------------------------------------------------------------
# BACKGROUND INSTALLATION OF GMT4 FUNCTIONS
#--------------------------------------------------------------------------------
install_this_gmt()
# Get? File
{
	ok=1
	if [ -f gmt-${GMT_version}-src.tar.$suffix ]; then
		this=gmt-${GMT_version}-src.tar.$suffix
	else
		ok=0
	fi
	if [ $ok -eq 1 ]; then	# File exists and we have not said no
		$expand $this | tar xvf -
	fi
	ok=1
	if [ -f gmt-${GMT_version}-non-gpl-src.tar.$suffix ]; then
		this=gmt-${GMT_version}-non-gpl-src.tar.$suffix
	else
		ok=0
	fi
	if [ $ok -eq 1 ]; then	# File exists and we have not said no
		$expand $this | tar xvf -
	fi
}

install_gshhg()
{
# Get? dir
	dir=$1
	here=`pwd`
	ok=1
	done=0
	if [ -f gshhg-gmt-${GSHHG}.tar.gz ]; then
		this=gshhg-gmt-${GSHHG}.tar.gz
		expander="gzip -dc"
	elif [ -f gshhg-gmt-nc4-${GSHHG}.tar.gz ]; then
		this=gshhg-gmt-nc4-${GSHHG}.tar.gz
		expander="gzip -dc"
	elif [ -f gshhg-gmt-nc3-${GSHHG}.tar.$suffix ]; then
		this=gshhg-gmt-nc3-${GSHHG}.tar.$suffix
		expander=$expand
	else
		ok=0
	fi
	if [ $ok -eq 1 ]; then	# File is present and wanted
		if [ ! -d $dir ]; then
			mkdir -p $dir
		fi				
		if [ ! -d $dir ]; then
			echo "Could not make the directory $dir - $this not untarred"
		else
			cd $dir
			$expander $here/$this | tar xvf -
			done=1
			cd $here
		fi
	fi
}

make_ftp_list()
{
# arg1=get arg2=prefix
	get_this=$1
	pre=$2
	if [ "$get_this" = "y" ]; then
		echo "get ${pre}.tar.$suffix" >> gmt_install.ftp_list
	fi
}

#============================================================
#	START OF MAIN SCRIPT - INITIALIZATION OF PARAMETERS
#============================================================

trap "rm -f gmt_install.ftp_*; exit" 0 2 15
DIR=pub/gmt
#--------------------------------------------------------------------------------
#	LISTING OF CURRENT FTP MIRROR SITES
#--------------------------------------------------------------------------------

N_FTP_SITES=8
cat << EOF > gmt_install.ftp_ip
ftp.soest.hawaii.edu
ftp.star.nesdis.noaa.gov
ftp.iris.washington.edu
ftp.iag.usp.br
gmt.mirror.ac.za
EOF

cat << EOF > gmt_install.ftp_dns
1
1
0
0
0
EOF
#--------------------------------------------------------------------------------

give_help=0
if [ $# -gt 0 ]; then
	if [ "X$1" = "X-h" ] || [ "X$1" = "X-help" ] || [ "X$1" = "X--help" ]; then
		give_help=1
	fi
fi

if [ $give_help -eq 1 ]; then
	cat << EOF >&2
install_gmt.sh - Automatic installation of GMT4

GMT4 is installed in the background following the gathering
of installation parameters.  These parameters are obtained
in one of two ways:

(1) Via Internet: You may compose a parameter file using
    the form on the GMT4 home page (see the installation
    link under gmt.soest.hawaii.edu) and save the result
    of your request to a parameter file on your hard disk.
2)  Interactively: You may direct this script to start an
    interactive session which gathers information from you
    via a question-and-answer dialog and then saves your
    answers to a parameter file on your hard disk.
    
The parameter file is then passed on to the next stage which
carries out the installation without further interruptions.

Thus, two forms of the command are recognized:

install_gmt.sh [ -c ] parameterfile [ &> logfile]  (for background install)
install_gmt.sh [ -c ] [ -n ] [ &> logfile]	 (for interactive install)

The option -n means do NOT install, just gather the parameters.
The option -c means all tar archices are already in current directory
    and there is no need to ask questions regarding ftp transfers.
Of course, there is also

      install_gmt.sh -h			    (to display this message)
     
EOF
	exit
fi

do_install=1
do_ftp_qa=1
if [ $# -ge 1 ] && [ "$1" = "-n" ]; then	# Do not want to install yet
	do_install=0
	shift
fi
if [ $# -ge 1 ] && [ "$1" = "-c" ]; then	# Local install from cwd - turn off ftp questions
	do_ftp_qa=0
	shift
fi

if [ $# -eq 1 ] && [ "$1" != "-h" ]; then	# User gave a parameter file
	parfile=$1
	if [ ! -f $parfile ]; then
		echo "install_gmt.sh: Parameter file $parfile not found" >&2
		exit
	fi
else			# We must run an interactive session first
	parfile=`prep_gmt`
	if [ $do_install -eq 0 ]; then	# Did not want to install yet
		exit
	fi
	answer=`get_answer "Hit return to start the install"`
fi

#--------------------------------------------------------------------------------
#	INITIATE SETTINGS FROM PARAMETER FILE
#--------------------------------------------------------------------------------
# 
# Because arguments to the . command MUST be in the users PATH
# we must prepend ./ if the file is in the local directory since
# the user may not have . in his PATH
first=`echo $parfile | awk '{print substr($1,1,1)}'`
if [ "$first" = "/" ]; then	# absolute path OK
	. $parfile
else				# Local file, prepend ./
	. ./$parfile
fi
GMT_version=$VERSION
SERIES=`echo $GMT_version | awk '{print substr($1,1,1)}'`
topdir=`pwd`
os=`uname -s`

check_for_bzip2
suffix="bz2"
expand="bzip2 -dc"
echo "+++ Will expand *.bz2 files made with bzip2 +++"

CONFIG_SHELL=`type sh | awk '{print $NF}'`
export CONFIG_SHELL

#--------------------------------------------------------------------------------
#	NETCDF SECTION
#--------------------------------------------------------------------------------

if [ ! x"$NETCDF_INC" = x ] && [ ! x"$NETCDF_LIB" = x ]; then	# Only set up path if these are not set
	echo "install_gmt.sh: Using NETCDF_INC=$NETCDF_INC and NETCDF_LIB=$NETCDF_LIB to find netcdf support"
elif [ x"$netcdf_path" = x ]; then	# Not explicitly set, must assign it
	echo "install_gmt.sh: Let configure determine netcdf support"
else
	echo "install_gmt.sh: Use $netcdf_path for netcdf support"
fi

#--------------------------------------------------------------------------------
#	GMT4 FTP SECTION
#--------------------------------------------------------------------------------

cd $topdir
if [ "$GMT_ftp" = "y" ] || [ "$GSHHG_ftp" = "y" ]; then

	if [ $GMT_ftpsite -eq 0 ]; then
		GMT_ftpsite=1
		echo " [Special GMT4 guru ftp site selected]" >&2
		GMT_FTP_TEST=1
	fi
	if [ $GMT_ftpsite -lt 0 ] || [ $GMT_ftpsite -gt $N_FTP_SITES ]; then
		GMT_ftpsite=1
		echo " Error in assigning site, use default site $GMT_ftpsite" >&2
	fi
	if [ $GMT_ftpsite -eq 1 ]; then	# SOEST's server starts at / and there is no pub
		if [ $GMT_FTP_TEST -eq 1 ]; then	# Special dir for guru testing
			DIR=gmttest/4
		else
			DIR=gmt
		fi
	elif [ $GMT_ftpsite -eq 2 ]; then	# NOAA's server uses different subdir
		DIR=pub/sod/lsa/gmt
	fi
	ftp_ip=`sed -n ${GMT_ftpsite}p gmt_install.ftp_ip`
	is_dns=`sed -n ${GMT_ftpsite}p gmt_install.ftp_dns`

#	Determine if client's ftp is set to active or passive mode by default

	echo passive | \ftp | grep off > /dev/null
	active=$?

#	Set-up ftp command; active above will be 0 if passive is off
	echo "user anonymous $USER@" > gmt_install.ftp_list
	if [ "$passive_ftp" = "y" ] && [ $active -eq 0 ]; then
		echo "passive" >> gmt_install.ftp_list
		echo "quote pasv" >> gmt_install.ftp_list
		if [ "$os" = "Darwin" ]; then # Seems to need this now
			echo "epsv" >> gmt_install.ftp_list
		fi
	fi
	echo "cd $DIR" >> gmt_install.ftp_list
	echo "binary" >> gmt_install.ftp_list
	make_ftp_list $GMT_ftp gmt-${GMT_version}-src
	make_ftp_list $GMT_triangle gmt-${GMT_version}-non-gpl-src
	if [ $GSHHG_ftp = y ]; then
		echo "get gshhg-gmt-${GSHHG}.tar.gz" >> gmt_install.ftp_list
	fi
	echo "quit" >> gmt_install.ftp_list
	echo " " >> gmt_install.ftp_list

#	Get the files

	echo "Getting GMT4 by anonymous ftp from $ftp_ip (be patient)..." >&2

	before=`du -sk . | cut -f1`
	ftp -dn $ftp_ip < gmt_install.ftp_list || ( echo "fpt failed - try again later >&2"; exit )
	after=`du -sk . | cut -f1`
	rm -f gmt_install.ftp_list
	newstuff=`echo $before $after | awk '{print $2 - $1}'`
	echo "Got $newstuff kb ... done" >&2
fi

# If we got here via a parameter file that had blank answers
# we need to provide the default values here

GMT_prefix=${GMT_prefix:-$topdir/gmt-${GMT_version}}
GMT_bin=${GMT_bin:-$GMT_prefix/bin}
GMT_lib=${GMT_lib:-$GMT_prefix/lib}
GMT_share=${GMT_share:-$GMT_prefix/share}
GMT_include=${GMT_include:-$GMT_prefix/include}
GMT_man=${GMT_man:-$GMT_prefix/man}
GMT_doc=${GMT_doc:-$GMT_prefix/share/doc/gmt}
GMT_sharedir=${GMT_sharedir:-$GMT_share}
GSHHG_path=${GSHHG_path:-$topdir}

#--------------------------------------------------------------------------------
# First install source code and documentation
#--------------------------------------------------------------------------------

if [ "$GMT_inst_gmt" = "y" ]; then
	install_this_gmt
fi
#--------------------------------------------------------------------------------
# Now do coastline archives
#--------------------------------------------------------------------------------

if [ "$GSHHG_install" = "y" ]; then
	install_gshhg $GSHHG_path
fi

echo " " >&2
echo "Set write privileges on all files in gmt-${GMT_version} ..." >&2
cd gmt-${GMT_version}
chmod -R +w .
cd ..
echo "Done" >&2
echo " " >&2

#--------------------------------------------------------------------------------
#	GMT4 INSTALLATION PREPARATIONS
#--------------------------------------------------------------------------------

cd $topdir
cd gmt-${GMT_version}
here=`pwd`

# Are we allowed to write in $GMT_share?

mkdir -p $GMT_share
if [ -w $GMT_share ]; then
	write_share=1
else
	write_share=0
fi

# Are we allowed to write in $GMT_bin?

mkdir -p $GMT_bin
if [ -w $GMT_bin ]; then
	write_bin=1
else
	write_bin=0
fi

# Are we allowed to write in $GMT_man?

mkdir -p $GMT_man
if [ -w $GMT_man ]; then
	write_man=1
else
	write_man=0
fi

# Are we allowed to write in $GMT_doc?

mkdir -p $GMT_doc
if [ -w $GMT_doc ]; then
	write_doc=1
else
	write_doc=0
fi

#--------------------------------------------------------------------------------
#	CONFIGURE PREPARATION
#--------------------------------------------------------------------------------

if [ "$GMT_si" = "y" ]; then
	enable_us=
else
	enable_us=--enable-US
fi
if [ "$GMT_ps" = "y" ]; then
	enable_eps=
else
	enable_eps=--enable-eps
fi
if [ "$GMT_flock" = "y" ]; then
	disable_flock=
else
	disable_flock=--disable-flock
fi
if [ "$GMT_triangle" = "y" ]; then
	enable_triangle=--enable-triangle
else
	enable_triangle=
fi
if [ "$GMT_suppl_mex" = "y" ]; then
	disable_mex=
else
	disable_mex=--disable-mex
fi
if [ "$GMT_suppl_xgrid" = "y" ]; then
	disable_xgrid=
else
	disable_xgrid=--disable-xgrid
fi

if [ "$GMT_sharedlib" = "y" ]; then
	enable_shared=--enable-shared
else
	enable_shared=
fi

if [ "$GMT_64" = "y" ]; then
	enable_64=--enable-64
elif [ "$GMT_64" = "n" ]; then
	enable_64=--disable-64
else
	enable_64=
fi

if [ ! x"$MATDIR" = x ]; then	# MATDIR is set
	if [ "X$GMT_mex_type" = "Xmatlab" ]; then
		enable_matlab=--enable-matlab=$MATDIR
	else
		enable_matlab=--enable-octave=yes
	fi
else
	enable_matlab=
fi
if [ ! x"$mex_mdir" = x ]; then	# mex_mdir is set
	enable_mex_mdir=--enable-mex-mdir=$mex_mdir
else
	enable_mex_mdir=
fi
if [ ! x"$mex_xdir" = x ]; then	# mex_xdir is set
	enable_mex_xdir=--enable-mex-xdir=$mex_xdir
else
	enable_mex_xdir=
fi

# Experimental GDAL support 
if [ "$use_gdal" = "y" ]; then	# Try to include GDAL support
        if [ ! "x$gdal_path" = "x" ]; then	# GDAL parent dir specified
 		enable_gdal=--enable-gdal=$gdal_path
	else
 		enable_gdal=--enable-gdal
        fi
else
	enable_gdal=
fi

#--------------------------------------------------------------------------------
#	GMT4 installation commences here
#--------------------------------------------------------------------------------

cat << EOF >&2

---> Begin GMT $GMT_version installation <---

---> Run configure to create config.mk and gmt_notposix.h

EOF

# Clean out old cached values

rm -f config.{cache,log,status}

# Clean out old config.mk etc if present

if [ -f src/config.mk ]; then
	echo '---> Clean out old executables, *.o, *.a, and config.mk' >&2
	$GMT_make spotless || exit
fi

# Determine actual GSHHG directory to use

if [ -d $GSHHG_path/gshhg-gmt-${GSHHG} ]; then
	enable_gshhg=--with-gshhg-dir=$GSHHG_path/gshhg-gmt-${GSHHG}
elif [ -d $GSHHG_path/gshhg-gmt-nc4-${GSHHG} ]; then
	enable_gshhg=--with-gshhg-dir=$GSHHG_path/gshhg-gmt-nc4-${GSHHG}
elif [ -d $GSHHG_path/gshhg-gmt-nc3-${GSHHG} ]; then
	enable_gshhg=--with-gshhg-dir=$GSHHG_path/gshhg-gmt-nc3-${GSHHG}
else
	enable_gshhg=--with-gshhg-dir=$GSHHG_path
fi

if [ x"$netcdf_path" = x ]; then	# Not set
	enable_netcdf=
else
	enable_netcdf=--enable-netcdf=$netcdf_path
fi

# Echo out the exact configure command for possible reuse by the user

cat << EOF >&2
./configure --prefix=$GMT_prefix --bindir=$GMT_bin --libdir=$GMT_lib --includedir=$GMT_include $enable_us \
  $enable_netcdf $enable_matlab $enable_eps $disable_flock $enable_shared $enable_triangle $enable_64 \
  --mandir=$GMT_man --docdir=$GMT_doc --datadir=$GMT_share --enable-update=$ftp_ip \
  $disable_mex $disable_xgrid $enable_mex_mdir $enable_mex_xdir $enable_gdal $enable_gshhg
EOF

./configure --prefix=$GMT_prefix --bindir=$GMT_bin --libdir=$GMT_lib --includedir=$GMT_include $enable_us \
  $enable_netcdf $enable_matlab $enable_eps $disable_flock $enable_shared $enable_triangle $enable_64 \
  --mandir=$GMT_man --docdir=$GMT_doc --datadir=$GMT_share --enable-update=$ftp_ip \
  $disable_mex $disable_xgrid $enable_mex_mdir $enable_mex_xdir $enable_gdal $enable_gshhg

if [ -f .gmtconfigure ]; then
	cat .gmtconfigure
	rm -f .gmtconfigure
fi

#--------------------------------------------------------------------------------
# INSTALL GMT4 AND SUPPLEMENTAL PROGRAMS
#--------------------------------------------------------------------------------

$GMT_make all || exit

if [ $write_bin -eq 1 ]; then
	$GMT_make install || exit
else
	echo "You do not have write permission to make $GMT_bin" >&2
fi

#--------------------------------------------------------------------------------
# INSTALL DATA DIRECTORY
#--------------------------------------------------------------------------------

if [ $write_share -eq 1 ]; then
	$GMT_make install-data || exit
else
	echo "You do not have write permission to make $GMT_share" >&2
fi

#--------------------------------------------------------------------------------
# INSTALL MAN PAGES
#--------------------------------------------------------------------------------

if [ $write_man -eq 1 ]; then
	$GMT_make install-man || exit
	echo "All users must include $GMT_man in their MANPATH" >&2
else
	echo "You do not have write permission to make $GMT_man" >&2
fi


#--------------------------------------------------------------------------------
# INSTALL WWW PAGES
#--------------------------------------------------------------------------------

if [ $write_doc -eq 1 ]; then
	if [ -d doc ]; then
		$GMT_make install-doc || exit
		echo "All users should add $GMT_doc/html/gmt_services.html to their browser bookmarks" >&2
	fi
else
	echo "You do not have write permission to create $GMT_doc" >&2
fi

#--------------------------------------------------------------------------------
# RUN EXAMPLES
#--------------------------------------------------------------------------------

# Run examples with /src as binary path in case the user did
# not have permission to place files in GMT_bin

if [ -d doc/examples ] && [ "$GMT_run_examples" = "y" ]; then
	GMT_SHAREDIR=$GMT_sharedir
	export GMT_SHAREDIR
	# avoid parallel builds with gmake
	if $GMT_make -v | grep -q "GNU Make"; then
		$GMT_make -j1 examples animations || exit
	else
		$GMT_make examples animations || exit
	fi
fi

cd $here/src
if [ $write_bin -eq 0 ]; then
	echo "Manually do the final installs as another user (root?)" >&2
	echo "Go to the main GMT4 directory and say:" >&2
	echo "make install install-suppl clean" >&2
fi
if [ $write_share -eq 0 ]; then
	echo "Manually do the coastline install as another user (root?)" >&2
	echo "Go to the main GMT4 directory and say:" >&2
	echo "make install-data" >&2
fi
if [ $write_man -eq 0 ]; then
	echo "Manually do the man page install as another user (root?)" >&2
	echo "Go to the main GMT4 directory and say:" >&2
	echo "make install-man" >&2
fi
if [ $write_doc -eq 0 ]; then
	echo "Manually do the doc page install as another user (root?)" >&2
	echo "Go to the main GMT4 directory and say:" >&2
	echo "make install-doc" >&2
fi

cd $topdir
if [ "$GMT_delete" = "y" ]; then
	rm -f gmt-*.tar.$suffix gshhg-*.tar.$suffix
fi

cat << EOF >&2
GMT4 installation complete. Remember to set these:

-----------------------------------------------------------------------
For csh or tcsh users:
set path=($GMT_bin \$path)
EOF
if [ "$GMT_sharedir" != "$GMT_share" ]; then
	echo setenv GMT_SHAREDIR $GMT_sharedir >&2
fi
cat << EOF >&2

For sh or bash users:
export PATH=$GMT_bin:\$PATH

Note: if you installed netCDF as a shared library you may have to add
the path to this library to LD_LIBRARY_PATH or place the library in a
standard system path [see information on shared library for your OS].
EOF
if [ "$GMT_sharedir" != "$GMT_share" ]; then
	echo export GMT_SHAREDIR=$GMT_sharedir >&2
fi
cat << EOF >&2

For all users:
EOF
if [ ! x"$GMT_man" = x ]; then
	echo "Add $GMT_man to MANPATH" >&2
fi
if [ ! x"$GMT_doc" = x ]; then
	echo "Add $GMT_doc/html/gmt_services.html as browser bookmark" >&2
fi
echo "-----------------------------------------------------------------------" >&2
rm -f gmt_install.ftp_*
