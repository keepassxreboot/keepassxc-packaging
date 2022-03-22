#!/usr/bin/env bash
#
# KeePassXC Release Preparation Helper
# Copyright (C) 2017 KeePassXC team <https://keepassxc.org/>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 or (at your option)
# version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

printf "\e[1m\e[32mKeePassXC\e[0m PPA Build Helper\n"
printf "Copyright (C) 2017 KeePassXC Team <https://keepassxc.org/>\n\n"

# variable defaults
UBUNTU_VERSION="1"
PPA_VERSION="ppa1"
SERIES_VERSION="1"
PACKAGE="keepassxc"
URGENCY="medium"
GPG_KEY="BF5A669F2272CF4324C1FDA8CFB4C2166397D0D2"

export DEBEMAIL=team@keepassxc.org
export DEBFULLNAME=KeePassXC Team

printStatus() {
    printf "\e[1m\e[34m${1}\e[0m\n"
}

printError() {
    printf "\e[91m${1}\e[0m\n" >&2
}

printUsage() {
    local cmd
    if [ "" == "$1" ] || [ "help" == "$1" ]; then
        cmd="COMMAND"
    elif [ "build" == "$1" ] || [ "upload" == "$1" ] || [ "clean" == "$1" ]; then
        cmd="$1"
    else
        printError "Unknown command: '$1'\n"
        cmd="COMMAND"
    fi

    printf "\e[1mUsage:\e[0m $(basename $0) $cmd [options]\n"

    if [ "COMMAND" == "$cmd" ]; then
        cat << EOF

Commands:
  build      Build source package
  upload     Upload source package to Launchpad PPA
  clean      Clean up build files
EOF
    elif [ "build" == "$cmd" ]; then
        cat << EOF

Build source packages which can be uploaded as PPA to Launchpad

Options:
  -s, --series           Ubuntu release series to build (required)
  -p, --package          Package name to build (required, default: '${PACKAGE}')
  -V, --upstream-version Upstream package version (required)
  -x, --ubuntu-version   Ubuntu package version (required, default: '${UBUNTU_VERSION}')
  -v, --ppa-version      PPA package version (default: '${PPA_VERSION}')
  -r, --series-version   PPA series package version (default: '${SERIES_VERSION}')
  -d, --docker-img       Ubuntu Docker image to use
  -c, --changelog        CHANGELOG file
  -u, --urgency          Package urgency (default: '${URGENCY}')
  -k, --gpg-key          GPG key used to sign package (default: '${GPG_KEY}')
      --upload           Immediately upload package
EOF
    elif [ "upload" == "$cmd" ]; then
        cat << EOF
Upload source previously built source package to Launchpad PPA

Options:
  -s, --series        Ubuntu release series to build (required)
  -p, --package       Package name to build (required, default: 'keepassxc')
  -v, --version       Full package version (required)
  -d, --docker-img    Ubuntu Docker image to use (required)
EOF
    elif [ "clean" == "$cmd" ]; then
        cat << EOF
Clean up temporary build and package files
EOF
    fi
}

# Usage: runDockerCmd CMD TESTCMD DEPENDENCIES...
runDockerCmd() {
    if [ -z "$DOCKER_IMG" ]; then
	command -v "$2" > /dev/null || (sudo apt-get -y update && sudo apt-get -y --no-install-recommends install $3)
	bash -c "$1"
	return
    fi

    local tmpuser="tmpuser${RANDOM}"
    docker run --rm \
            -e "DEBEMAIL=$DEBEMAIL" -e "DEBFULLNAME=$DEBFULLNAME" \
            -v "$(realpath ..):/debuild:rw" \
            --net=host \
            "$DOCKER_IMG" \
            bash -c "command -v ${2} > /dev/null || \
                     (apt-get -y update && apt-get -y --no-install-recommends install ${3}); \
                     useradd -u $(id -u) ${tmpuser} && cd /debuild/${PACKAGE} && \
                     su ${tmpuser} -c '${1}'"

}

# -----------------------------------------------------------------------
#                            upload command
# -----------------------------------------------------------------------
upload() {
    while [ $# -ge 1 ]; do
        ARG="$1"
        case "$ARG" in
            -s|--series)
                SERIES="$2"
                shift ;;

            -p|--package)
                PACKAGE="$2"
                shift ;;

            -v|--version)
                VERSION="$2"
                shift ;;

            -d|--docker-img)
                DOCKER_IMG="$2"
                shift ;;

            *)
                printError "ERROR: Unknown option '$ARG'\n"
                printUsage upload >&2
                exit 1 ;;
        esac
        shift
    done

    if [ "$SERIES" == "" ] || [ "$PACKAGE" == "" ]; then
        printUsage upload >&2
        exit 1
    fi

    if [ ! -f "${SERIES}/${PACKAGE}_${VERSION}_source.changes" ]; then
        printError "No source package for package ${PACKAGE}~${SERIES} found!"
        exit 1
    fi

    cd "${SERIES}/${PACKAGE}"
    printStatus "Uploading package..."
    runDockerCmd "cd .. && dput -u ppa:phoerious/keepassxc \"${PACKAGE}_${VERSION}_source.changes\"" "dput" "dput"
    cd ../..
}


