#!/bin/bash

untar_any () {
  # Function to untar any file format

  # Arguments are:
  local tar=$1

  file=`basename $tar`

  if [ -f $tar ] ; then
    echo "    unpacking $file"
    case $file in
      *.tar.bz2)  tar -xjf $tar    ;;
      *.tar.gz)   tar -xzf $tar    ;;
      *.tar.xz)   tar -xJf $tar    ;;
      *.bz2)      bunzip2 $tar     ;;
      *.gz)       gunzip $tar      ;;
      *.tar)      tar -xf $tar     ;;
      *.tbz2)     tar -xjf $tar    ;;
      *.tgz)      tar -xzf $tar    ;;
      *.zip)      unzip $tar       ;;
      *.Z)        uncompress $tar  ;;
      *.rar)      rar x $tar       ;;
      *)
        echo "Error: '$file' can't be extracted via untar_any()"
        ;;
    esac
  else
      echo "Error: file '$tar' doesn't exist."
  fi

}

insist_pkg () {
  # Function to try to find pkg in any possible compression type

  # Arguments are:
  # Package name
  local pkg=$1
  # package extension
  local forced_ext=$2

  local extensions="tar.xz txz tar.gz tgz tar.bz2"

  if [ "$forced_ext" != "" ]; then extensions=$forced_ext; fi

  for e in $extensions; do
    if [ -f $pkg.$e ]; then PKG="$pkg.$e"; return 0; fi
  done
  return 1
}

insist_wget () {
  # Function to try to wget something in any possible compression type

  # Arguments are:
  # Package name
  local pkg=$1
  # url address
  local url=$2
  # package extension
  local forced_ext=$3

  local extensions="tar.xz tar.gz txz tgz tar.bz2"

  if [ "$forced_ext" != "" ]; then extensions=$forced_ext; fi

  PKG=""
  insist_pkg "$pkg" "$forced_ext"

  if [ "$PKG" = "" ]; then
    echo "  Downloading $pkg"
    for e in $extensions; do
      wget -q $url/$pkg.$e
      if [ $? = 0 ]; then
        PKG="$pkg.$e";
        return 0;
      fi
    done
  else
    echo "  Package $pkg exists."
  fi

}

get_sources () {
  local pkg=$1

  case $pkg in
    binutils-2*)
      insist_wget "$pkg" "ftp://sourceware.org/pub/binutils/releases"
      ;;
    gdb-*)
      insist_wget "$pkg" "ftp://ftp.gnu.org/gnu/gdb"
      ;;
    zlib-*)
      insist_wget "$pkg" "http://www.zlib.net"
      ;;
    libiconv-*)
      insist_wget "$pkg" "http://ftp.gnu.org/pub/gnu/libiconv"
      ;;
    expat-*)
      insist_wget "$pkg" "http://downloads.sourceforge.net/expat/"
      ;;
    termcap-*)
      insist_wget "$pkg" "https://ftp.gnu.org/gnu/termcap/"
      ;;
    xz-*)
      insist_wget "$pkg" "https://tukaani.org/xz/"
      ;;
  esac


  if [ "$PKG" != "" ]; then
    pushd ${WORKDIR}/${SRCDIR} > /dev/null 2>&1
      untar_any "${WORKDIR}/${PKGDIR}/$PKG"
    popd > /dev/null 2>&1
  fi

}


build_lib () {
  # Arguments are:
  # Library name
  local lib=$1
  local version=$2
  local CONFIGENV=""

  echo "Building ${lib} separately:"

  if [ "${lib}" == "zlib" ]; then
    #zlib has different build process (TBD: check this later)
    cp -r ../src/${lib}-${version}/ ${lib}-${version}-build
    cd ${lib}-${version}-build

    echo "  Building ${lib}"
    make -f win32/Makefile.gcc > ${LOGS}/${lib}.build 2>&1

    echo "  Installing ${lib}"
    make -f win32/Makefile.gcc install INCLUDE_PATH=${WHOSTLIBINST}/usr/include BINARY_PATH=${WHOSTLIBINST}/usr/bin LIBRARY_PATH=${WHOSTLIBINST}/usr/lib > ${LOGS}/${lib}.install 2>&1
  else
    #all other libs which follow standard "configure/build/install" sequence
    if [ ! -d ${lib}-${version}-build ]; then
      mkdir ${lib}-${version}-build
    fi

    cd ${lib}-${version}-build

    echo "  Configuring ${lib}"
    ../../src/${lib}-${version}/configure --prefix=${WHOSTLIBINST}/usr --disable-shared --disable-nls ${CONFIGENV} > ${LOGS}/${lib}.config 2>&1

    echo "  Building ${lib}"
    make all > ${LOGS}/${lib}.build 2>&1

    echo "  Installing ${lib}"
    make install > ${LOGS}/${lib}.install 2>&1
  fi

  cd ../
  echo
}


