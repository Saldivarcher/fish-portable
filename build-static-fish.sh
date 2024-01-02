#!/bin/sh

export CC=cc
export REALCC=${CC}
export CPPFLAGS="-P"
export LDFLAGS="-static"

# ANSI Color Codes
RED="\033[0;31m"
GREEN="\033[0;32m"
#YELLOW="\033[0;33m"
BLUE="\033[0;34m"
COLOR_END="\033[0m"

# Program basename
PGM="${0##*/}" # Program basename

# Scriptversion
VERSION=3.7.0

# How many lines of the error log should be displayed
LOG_LINES=50

# os and pocessor architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

# sigh, in linux some use "x86_64", "aarch64"
# and others "amd64" or "arm64" the upx developers 
case "$(uname -m)" in
    "aarch64")
        ARCH="arm64"
        ;;
    "x86_64")
        ARCH="amd64"
        ;;
    *)
        ARCH=$(uname -m)
        ;;
esac

FISH_BIN="fish.${OS}-${ARCH}"

######################################
###### BEGIN VERSION DEFINITION ######
######################################
FISH_VERSION=3.7.0
NCURSES_VERSION=6.4
######################################
####### END VERSION DEFINITION #######
######################################

FISH_STATIC_HOME="/tmp/fish-static"

LOG_DIR="${FISH_STATIC_HOME}/log"

FISH_ARCHIVE="fish-${FISH_VERSION}.tar.xz"
FISH_URL="https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}"

NCURSES_ARCHIVE="ncurses-6.4.tar.gz"
NCURSES_URL="https://ftp.gnu.org/pub/gnu/ncurses/"

#
# decipher the programm arguments
#
get_args()
{
    while getopts "hcd" option
    do
        case $option in
            h)
                usage
                exit 0
                ;;
            c)
		USE_UPX=1
                ;;
            d)
		DUMP_LOG_ON_ERROR=1
                ;;
            '')
                ;;
            *)
                echo ""
                usage_options
                exit 1
                ;;
        esac
    done
    shift $((OPTIND - 1))
}

#
# print valid options
#
usage_options()
{
    printf "\t%s\n" "The following options are available:"
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-c${COLOR_END}" "compress the resulting binary with UPX."
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-d${COLOR_END}" "dump the log of the current buildstep to stdout if an error occurs."
    echo ""
    printf "\t%b\t%s\n" "${BLUE}-h${COLOR_END}" "print this help message."
    echo ""
}
#
# print the usage message
#
usage()
{
    exec >&2
    echo   ""
    echo "NAME"
    printf "\t%b - %s\n" "${BLUE}${PGM}${COLOR_END}" "build a static FISH release"
    echo   ""
    echo   "SYNOPSIS"
    printf "\t%b" "${BLUE}${PGM} [-h | -c -d]${COLOR_END}\n"
    echo ""
    echo   "DESCRIPTION"
    usage_options
    echo "ENVIRONMENT"
    printf "\t%b\n" "The following environment variables affect the execution of ${BLUE}${PGM}${COLOR_END}"
    echo ""
    printf "\t%s\t\t\t%b\n" "USE_UPX" "set to \"1\" to compress the resulting binary with UPX (see argument ${BLUE}-c${COLOR_END} above)."
    echo ""
    printf "\t%s\t%b\n" "DUMP_LOG_ON_ERROR" "set to \"1\" to dump the log of the current buildstep to stdout if an error occurs (see argument ${BLUE}-d${COLOR_END} above)."
    echo ""
    printf "\t%s\n" "In case you are behind a proxy, export these environment variables to download the necessary files:"
    printf "\t%s\t%b\n" "http_proxy|HTTP_PROXY" "e.g. \"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\""
    printf "\t%s\t%b\n" "https_proxy|HTTPS_PROXY" "e.g. \"http://<username>:<password>@<Proxy_DNS_or_IP_address>:<Port>/\""
    echo ""
    echo "EXIT STATUS"
    printf "\t%b\n" "The ${BLUE}${PGM}${COLOR_END} utility exits 0 on success, and >0 if an error occurs."
    echo ""
    echo "VERSION"
    printf "\t%s\n" "${VERSION}"
    echo ""
}

#
# check the returncode of the last programm
# and print a nice status message
#
checkResult ()
{
    if [ "$1" -eq 0 ]; then
        printf "%b\n" "${GREEN}[OK]${COLOR_END}"
    else
        printf "%b\n" "${RED}[ERROR]${COLOR_END}"
        echo ""
        if [ ${DUMP_LOG_ON_ERROR} = 0 ]; then
            echo "Check Buildlog in ${LOG_DIR}/${LOG_FILE}"
            cat ${LOG_DIR}/${LOG_FILE}
        else
            echo "last ${LOG_LINES} from ${LOG_DIR}/${LOG_FILE}:"
            echo "-----------------------------------------------"
            echo "..."
            if [ -f "${LOG_DIR}/${LOG_FILE}" ]; then
                tail -n ${LOG_LINES} "${LOG_DIR}/${LOG_FILE}"
            else
                echo "Oops, logfile ${LOG_DIR}/${LOG_FILE} not found, something gone wrong!"
            fi
            echo ""
            echo "-------------"
            printf "%b\n" "${RED}build aborted${COLOR_END}"
            echo ""
        fi
        exit $1
    fi
}

