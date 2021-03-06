#
# Copyright (C) 2008 Search Solution Corporation. All rights reserved by Search Solution.
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.
#

AC_PREREQ(2.59)
AC_INIT([CUBRID Cluster 2010], RELEASE, https://sourceforge.net/projects/cubridcluster/, cubridcluster)
AC_CONFIG_SRCDIR([src/executables/server.c])
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE

# Checks for programs.
remember_CFLAGS="$CFLAGS"
remember_CXXFLAGS="$CXXFLAGS"
remember_LDFLAGS="$LDFLAGS"
AC_PROG_CC
AC_PROG_CXX
AC_PROG_LIBTOOL
AC_PROG_RANLIB
AC_PROG_INSTALL
AC_PROG_YACC
AC_PROG_LEX
CFLAGS="$remember_CFLAGS"
CXXFLAGS="$remember_CXXFLAGS"
LDFLAGS="$remember_LDFLAGS"

# Checks bit model feature.
AC_ARG_ENABLE([64bit],
	[AS_HELP_STRING([--enable-64bit],
		[build 64 bit code @<:@default=no (32 bit code)@:>@])],
	[bit_model=$enableval],
	[bit_model=no])

if test "$bit_model" = "yes"
then
	BIT_MODEL="-m64"
else
	BIT_MODEL="-m32"
	CC="$CC -m32"
	CXX="$CXX -m32"
fi
AM_CONDITIONAL([BUILD_64], [test "$bit_model" = "yes"])

# System type
SYSTEM_TYPE="$host_vendor-$host_os"
MACHINE_TYPE="$host_cpu"
export BIT_MODEL SYSTEM_TYPE MACHINE_TYPE CC CXX

case $SYSTEM_TYPE in
	*linux*) SYS_DEFS="-DGCC -DLINUX -D_GNU_SOURCE -DI386"
		 SYS_LIBS="" ;;
	*)       SYS_DEFS=""
		 SYS_LIBS="" ;;
esac

# Checks for libraries.
AC_CHECK_LIB([m], [main])
#AC_CHECK_LIB([rt], [main])
AC_CHECK_LIB([dl], [main])
#AC_CHECK_LIB([elf], [main])
#AC_CHECK_LIB([iberty], [main])
#AC_CHECK_LIB([bfd], [main])
AC_CHECK_LIB([pthread], [main])
AC_CHECK_LIB([curses], [main])
AC_CHECK_LIB([stdc++], [main])
AC_CHECK_LIB([gcrypt], [main])

# Checks for header files.
AC_HEADER_STDC
AC_HEADER_STDBOOL
AC_HEADER_STAT
AC_HEADER_TIME
AC_CHECK_HEADERS([limits.h],
	[],
	[AC_DEFINE([PATH_MAX], [512], [Max path length])])
AC_CHECK_HEADERS([limits.h],
	[],
	[AC_DEFINE([NAME_MAX], [255], [Max file name length])])
AC_CHECK_HEADERS([limits.h],
	[],
	[AC_DEFINE([LINE_MAX], [2048], [Max line length])])
AC_CHECK_HEADERS([sys/param.h sys/socket.h nl_types.h regex.h getopt.h libgen.h rpc/des_crypt.h])

# Checks for typedefs, structures, and compiler characteristics.
#AC_TYPE_INT8_T
#AC_TYPE_INT16_T
#AC_TYPE_INT32_T
#AC_TYPE_INT64_T
#AC_TYPE_INTMAX_T
#AC_TYPE_INTPTR_T
#AC_TYPE_UINT8_T
#AC_TYPE_UINT16_T
#AC_TYPE_UINT32_T
#AC_TYPE_UINT64_T
#AC_TYPE_UINTMAX_T
#AC_TYPE_UINTPTR_T
AC_TYPE_OFF_T
AC_TYPE_SIZE_T
AC_TYPE_PID_T
AC_CHECK_SIZEOF([char])
AC_CHECK_SIZEOF([short])
AC_CHECK_SIZEOF([int])
AC_CHECK_SIZEOF([long])
AC_CHECK_SIZEOF([long long])
AC_CHECK_SIZEOF([void *])
AC_CHECK_TYPES([long long])
AC_CHECK_TYPES([byte_t, int8_t, int16_t, int32_t, int64_t, intmax_t, intptr_t,
		uint8_t, uint16_t, uint32_t, uint64_t, uintmax_t, uintptr_t])