# -----------------------------------------------------------------------
#                             build command
# -----------------------------------------------------------------------
build() {
    local IMMEDIATE_UPLOAD=false

    while [ $# -ge 1 ]; do
        ARG="$1"

        case "$ARG" in
            -s|--series)
                SERIES="$2"
                shift ;;

            -p|--package)
                PACKAGE="$2"
                shift ;;

            -d|--docker-img)
                DOCKER_IMG="$2"
                shift ;;

            -c|--changelog)
                CHANGELOG_FILE="$2"
                shift ;;

            -V|--upstream-version)
                UPSTREAM_VERSION="$2"
                shift ;;

            -x|--ubuntu-version)
                UBUNTU_VERSION="$2"
                shift ;;

            -v|--ppa-version)
                PPA_VERSION="$2"
                shift ;;

            -r|--series-version)
                SERIES_VERSION="$2"
                shift ;;

            -u|--urgency)
                URGENCY="$2"
                shift ;;

            -k|--gpg-key)
                GPG_KEY="$2"
                shift ;;

            --upload)
                IMMEDIATE_UPLOAD=true ;;

            *)
                printError "ERROR: Unknown option '$ARG'\n"
                printUsage build >&2
                exit 1 ;;
        esac
        shift
    done

    if [ "$SERIES" == "" ] || [ "$PACKAGE" == "" ] || \
       [ "$UPSTREAM_VERSION" == "" ] || [ "$UBUNTU_VERSION" == "" ]; then
        printUsage build >&2
        exit 1
    fi

    CL_FILE_IS_TMP=false
    FULL_VERSION="${UPSTREAM_VERSION}-${UBUNTU_VERSION}${PPA_VERSION}~${SERIES}${SERIES_VERSION}"
    if [ "$CHANGELOG_FILE" == "" ]; then
        CHANGELOG_FILE="/tmp/builddebpkg_${PACKAGE}~${SERIES}_${RANDOM}"
        CL_FILE_IS_TMP=true
        echo "${FULL_VERSION} ($(date +%Y-%m-%d))
=========================

