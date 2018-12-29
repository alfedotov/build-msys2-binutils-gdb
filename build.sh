#!/bin/bash

build_lib () {
  # Arguments are:
  # Library name
  local lib=$1
  local version=$2
  local CONFIGENV=""

  echo "Building ${lib} separately:"

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

  cd ../
  echo 
}

build_zlib () {
  # Arguments are:
  # Library name
  local lib=$1
  local version=$2
 
  echo "Building zlib separately:"

  cp -r ../src/${lib}-${version}/ ${lib}-${version}-build
  cd ${lib}-${version}-build

  echo "  Building ${lib}" 
  make -f win32/Makefile.gcc > ${LOGS}/${lib}.build 2>&1
  
  echo "  Installing ${lib}"  
  make -f win32/Makefile.gcc install INCLUDE_PATH=${WHOSTLIBINST}/usr/include BINARY_PATH=${WHOSTLIBINST}/usr/bin LIBRARY_PATH=${WHOSTLIBINST}/usr/lib > ${LOGS}/${lib}.install 2>&1

  cd ../
  echo 
}


build_gdb () {
  local CONFIGENV="LDFLAGS=-L$WHOSTLIBINST/usr/lib CPPFLAGS=-I${WHOSTLIBINST}/usr/include"
  
  local version=$1
  
  cfg="--prefix ${PREFIX}/gdb-${GDB_VERSION} \
       --with-libexpat-prefix=${WHOSTLIBINST}/usr \
       --target ${TRPTARGET} \
       --disable-nls \
       --disable-shared \
       --enable-static \
       --disable-sim \
       --disable-tui"
  
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
  ../../src/gdb-$version/configure $cfg ${CONFIGENV} > ${LOGS}/gdb-$version.config 2>&1

  echo "  Building..."
  make all > ${LOGS}/gdb-$version.build 2>&1
  
  echo "  Installing..." 
  make install > ${LOGS}/gdb-$version.install 2>&1
  

  echo 
  cd ../

}

################################################################################
# Program entry point
################################################################################
GDB_VERSION="7.12.1"
EXPAT_VERSION="2.2.6"
ZLIB_VERSION="1.2.11"
TERMCAP_VERSION="1.3.1"
LIBICONV_VERSION="1.15"
LIBLZMA_VERSION="5.2.4"

TRPTARGET="arm-none-eabi"
TRPHOST="x86_64-w64-mingw32"

WORKDIR=`pwd`
BUILDDIR="build"

PREFIX=${WORKDIR}/opt/
WHOSTLIBINST=${WORKDIR}/${BUILDDIR}/mingw32_host_libs
LOGS=${WORKDIR}/${BUILDDIR}/logs

if [ ! -d ${LOGS} ]; then
  mkdir ${LOGS}
fi

pushd ${BUILDDIR} > /dev/null 2>&1

  #build_lib expat ${EXPAT_VERSION}
  #build_lib termcap ${TERMCAP_VERSION}
  #build_lib libiconv ${LIBICONV_VERSION}
  #build_lib xz ${LIBLZMA_VERSION}
  #build_zlib zlib ${ZLIB_VERSION}


  INSTALL_DIR=${PREFIX}/gdb-${GDB_VERSION}
  build_gdb $GDB_VERSION
  
  #copy required MinGW library
  if [ -d $INSTALL_DIR/bin ]; then
    cp -f /c/msys64/mingw64/bin/libwinpthread-1.dll $INSTALL_DIR/bin
  fi

  
  
  #GDB_VERSION="8.2.1"
  #
  #INSTALL_DIR=${PREFIX}/gdb-${GDB_VERSION}
  #build_gdb $GDB_VERSION
  #
  ##copy required MinGW library
  #if [ -d $INSTALL_DIR/bin ]; then
  #  cp -f /c/msys64/mingw64/bin/libwinpthread-1.dll $INSTALL_DIR/bin
  #fi


popd > /dev/null 2>&1

echo "Done"