remember_CFLAGS="$CFLAGS"
CFLAGS="$CFLAGS -D_LARGEFILE64_SOURCE"
AC_CHECK_TYPES([off64_t], [SYS_DEFS="$SYS_DEFS -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64"])
CFLAGS="$remember_CFLAGS"

AC_STRUCT_TM

# Checks for library functions.
AC_FUNC_VPRINTF
AC_CHECK_FUNCS([getrlimit sysconf])

# Checks for system functions for which we have replacements.
AC_REPLACE_FUNCS([vasprintf asprintf strdup strlcpy strlcat \
		  getopt getopt_long dirname basename])

# Check gethostbyname_r function
AC_MSG_CHECKING([for glibc gethostbyname_r])
AC_TRY_LINK([#include <netdb.h>],
	[struct hostent result_buf;
	 char buf[1024];
	 struct hostent *result;
	 int h_erropp;
	 gethostbyname_r("localhost", &result_buf, buf, sizeof(buf), &result, &h_erropp);
	],
	[AC_MSG_RESULT([yes])
	 AC_DEFINE(HAVE_GETHOSTBYNAME_R_GLIBC, 1, [Using glibc version of gethostbyname_r()])
	 AC_DEFINE(HAVE_GETHOSTBYNAME_R, 1, [Define to 1 if you have the `gethostbyname_r' function.])
	],
	[AC_MSG_RESULT([no])]
)
AC_MSG_CHECKING([for Solaris/Irix gethostbyname_r])
AC_TRY_LINK([#include <netdb.h>],
	[struct hostent result;
	 char buf[1024];
	 int h_errnop;
	 gethostbyname_r("localhost", &result, buf, sizeof(buf), &h_errnop);
	],
	[AC_MSG_RESULT([yes])
	 AC_DEFINE(HAVE_GETHOSTBYNAME_R_SOLARIS, 1, [Using Solaris gethostbyname_r()])
	 AC_DEFINE(HAVE_GETHOSTBYNAME_R, 1, [Define to 1 if you have the `gethostbyname_r' function.])
	],
	[AC_MSG_RESULT([no])]
)
AC_MSG_CHECKING([for HP-UX gethostbyname_r])
AC_TRY_LINK([#include <netdb.h>],
	[struct hostent result;
	 char buf[1024];
	 gethostbyname_r("localhost", &result, buf);
	],
	[AC_MSG_RESULT([yes])
	 AC_DEFINE(HAVE_GETHOSTBYNAME_R_HPUX, 1, [Using HPUX gethostbyname_r()])
	 AC_DEFINE(HAVE_GETHOSTBYNAME_R, 1, [Define to 1 if you have the `gethostbyname_r' function.])
	],
	[AC_MSG_RESULT([no])]
)

# Checks system services
AC_SYS_LARGEFILE

# Checks optional features.
AC_ARG_ENABLE([coverage],
	[AS_HELP_STRING([--enable-coverage],
		[build as code coverage mode @<:@default=no@:>@])],
	[enable_coverage=$enableval],
	[enable_coverage=no])

if test "$enable_coverage" = "yes"
then
	CFLAGS="$CFLAGS -fprofile-arcs -ftest-coverage"
	CXXFLAGS="$CXXFLAGS -fprofile-arcs -ftest-coverage"
	LDFLAGS="$LDFLAGS -lgcov"
fi

AC_ARG_ENABLE([debug],
	[AS_HELP_STRING([--enable-debug],
		[build as debug mode @<:@default=no (release mode)@:>@])],
	[enable_debug=$enableval],
	[enable_debug=no])

if test "$enable_debug" = "yes"
then
	CFLAGS="$CFLAGS -ggdb -fno-inline"
	CXXFLAGS="$CXXFLAGS -ggdb -fno-inline"
else
	CFLAGS="$CFLAGS -ggdb -O2 -DNDEBUG -finline-functions"
	CXXFLAGS="$CXXFLAGS -ggdb -O2 -DNDEBUG -finline-functions"
fi
AM_CONDITIONAL([BUILD_DEBUG], [test "$enable_debug" = "yes"])

AC_ARG_ENABLE([profile],
	[AS_HELP_STRING([--enable-profile],
		[build as profile mode @<:@default=no@:>@])],
	[enable_profile=$enableval],
	[enable_profile=no])

if test "$enable_profile" = "yes"
then
	CFLAGS="$CFLAGS -g -pg"
	CXXFLAGS="$CXXFLAGS -g -pg"
fi

WARN="-Wall -W -Wwrite-strings -Wno-cast-qual -Wmissing-prototypes -Wredundant-decls -Wextra -Wlong-long"
NOWARN="-Wno-unused"
CFLAGS="$CFLAGS $WARN $NOWARN"
CXXFLAGS="$CCCFLAGS $WARN $NOWARN"

AC_ARG_ENABLE([hoard],
	[AS_HELP_STRING([--enable-hoard],
		[enable to use Hoard as memory allocator @<:@default=no (C library)@:>@])],
	[enable_hoard=$enableval],
	[enable_hoard=no])

if test "$enable_hoard" = "yes"
then
	AC_CONFIG_SUBDIRS([external/hoard-371])
	SYS_DEFS="$SYS_DEFS -DHOARD"
	SYS_LIBS="$SYS_LIBS -L\$(top_builddir)/external/lib -lhoard -lstdc++ -ldl -lpthread"
fi

AC_ARG_WITH(jdk,
	AS_HELP_STRING([--with-jdk=DIR],
		       [JDK HOME you want to use @<:@default=check@:>@]),
	[JDK_HOME=${with_jdk}],
	[with_jdk=check])

AS_IF([test "x$with_jdk" != "xno"],
    [if test "x$with_jdk" = "xcheck"
    then
	AC_MSG_CHECKING(java home)
        if test "x$JAVA_HOME" != "x"
	then
	    JDK_HOME=$JAVA_HOME
	    JDK_BIN=$JAVA_HOME/bin
	    JAVAC=$JDK_BIN/javac
	else
	    AC_MSG_ERROR(set your JAVA_HOME enviroment variable.)
	    #AC_PATH_TOOL(JAVAC, javac, [AC_MSG_ERROR(Could not find javac in the PATH])
	    #JDK_BIN=`dirname $JAVAC`
	    #JDK_HOME=`dirname $JDK_BIN`
	fi
	AC_MSG_RESULT($JDK_HOME)
    else
	JAVA_HOME=$JDK_HOME
	JDK_BIN=$JDK_HOME/bin
	JAVAC=$JDK_BIN/javac
    fi

    if test -x $JDK_BIN/javac
    then
	JAVAC=$JDK_BIN/javac
    else
	AC_MSG_ERROR(javac not found at $JDK_HOME)
    fi

    AC_MSG_CHECKING(javac version)
    JAVAC_VERSION=`$JAVAC -version 2>&1|head -1|sed -e 's/.*javac \(.*\).*/\1/'`
    if test -n "$JAVAC_VERSION"
    then
	AC_MSG_RESULT($JAVAC_VERSION)
	if expr 1.4 ">" "$JAVAC_VERSION" > /dev/null
	then
	    AC_MSG_ERROR(Java 1.5 or later is required)
	fi

	if expr 1.6 "<=" "$JAVAC_VERSION" > /dev/null
	then
	    JDK6_DEFINE=-DJDK6
	fi
    else
	AC_MSG_ERROR(Java 1.5 or later is required)
    fi

    AC_CHECK_PROG(ANT, ant, ant)
    if test "x$ANT" == "x"
    then
      AC_MSG_ERROR(Ant was not found. check PATH or install ant)
    fi

    AC_CHECK_FILE($JDK_HOME/include/jni.h,[JAVA_INC="-I$JDK_HOME/include"],
		  AC_MSG_ERROR(jni.h is required.))
    case ${host_os} in
      linux*)
	    mddir="linux";;
      solaris*)
	    mddir="solaris";;
      *)
	    mddir=""
    esac
    AC_CHECK_FILE($JDK_HOME/include/$mddir/jni_md.h,
		  [JAVA_INC="$JAVA_INC -I$JDK_HOME/include/$mddir"],
		  AC_MSG_ERROR(jni_md.h is required.))

    AC_MSG_CHECKING([whether JNI programs can be compiled with $JAVA_INC])
    CFLAGS="$CFLAGS $JAVA_INC"
    AC_LINK_IFELSE([
#include <jni.h>
int main(void) { return 0; }
		   ],[AC_MSG_RESULT(yes)],
		   [AC_MSG_ERROR([Cannot compile a JNI program. See config.log for details.])])
    ],
    [SYS_DEFS="$SYS_DEFS -DDISABLE_JSP"])
AC_SUBST(JDK6_DEFINE)
AC_SUBST(JAVA_INC)
AC_SUBST(JAVA_HOME)

AC_ARG_WITH([libedit],
	AS_HELP_STRING([--with-libedit=PATH],
		[prefix for installed editline @<:@default=builtin@:>@]),
	[with_libedit=$withval],
	[with_libedit=builtin])

if test "$with_libedit" = "builtin"
then
	AC_CONFIG_SUBDIRS([external/libedit-20100424-3.0])
	LIBEDIT_LIBS="\$(top_builddir)/external/lib/libedit.la"
	LIBEDIT_INC="-I\$(top_builddir)/external/include"
else
	LIBEDIT_LIBS="-L$with_libedit/lib -ledit"
	LIBEDIT_INC="-I$with_libedit/include"
fi

AC_ARG_WITH([lzo2],
	AS_HELP_STRING([--with-lzo2=PATH],
		[prefix for installed LZO2 @<:@default=builtin@:>@]),
	[with_lzo2=$withval],
	[with_lzo2=builtin])

if test "$with_lzo2" = "builtin"
then
	AC_CONFIG_SUBDIRS([external/lzo-2.03])
	LZO_LIBS="\$(top_builddir)/external/lib/liblzo2.la"
	LZO_INC="-I\$(top_builddir)/external/include/lzo"
	LDFLAGS="$LDFLAGS $LZO_LIBS"
else
	LZO_LIBS="-L$with_lzo2/lib -llzo2"
	LZO_INC="-I$with_lzo2/include/lzo"
	LDFLAGS="$LDFLAGS $LZO_LIBS"
fi

AC_ARG_WITH([pcre],
	AS_HELP_STRING([--with-pcre=PATH],
		[prefix for installed PCRE @<:@default=builtin@:>@]),
	[with_pcre=$withval],
	[with_pcre=builtin])

if test "$with_pcre" = "builtin"
then
	AC_CONFIG_SUBDIRS([external/pcre-7.6])
	PCRE_LIBS="\$(top_builddir)/external/lib/libpcre.la"
	PCRE_INC="-I\$(top_builddir)/external/include"
else
	PCRE_LIBS="-L$with_pcre/lib -lpcre"
	PCRE_INC="-I$with_pcre/include"
fi

AC_ARG_WITH([gc],
	AS_HELP_STRING([--with-gc=PATH],
		[prefix for installed GC @<:@default=builtin@:>@]),
	[with_gc=$withval],
	[with_gc=builtin])

if test "$with_gc" = "builtin"
then
	AC_CONFIG_SUBDIRS([external/gc6.7])
	GC_LIBS="\$(top_builddir)/external/lib/libgc.la"
	GC_INC="-I\$(top_builddir)/external/include/gc"
else
	GC_LIBS="-L$with_gc/lib -lgc"
	GC_INC="-I$with_gc/include/gc"
fi

AC_ARG_WITH([aio],
	AS_HELP_STRING([--with-aio],
		[use aio]),
	[with_aio=$withval],
	[with_aio=no])

if test "$with_aio" = "yes"
then
	SYS_DEFS="$SYS_DEFS -DUSE_AIO"
	SYS_LIBS="$SYS_LIBS -lrt"
fi

AC_PREFIX_DEFAULT("$HOME/cubrid")

BUILD_NUMBER=`cat $srcdir/BUILD_NUMBER`
RELEASE_STRING=`echo $BUILD_NUMBER | sed -e "s|\.[[0-9]]*$||"`
MAJOR_RELEASE_STRING=`echo $RELEASE_STRING | sed -e "s|\.[[0-9]]*$||"`
MAJOR_VERSION=`echo $RELEASE_STRING | cut -d \. -f 1`
MINOR_VERSION=`echo $RELEASE_STRING | cut -d \. -f 2`
PATCH_NUMBER=`echo $RELEASE_STRING | cut -d \. -f 3`
BUILD_SERIAL_NUMBER=`echo $BUILD_NUMBER | cut -d \. -f 4`
#AC_SUBST(RELEASE_STRING)
#AC_SUBST(MAJOR_RELEASE_STRING)
#AC_SUBST(BUILD_NUMBER)
AC_SUBST(LT_VERSION,$MAJOR_VERSION:$MINOR_VERSION:$PATCH_NUMBER)

SERVER_DEFS="-DSERVER_MODE"
CS_DEFS="-DCS_MODE"
SA_DEFS="-DSA_MODE"
COMMON_DEFS="-DANSI=1 -DSYSV -DMAXPATHLEN=1024 -D_REENTRANT"
VERSION_DEFS="-DMAJOR_VERSION=$MAJOR_VERSION -DMINOR_VERSION=$MINOR_VERSION \
-DPATCH_NUMBER=$PATCH_NUMBER -DRELEASE_STRING=$RELEASE_STRING \
-DBUILD_SERIAL_NUMBER=$BUILD_SERIAL_NUMBER \
-DMAJOR_RELEASE_STRING=$MAJOR_RELEASE_STRING -DBUILD_NUMBER=$BUILD_NUMBER"

SRC_INC="-I\$(top_srcdir)/include"
DIR_LIST=`ls -l $srcdir/src | grep ^d | awk '{ print $9}'`
for D in $DIR_LIST
do
	SRC_INC="$SRC_INC -I\$(top_srcdir)/src/$D"
done

CUBRID_LIB="\$(top_builddir)/cubrid/libcubrid.la"
CS_LIB="\$(top_builddir)/cs/libcubridcs.la"
SA_LIB="\$(top_builddir)/sa/libcubridsa.la"
CAS_LIB="-L\$(top_builddir)/cas -lcas"
CCI_LIB="\$(top_builddir)/cas/libcascci.la"
ESQL_LIB="\$(top_builddir)/util/libcubridesql.la"
BROKER_ADMIN_LIB="\$(top_builddir)/broker/libbrokeradmin.la"

EXT_LIBS="$LIBEDIT_LIBS $LZO_LIBS $GC_LIBS"
EXT_INC="$LIBEDIT_INC $LZO_INC $GC_INC"

AC_MSG_CHECKING(whether to use CUBRID environment variable)
AC_ARG_ENABLE([cubridenv],
	AS_HELP_STRING([--enable-cubridenv],
		       [Using CUBRID environment variable @<:@default=yes@:>@]),
	[case "$enableval" in
	  yes)
	    ;;
	   no)
	    COMMON_DEFS="$COMMON_DEFS -DDO_NOT_USE_CUBRIDENV"
	    ;;
	  *)
	    AC_MSG_ERROR([bad value ${enableval} for --enable-cubridenv])
	    ;;
	  esac],
	  [enableval=yes])
AC_MSG_RESULT($enableval)
AM_CONDITIONAL([DISABLE_CUBRIDENV], [test "x$enableval" = "xno"])

# install dir
AC_MSG_CHECKING(for bindir)
AS_IF([test "$bindir" != '${exec_prefix}/bin'],
      [AC_MSG_ERROR(Do not use --bindir option ($bindir). It must be PREFIX/bin)])
AC_MSG_RESULT($bindir)

AC_MSG_CHECKING(for libdir)
AS_IF([test "$libdir" != '${exec_prefix}/lib'],
      [AC_MSG_ERROR(Do not use --libdir option ($libdir). It must be PREFIX/lib)])
AC_MSG_RESULT($libdir)

AC_MSG_CHECKING(for localstatedir)
#AS_IF([test "$localstatedir" != '${prefix}/var'],
#      [AC_MSG_ERROR(Do not use --localstatedir option ($localstatedir). It must be PREFIX/var)])
AC_MSG_RESULT($localstatedir)

DIR_DEFS="-DCUBRID_PREFIXDIR=\\\"\$(prefix)\\\" -DCUBRID_BINDIR=\\\"\$(bindir)\\\" -DCUBRID_LIBDIR=\\\"\$(libdir)\\\" -DCUBRID_VARDIR=\\\"\$(localstatedir)\\\""

AC_MSG_CHECKING(for confdir)
AC_ARG_WITH([confdir],
	AS_HELP_STRING([--with-confdir=PATH],
		       [Directory containing configuration files @<:@default=PREFIX/conf@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need CONFDIR.)
	    ;;
	  yes)
	    CUBRID_CONFDIR="\$(prefix)/conf"
	    ;;
	  *)
	    CUBRID_CONFDIR="$withval"
	    ;;
	  esac],
	[CUBRID_CONFDIR="\$(prefix)/conf"])
AC_MSG_RESULT($CUBRID_CONFDIR)

DIR_DEFS="$DIR_DEFS -DCUBRID_CONFDIR=\\\"$CUBRID_CONFDIR\\\""

AC_MSG_CHECKING(for jspdir)
AC_ARG_WITH([jspdir],
	AS_HELP_STRING([--with-jspdir=PATH],
		       [Directory containing JSP server files @<:@default=PREFIX/java@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need JSPDIR.)
	    ;;
	  yes)
	    CUBRID_JAVADIR="\$(prefix)/java"
	    ;;
	  *)
	    CUBRID_JAVADIR="$withval"
	    ;;
	  esac],
	[CUBRID_JAVADIR="\$(prefix)/java"])
AC_MSG_RESULT($CUBRID_JAVADIR)

DIR_DEFS="$DIR_DEFS -DCUBRID_JAVADIR=\\\"$CUBRID_JAVADIR\\\""

AC_MSG_CHECKING(for jdbcdir)
AC_ARG_WITH([jdbcdir],
	AS_HELP_STRING([--with-jdbcdir=PATH],
		       [Directory containing JDBC files @<:@default=PREFIX/jdbc@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need JDBCDIR.)
	    ;;
	  yes)
	    CUBRID_JDBCDIR="\$(prefix)/ndbc"
	    ;;
	  *)
	    CUBRID_JDBCDIR="$withval"
	    ;;
	  esac],
	[CUBRID_JDBCDIR="\$(prefix)/jdbc"])
AC_MSG_RESULT($CUBRID_JDBCDIR)

DIR_DEFS="$DIR_DEFS -DCUBRID_JDBCDIR=\\\"$CUBRID_JDBCDIR\\\""

AC_MSG_CHECKING(for demodir)
AC_ARG_WITH([demodir],
	AS_HELP_STRING([--with-demodir=PATH],
		       [Directory containing demo files @<:@default=PREFIX/demo@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need DEMODIR.)
	    ;;
	  yes)
	    CUBRID_DEMODIR="\$(prefix)/ndbc"
	    ;;
	  *)
	    CUBRID_DEMODIR="$withval"
	    ;;
	  esac],
	[CUBRID_DEMODIR="\$(prefix)/demo"])
AC_MSG_RESULT($CUBRID_DEMODIR)

AC_MSG_CHECKING(for msgdir)
AC_ARG_WITH([msgdir],
	AS_HELP_STRING([--with-msgdir=PATH],
		       [Directory containing message files @<:@default=PREFIX/msg@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need MSGDIR.)
	    ;;
	  yes)
	    CUBRID_LOCALEDIR="\$(prefix)/msg"
	    ;;
	  *)
	    CUBRID_LOCALEDIR="$withval"
	    ;;
	  esac],
	[CUBRID_LOCALEDIR="\$(prefix)/msg"])
AC_MSG_RESULT($CUBRID_LOCALEDIR)
DIR_DEFS="$DIR_DEFS -DCUBRID_LOCALEDIR=\\\"$CUBRID_LOCALEDIR\\\""

AC_MSG_CHECKING(for compatdir)
AC_ARG_WITH([compatdir],
	AS_HELP_STRING([--with-compatdir=PATH],
		       [Directory containing compatibility files @<:@default=PREFIX/compat@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need COMPATDIR.)
	    ;;
	  yes)
	    CUBRID_COMPATDIR="\$(prefix)/compat"
	    ;;
	  *)
	    CUBRID_COMPATDIR="$withval"
	    ;;
	  esac],
	[CUBRID_COMPATDIR="\$(prefix)/compat"])
AC_MSG_RESULT($CUBRID_COMPATDIR)

AC_MSG_CHECKING(for logdir)
AC_ARG_WITH([logdir],
	AS_HELP_STRING([--with-logdir=PATH],
		       [Directory containing log files @<:@default=PREFIX/log@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need LOGDIR.)
	    ;;
	  yes)
	    CUBRID_LOGDIR="\$(prefix)/log"
	    ;;
	  *)
	    CUBRID_LOGDIR="$withval"
	    ;;
	  esac],
	[CUBRID_LOGDIR="\$(prefix)/log"])
AC_MSG_RESULT($CUBRID_LOGDIR)
DIR_DEFS="$DIR_DEFS -DCUBRID_LOGDIR=\\\"$CUBRID_LOGDIR\\\""

AC_MSG_CHECKING(for tmpdir)
AC_ARG_WITH([tmpdir],
	AS_HELP_STRING([--with-tmpdir=PATH],
		       [Directory containing temporary files @<:@default=PREFIX/tmp@:>@]),
	[case "$withval" in
	   no)
	    AC_MSG_ERROR(Need TMPDIR.)
	    ;;
	  yes)
	    CUBRID_TMPDIR="\$(prefix)/tmp"
	    ;;
	  *)
	    CUBRID_TMPDIR="$withval"
	    ;;
	  esac],
	[CUBRID_TMPDIR="\$(prefix)/tmp"])
AC_MSG_RESULT($CUBRID_TMPDIR)
DIR_DEFS="$DIR_DEFS -DCUBRID_TMPDIR=\\\"$CUBRID_TMPDIR\\\""

AC_ARG_WITH([mysql],
	AS_HELP_STRING([--with-mysql=PATH],
		[for CAS for MySQL @<:@default=no@:>@]),
	[with_mysql=$withval],
	[with_mysql=no])

if test "$with_mysql" != "no"
then
	MYSQL_LIB_PATH="-L$with_mysql/lib"
	MYSQL_INC_PATH="-I$with_mysql/include"
fi
AM_CONDITIONAL([BUILD_CAS_FOR_MYSQL], [test "$with_mysql" != "no"])

AC_ARG_WITH([oracle],
	AS_HELP_STRING([--with-oracle=PATH],
		[for CAS for Oracle @<:@default=no@:>@]),
	[with_oracle=$withval],
	[with_oracle=no])

if test "$with_oracle" != "no"
then
	ORACLE_LIB_PATH="-L$with_oracle/lib"
	ORACLE_INC_PATH="-I$with_oracle/include"
fi
AM_CONDITIONAL([BUILD_CAS_FOR_ORACLE], [test "$with_oracle" != "no"])

AC_SUBST([BUILD_NUMBER])
AC_SUBST([SYS_DEFS])
AC_SUBST([SYS_LIBS])
AC_SUBST([EXT_LIBS])
AC_SUBST([EXT_INC])
AC_SUBST([SERVER_DEFS])
AC_SUBST([CS_DEFS])
AC_SUBST([SA_DEFS])
AC_SUBST([COMMON_DEFS])
AC_SUBST([VERSION_DEFS])
AC_SUBST([SRC_INC])
AC_SUBST([CUBRID_LIB])
AC_SUBST([CS_LIB])
AC_SUBST([SA_LIB])
AC_SUBST([CAS_LIB])
AC_SUBST([CCI_LIB])
AC_SUBST([ESQL_LIB])
AC_SUBST([BROKER_ADMIN_LIB])
AC_SUBST([BIT_MODEL])
AC_SUBST([DIR_DEFS])
AC_SUBST([CUBRID_CONFDIR])
AC_SUBST([CUBRID_JAVADIR])
AC_SUBST([CUBRID_JDBCDIR])
AC_SUBST([CUBRID_DEMODIR])
AC_SUBST([CUBRID_LOCALEDIR])
AC_SUBST([CUBRID_COMPATDIR])
AC_SUBST([CUBRID_LOGDIR])
AC_SUBST([CUBRID_TMPDIR])
AC_SUBST([MYSQL_LIB_PATH])
AC_SUBST([MYSQL_INC_PATH])
AC_SUBST([ORACLE_LIB_PATH])
AC_SUBST([ORACLE_INC_PATH])

AH_TOP([
#ifndef _CONFIG_H_
#define _CONFIG_H_
])
AH_BOTTOM([
#include "system.h"
#endif /* _CONFIG_H_ */
])

AC_CONFIG_FILES([Makefile
	cas/Makefile
	broker/Makefile
	cm_common/Makefile
	include/Makefile
	sa/Makefile
	cubrid/Makefile
	cs/Makefile
	util/Makefile
	conf/Makefile
	msg/Makefile
	msg/en_US/Makefile
	msg/ko_KR.euckr/Makefile
	msg/ko_KR.utf8/Makefile
	msg/zh_CN.gb2312/Makefile
	msg/zh_CN.utf8/Makefile
	log/Makefile
	demo/Makefile
	contrib/Makefile
	jdbc/Makefile
	java/Makefile
	cas4mysql/Makefile
	cas4oracle/Makefile
	])

AC_OUTPUT
