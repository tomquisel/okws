#!/bin/sh
##
## okws-init-jail.sh
##
##   A shell script that given an OKWS module, and an OKWS config file,
##   will initialize the jail as required, setting up the appropriate
##   directories, twiddling permissions bits, and so on.
##
## Usage:
##
##    okws-init-jail.sh [-f <config-file>] <module-name>
##
##-----------------------------------------------------------------------
## $Id: okws-init-jail.sh,v 1.1 2006/06/19 17:20:20 max Exp $
##-----------------------------------------------------------------------

#
# initialize various tools, allowing the user to overload them if
# if necessary.
#
oij_init() {

    test "$LDD"     || LDD=ldd
    test "$PERL"    || PERL=perl
    test "$INSTALL" || INSTALL=install
    test "$CMP"     || CMP=cmp
    test "$MKDIR"   || MKDIR='mkdir -p'
    
    if test -z "$LINKER" ; then
	name=libexec/ld-elf.so.1
	linkers="/$name /usr/$name /lib/ld-linux.so.2"
	for LINKER in $linkers; do
	    if [ -f $LINKER ]; then
		break
	    fi
	done
	if [ ! -f $LINKER ]; then
	    echo "Cannot find linker: $name"
	    exit 128
	fi
    fi
    return 0
}

#
# either use the given configuration variable, or search in the
# standard OKWS locations
#
get_configfile()
{
    if test -z "$CFGFILE" ; then
	for d in \ # %%okwsconfdir%% \
	    /usr/local/etc/okws /usr/local/okws/conf /etc/okws/
	do
	  CFGFILE=$d/okws_config
	  if [ -f "$CFGFILE" ] ; then
	      return 0
	  fi
	done
    fi
    if [ ! -f $CFGFILE ] ; then
	echo "Cannot find configuration file" 2>&1
	return 1
    fi
    return 0
}

#
# read field <name> <column> [<verbose>]
#
read_field()
{
    field=$1
    shift
    if [ $# -ge 2 ]; then
	col=$1
    else
	col=2
    fi

    if [ $# -ge 3 ]; then
	verbose=$3
    else
	verbose=1
    fi

    AE="{ print \$$col }"

    f=`sed 's/#.*//' < $CFGFILE | grep -iE "$field\b" | awk "$AE" `
    echo $f
    r=$?

    test $r -eq 0 && test -z "$f" && r=1

    if [ $verbose -eq 1 -a $r -ne 0 ] ; then
	echo $field ": not found in config file" 2>&1
    fi

    return $r
}

#
# make a directory if it does not exist, and handle weird cases
# such as if it's a file or something.
#
mkdir_complete()
{
    d=$1
    m=$2
    if [ -f $d -a ! -d $d ]; then
	echo "$d exists, but isn't a directory!" 1>&2
	return 1
    fi
    if [ ! -f $d ] ; then
	$MKDIR $d
    fi
    if [ ! -d $d ] ; then
	echo "$MKDIR $d failed!" 1>&2
	return 1
    fi
    chmod $m $d
    return 0
}

#
# touch a file if it doesn't exist already
#
touch_file()
{
    f=$1
    m=$2
    if [ ! -f $f ]; then
	touch $f
    fi
    chmod $m $f
    return 0
}

#
# make the log directory, and chown it as necessary
#
config_log_dir()
{
    dir=`read_field LogDir 2` || return 1
    access=`read_field AccessLog 2` || return 1
    error=`read_field ErrorLog 2` || return 1
    user=`read_field OklogdUser 2` 
    group=`read_field OklogdGroup 2`

    mkdir_complete $dir 0755
    if [ $? -ne 0 ] ; then
	echo "Could not make/access log directory: $dir"
	return 1
    fi

    touch_file $dir/$access 0644
    touch_file $dir/$error 0644

    if test "$user" ; then
	for f in $dir $dir/$access $dir/$error ; do
	    chown $user $f
	done
    fi

    if test "$group"; then 
	for f in $dir $dir/$access $dir/$error ; do
	    chgrp $group $f
	done
    fi

    return 0
}


#
# usage output and kill
#
usage() {
    echo "usage: $0 [-f <config-file>] <module-name>]" 1>&2
    exit 2
}

args=`getopt f: $* `
if [ $? -ne 0 ] ; then
    usage
fi
set -- $args
for i; do
  case "$i" in
      -f) CFGFILE="$2"; shift; shift;;
      --) shift; break;;
  esac
done
      
oij_init || usage
get_configfile || usage
config_log_dir || exit 3

#read_field $*