- Upstream update" > "$CHANGELOG_FILE"
        if [ "$EDITOR" == "" ]; then
            EDITOR=vim
        fi
        $EDITOR "$CHANGELOG_FILE"
    fi

    FULL_CL="$(grep -Pzo "^[\d\.~\-\+a-z]+ \(\d+-\d+-\d+\)\n=+(?:(?:\n\s*-[^\n]+)+)" "$CHANGELOG_FILE" | tr -d '\0')"
    CHANGELOG="$(echo "$FULL_CL" | grep -Pzo "(?s)(?<====\n\n).+" | tr -d '\0' | sed 's/^\s*- \?/  * /')"
    FULL_VERSION="$(echo "$FULL_CL" | grep -Pzo "^[\d\.~\-\+a-z]+" | tr -d '\0')"

    DATE="$(date -R)"

    if $CL_FILE_IS_TMP; then
        rm "$CHANGELOG_FILE"
    fi

    if [ ! -d "./${SERIES}/${PACKAGE}/debian" ]; then
        printError "No source folder for package '${PACKAGE}~${SERIES}'!"
        exit 1
    fi

    cd "./${SERIES}/${PACKAGE}"

    STRIPPED_UPSTREAM_VERSION=$(echo -n "$UPSTREAM_VERSION" | cut -d"+" -f1)
    STRIPPED_UPSTREAM_VERSION2=$(echo -n "$UPSTREAM_VERSION" | cut -d"+" -f2)
    if [ "" != "$STRIPPED_UPSTREAM_VERSION2" ]; then
        DOWNLOAD_VERSION="$(echo -n "$STRIPPED_UPSTREAM_VERSION2" | sed 's/^really//')"
    else
        DOWNLOAD_VERSION="$STRIPPED_UPSTREAM_VERSION"
    fi
    SOURCE=$(grep -oP "(?<=^${PACKAGE} )(https?|ftps?)://.*" ../sources | sed "s/\${VERSION}/${DOWNLOAD_VERSION}/g")
    SOURCE_EXT=$(basename "$SOURCE" | grep -oP "(xz|bz2|gz)\$")
    if [ "" == "${SOURCE}" ]; then
        printError "No source URL given for package ${PACKAGE}!"
        cd ../..
        exit 1
    fi
    if [ ! -f "../${PACKAGE}_${UPSTREAM_VERSION}.orig.tar.xz" ]; then
        printStatus "Downloading sources for version ${PACKAGE}-${UPSTREAM_VERSION}..."
        wget "${SOURCE}" -O "../${PACKAGE}_${UPSTREAM_VERSION}.orig.tar.${SOURCE_EXT}"
	if [ $? -ne 0 ]; then
            printError "Download failed! Process aborted."
            exit 1
        fi
    else
        printStatus "Sources already downloaded."
    fi

    if [ "${PACKAGE}" == "keepassxc" ]; then
        printStatus "Verifying sources..."
        curl -fL "https://github.com/keepassxreboot/keepassxc/releases/download/${STRIPPED_UPSTREAM_VERSION}/keepassxc-${STRIPPED_UPSTREAM_VERSION}-src.tar.xz.sig" | \
            gpg --verify - "../${PACKAGE}_${UPSTREAM_VERSION}.orig.tar.${SOURCE_EXT}"

        if [ $? -ne 0 ]; then
            printError "Signature verification failed! Process aborted."
            exit 1
        fi
    fi


    printStatus "Creating source package for '${SERIES}'..."

    if $(grep -q "^${PACKAGE} (${FULL_VERSION})" debian/changelog); then
        printError "Changelog entry for '${FULL_VERSION}' already exists!"
        cd ..
        exit 1
    fi

    TMP_CL="$(cat debian/changelog)"
    echo -e "${PACKAGE} (${FULL_VERSION}) ${SERIES}; urgency=${URGENCY}\n" > debian/changelog
    echo "$CHANGELOG" >> debian/changelog
    echo -e "\n -- KeePassXC Team <team@keepassxc.org>  ${DATE}" >> debian/changelog

    if [ "$TMP_CL" != "" ] && [ "$TMP_CL" != $'\n' ]; then
        echo >> debian/changelog
        echo "$TMP_CL" >> debian/changelog
    fi

    runDockerCmd "debuild -us -uc -S" "debuild" "devscripts build-essential dh-autoreconf fakeroot dh-make"

    # reproduce what debsign would do, so we can sign on non-Debian based systems
    printStatus "Signing DSC file..."
    DSC_NAME="${PACKAGE}_${FULL_VERSION}.dsc"
    gpg --clearsign --local-user "${GPG_KEY}" "../${DSC_NAME}"
    rm "../${DSC_NAME}"
    mv "../${DSC_NAME}.asc" "../${DSC_NAME}"
    MD5SUM=$(md5sum "../${DSC_NAME}" | awk '{ print $1 }')
    SHA1UM=$(sha1sum "../${DSC_NAME}" | awk '{ print $1 }')
    SHA256UM=$(sha256sum "../${DSC_NAME}" | awk '{ print $1 }')
    SIZE=$(du -b "../${DSC_NAME}" | awk '{ print $1 }')

    printStatus "Updating CHANGES file..."
    CHANGES_NAME="${PACKAGE}_${FULL_VERSION}_source.changes"
    sed -i "s/ [0-f]\\{40\\} [0-9]\+ \(.\+\.dsc\)/ ${SHA1UM} ${SIZE} \1/" "../${CHANGES_NAME}"
    sed -i "s/ [0-f]\\{64\\} [0-9]\+ \(.\+\.dsc\)/ ${SHA256UM} ${SIZE} \1/" "../${CHANGES_NAME}"
    sed -i "s/ [0-f]\\{32\\} [0-9]\+ \(.\+\.dsc\)/ ${MD5SUM} ${SIZE} \1/" "../${CHANGES_NAME}"

    printStatus "Signing CHANGES file..."
    gpg --clearsign --local-user "${GPG_KEY}" "../${CHANGES_NAME}"
    rm "../${CHANGES_NAME}"
    mv "../${CHANGES_NAME}.asc" "../${CHANGES_NAME}"

    cd ../..

    if $IMMEDIATE_UPLOAD; then
        upload --series "$SERIES" --package "$PACKAGE" --version "$FULL_VERSION" --docker-img "$DOCKER_IMG"
    fi
}


# -----------------------------------------------------------------------
#                             clean command
# -----------------------------------------------------------------------
clean() {
    if [ "$1" != "" ]; then
        printError "ERROR: Unknown option '${1}'\n"
        printUsage clean >&2
        exit 1
    fi

    printStatus "Cleaning up packaging mess..."
    find . -name "*_source.build" -exec rm -rfv {} \;
    find . -name "*_source.changes" -exec rm -rfv {} \;
    find . -name "*.debian.tar.gz" -exec rm -rfv {} \;
    find . -name "*.dsc" -exec rm -rfv {} \;
    find . -name "*.orig.tar.*" -exec rm -rfv {} \;
    find . -name "*_source.ppa.upload" -exec rm -rfv {} \;
}


# -----------------------------------------------------------------------
#                       parse global command line
# -----------------------------------------------------------------------
MODE="$1"
shift
if [ "" == "$MODE" ]; then
    logError "Missing arguments!\n"
    printUsage
    exit 1
elif [ "help" == "$MODE" ]; then
    printUsage "$1"
    exit
elif [ "build" == "$MODE" ] || [ "upload" == "$MODE" ] || [ "clean" == "$MODE" ]; then
    $MODE "$@"
else
    printUsage "$MODE"
fi