build_gdb () {
  local DBGBUILD="-O0 -g3"
  local CONFIGENV="CFLAGS=\"$DBGBUILD\" LDFLAGS=-L$WHOSTLIBINST/usr/lib CPPFLAGS=-I${WHOSTLIBINST}/usr/include"

  local version=$1

  cfg="--prefix ${WORKDIR}/${INSTALLDIR}/gdb-${GDB_VERSION} \
       --with-libexpat-prefix=${WHOSTLIBINST}/usr \
       --target ${TRPTARGET} \
       --disable-nls \
       --disable-shared \
       --enable-static \
       --disable-gas \
       --disable-binutils \
       --disable-ld \
       --disable-gprof \
       --disable-werror \
       --disable-test \
       --disable-guile \
       --without-guile \
       --disable-sim \
       --disable-tui \
       --with-python=no"

  case "gdb-${version}" in
    gdb-8.*)
      # In the case of gdb 8.0, you have to also add the --disable-interprocess-agent to successfully build a static version
      cfg+=" --disable-interprocess-agent"
      ;;
    gdb-7.12*)
      ;;
  esac


  echo "Building gdb-$version:"

  if [ ! -d gdb-$version-build ]; then
    mkdir gdb-$version-build
  fi

  cd gdb-$version-build

  rm -rf *

  echo "  Configuring..."
  eval ${CONFIGENV} ../../src/gdb-$version/configure $cfg > ${LOGS}/gdb-$version.config 2>&1

  echo "  Building..."
  make all > ${LOGS}/gdb-$version.build 2>&1

  echo "  Installing..."
  make install > ${LOGS}/gdb-$version.install 2>&1


  echo
  cd ../

}


build_binutils () {
  local DBGBUILD="-O0 -g3"
  local CONFIGENV="CFLAGS=\"$DBGBUILD\" LDFLAGS=-L$WHOSTLIBINST/usr/lib CPPFLAGS=-I${WHOSTLIBINST}/usr/include"

  local version=$1

  cfg="--prefix ${WORKDIR}/${INSTALLDIR}/binutils-${BINUTILS_VERSION} \
       --with-libexpat-prefix=${WHOSTLIBINST}/usr \
       --target ${TRPTARGET} \
       --disable-nls \
       --disable-shared \
       --enable-static \
       --disable-gdb \
       --disable-gprof \
       --disable-werror \
       --disable-test \
       --disable-guile \
       --without-guile \
       --disable-sim \
       --disable-tui \
       --with-python=no"


  echo "Building bintuils-$version:"

  if [ ! -d binutils-$version-build ]; then
    mkdir binutils-$version-build
  fi

  cd binutils-$version-build

  rm -rf *

  echo "  Configuring..."
  eval ${CONFIGENV} ../../src/binutils-$version/configure $cfg > ${LOGS}/binutils-$version.config 2>&1

  echo "  Building..."
  make all > ${LOGS}/binutils-$version.build 2>&1

  echo "  Installing..."
  make install > ${LOGS}/binutils-$version.install 2>&1


  echo
  cd ../

}


################################################################################
# Program entry point
################################################################################
BINUTILS_VERSION="2.34"
GDB_VERSION="7.12.1"
EXPAT_VERSION="2.2.6"
ZLIB_VERSION="1.2.11"
TERMCAP_VERSION="1.3.1"
LIBICONV_VERSION="1.15"
LIBLZMA_VERSION="5.2.4"

TRPTARGET="arm-none-eabi"
#TRPTARGET="powerpc-eabivle"
TRPHOST="x86_64-w64-mingw32"

WORKDIR=`pwd`

PKGDIR="pkg"
SRCDIR="src"
BUILDDIR="build"
INSTALLDIR="opt"


WHOSTLIBINST=${WORKDIR}/${BUILDDIR}/mingw32_host_libs
LOGS=${WORKDIR}/${BUILDDIR}/logs

if [ ! -d ${BUILDDIR} ]; then
  mkdir ${BUILDDIR}
fi

if [ ! -d ${LOGS} ]; then
  mkdir ${LOGS}
fi

echo "Building for target: ${TRPTARGET}"
echo

## Prepare sources directory
if [ ! -d ${SRCDIR} ]; then
  mkdir ${SRCDIR}
fi
if [ ! -d ${PKGDIR} ]; then
  mkdir ${PKGDIR}
fi
pushd ${PKGDIR} > /dev/null 2>&1
  get_sources binutils-${BINUTILS_VERSION}
  get_sources gdb-${GDB_VERSION}
  get_sources expat-${EXPAT_VERSION}
  get_sources termcap-${TERMCAP_VERSION}
  get_sources libiconv-${LIBICONV_VERSION}
  get_sources xz-${LIBLZMA_VERSION}
  get_sources zlib-${ZLIB_VERSION}
  echo
popd > /dev/null 2>&1

## Build stuff
pushd ${BUILDDIR} > /dev/null 2>&1
  build_lib expat ${EXPAT_VERSION}
  build_lib termcap ${TERMCAP_VERSION}
  build_lib libiconv ${LIBICONV_VERSION}
  build_lib xz ${LIBLZMA_VERSION}
  build_lib zlib ${ZLIB_VERSION}

  build_binutils ${BINUTILS_VERSION}
  build_gdb ${GDB_VERSION}
popd > /dev/null 2>&1

#copy required MinGW library
if [ -d ${WORKDIR}/${INSTALLDIR}/gdb-${GDB_VERSION}/bin ]; then
  cp -f /c/msys64/mingw64/bin/libwinpthread-1.dll ${WORKDIR}/${INSTALLDIR}/gdb-${GDB_VERSION}/bin
fi

if [ -d ${WORKDIR}/${INSTALLDIR}/binutils-${BINUTILS_VERSION}/bin ]; then
  cp -f /c/msys64/mingw64/bin/libwinpthread-1.dll ${WORKDIR}/${INSTALLDIR}/binutils-${BINUTILS_VERSION}/bin
fi

echo "Done"