# print the last x lines of the log to stdout
DUMP_LOG_ON_ERROR=${DUMP_LOG_ON_ERROR:-0}

get_args "$@"

clear

# create directories initially
[ ! -d ${FISH_STATIC_HOME} ]         && mkdir ${FISH_STATIC_HOME}
[ ! -d ${FISH_STATIC_HOME}/src ]     && mkdir ${FISH_STATIC_HOME}/src
[ ! -d ${FISH_STATIC_HOME}/lib ]     && mkdir ${FISH_STATIC_HOME}/lib
[ ! -d ${FISH_STATIC_HOME}/bin ]     && mkdir ${FISH_STATIC_HOME}/bin
[ ! -d ${FISH_STATIC_HOME}/include ] && mkdir ${FISH_STATIC_HOME}/include
[ ! -d ${LOG_DIR} ]                  && mkdir ${LOG_DIR}

# Clean up #
printf "%b\n" "${BLUE}Cleaning up...${COLOR_END}"
rm -rf ${FISH_STATIC_HOME:?}/include/*
rm -rf ${FISH_STATIC_HOME:?}/lib/*
rm -rf ${FISH_STATIC_HOME:?}/bin/*
rm -rf ${LOG_DIR:?}/*

rm -rf ${FISH_STATIC_HOME:?}/src/ncurses-${NCURSES_VERSION}
rm -rf ${FISH_STATIC_HOME:?}/src/fish-${FISH_VERSION}

echo ""
echo "current settings"
echo "----------------"
echo "USE_UPX:           ${USE_UPX}"
echo "DUMP_LOG_ON_ERROR: ${DUMP_LOG_ON_ERROR}"
echo "LOG_LINES:         ${LOG_LINES}"

echo ""
printf "%b\n" "${BLUE}*********************************************${COLOR_END}"
printf "%b\n" "${BLUE}** Starting to build a static FISH release **${COLOR_END}"
printf "%b\n" "${BLUE}*********************************************${COLOR_END}"

TIME_START=$(date +%s)
export PKG_CONFIG_PATH=${FISH_STATIC_HOME}/lib/pkgconfig


###############################################################
echo ""
echo "ncurses ${NCURSES_VERSION}"
echo "------------------"

LOG_FILE="ncurses-${NCURSES_VERSION}.log"

cd ${FISH_STATIC_HOME}/src || exit 1
if [ ! -f ${NCURSES_ARCHIVE} ]; then
    printf "Downloading..."
    wget --no-verbose ${NCURSES_URL}/${NCURSES_ARCHIVE} > ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

printf "Extracting...."
tar xzf ${NCURSES_ARCHIVE}
checkResult $?

cd ncurses-${NCURSES_VERSION} || exit 1

printf "Configuring..."
./configure \
    --prefix=/usr \
    --includedir=/usr/include \
    --libdir=/usr/lib \
    --without-ada \
    --without-tests \
    --without-manpages \
    --with-ticlib \
    --with-termlib \
    --with-default-terminfo-dir=/usr/share/terminfo \
    --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Compiling....."
make -j`nproc` >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

###############################################################
echo ""
echo "fish ${FISH_VERSION}"
echo "------------------"

LOG_FILE="fish-${FISH_VERSION}.log"

cd ${FISH_STATIC_HOME}/src || exit 1
if [ ! -f ${FISH_ARCHIVE} ]; then
    printf "Downloading..."
    wget --no-verbose ${FISH_URL}/${FISH_ARCHIVE} > ${LOG_DIR}/${LOG_FILE} 2>&1
    checkResult $?
fi

printf "Extracting...."
tar xf ${FISH_ARCHIVE}
checkResult $?

cd fish-${FISH_VERSION} || exit 1

printf "Configuring..."

patch -p1 -i /tmp/enable-static-linking.patch
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=${FISH_STATIC_HOME} -DCMAKE_BUILD_TYPE=Release .. && make -j`nproc` && make install

checkResult $?

# patch file.c
sed -i 's|#include <sys/queue.h>||g' file.c

printf "Compiling....."
make >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

printf "Installing...."
make install >> ${LOG_DIR}/${LOG_FILE} 2>&1
checkResult $?

###############################################################

cd ${FISH_STATIC_HOME} || exit 1

echo ""
echo "Tar'ing directory...:"
echo "----------------"
echo "${FISH_STATIC_HOME}"

tar --exclude=${FISH_STATIC_HOME}/src/* -zcvf /tmp/fish-static.${OS}-${ARCH}.tar.gz ${FISH_STATIC_HOME}

echo ""
echo "----------------------------------------"
TIME_END=$(date +%s)
TIME_DIFF=$((TIME_END - TIME_START))
echo "Duration: $((TIME_DIFF / 3600))h $(((TIME_DIFF / 60) % 60))m $((TIME_DIFF % 60))s"
echo ""

