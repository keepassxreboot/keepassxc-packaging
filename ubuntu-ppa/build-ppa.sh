#!/usr/bin/env bash

printUsage() {
    echo "Usage: $(basename $0) OPTIONS"
    cat << EOF

Build and publish Ubuntu PPA source packages

Options:
  -s, --series        Ubuntu release series to build (required)
  -p, --package       Package name to build (required, default: 'keepassxc')
  -d, --docker-img    Ubuntu Docker image to use (required)
  -c, --changelog     CHANGELOG file
  -g, --pkg-version   Package build version (default: '0')
  -v, --ppa-version   PPA package version (default: '1')
  -u, --urgency       Package urgency (default: 'medium')
  -k, --gpg-key       GPG key used to sign package (default: 'BF5A669F2272CF4324C1FDA8CFB4C2166397D0D2')
EOF
}

printStatus() {
    echo -e "\e[1m\e[34m${1}\e[0m"
}

printError() {
    echo -e "\e[91m${1}\e[0m" >&2
}

# Usage: runDockerCmd CMD TESTCMD DEPENDENCIES...
runDockerCmd() {
    local tmpuser="tmpuser${RANDOM}"
    docker run --rm \
            -e "DEBEMAIL=team@keepassxc.org" -e "DEBFULLNAME=KeePassXC Team" \
            -v "$(realpath ..):/debuild:rw" \
            "$DOCKER_IMG" \
            bash -c "command -v ${2} > /dev/null || \
                     (apt-get --yes update && apt-get --yes --no-install-recommends install ${3}); \
                     useradd -u $(id -u) ${tmpuser} && cd /debuild/${PACKAGE} && \
                     su ${tmpuser} -c '${1}'"
}

PKG_VERSION="0"
PPA_VERSION="1"
PACKAGE="keepassxc"
URGENCY="medium"
GPG_KEY="BF5A669F2272CF4324C1FDA8CFB4C2166397D0D2"

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

        -g|--pkg-version)
            PKG_VERSION="$2"
            shift;;

        -v|--ppa-version)
            PPA_VERSION="$2"
            shift;;

        -u|--urgency)
            URGENCY="$2"
            shift;;

        -k|--gpg-key)
            GPG_KEY="$2"
            shift;;

        *)
            printError "ERROR: Unknown option '$ARG'\n"
            printUsage >&2
            exit 1 ;;
    esac
    shift
done

if [ "$SERIES" == "" ] || [ "$PACKAGE" == "" ] || [ "$DOCKER_IMG" == "" ]; then
    printUsage >&2
    exit 1
fi

CL_FILE_IS_TMP=false
if [ "$CHANGELOG_FILE" == "" ]; then
    CHANGELOG_FILE="/tmp/builddebpkg_${PACKAGE}~${SERIES}_${RANDOM}"
    CL_FILE_IS_TMP=true
    echo "VERSION ($(date +%Y-%m-%d))
=========================

- " > "$CHANGELOG_FILE"
    CHECKSUM=$(sha1sum "$CHANGELOG_FILE")
    if [ "$EDITOR" == "" ]; then
        EDITOR=vim
    fi
    $EDITOR "$CHANGELOG_FILE"

    if [ "$(sha1sum "$CHANGELOG_FILE")" == "$CHECKSUM" ]; then
        printError "No changes made to temporary changelog."
        rm "$CHANGELOG_FILE"
        exit 1
    fi
fi

FULL_CL="$(grep -Pzo "^\d+\.\d+\.\d+ \(\d+-\d+-\d+\)\n=+(?:(?:\n\s*-[^\n]+)+)" "$CHANGELOG_FILE" | tr -d '\0')"
CHANGELOG="$(echo "$FULL_CL" | grep -Pzo "(?s)(?<====\n\n).+" | tr -d '\0' | sed 's/^\s*- \?/  * /')"
VERSION="$(echo "$FULL_CL" | grep -Pzo "\d+\.\d+\.\d+" | tr -d '\0')"
DATE="$(date -R)"

if $CL_FILE_IS_TMP; then
    rm "$CHANGELOG_FILE"
fi

if [ ! -d "./${SERIES}/${PACKAGE}/debian" ]; then
    printError "No source folder for package '${PACKAGE}~${SERIES}'!"
    exit 1
fi

cd "./${SERIES}/${PACKAGE}"

SOURCE=$(grep -oP "(?<=^keepassxc )https?://.*" ../sources | sed "s/\${VERSION}/${VERSION}/g")
SOURCE_EXT=$(basename "$SOURCE" | grep -oP "(xz|bz2|gz)\$")
if [ "" == "${SOURCE}" ]; then
    printError "No source URL given for package ${PACKAGE}!"
    cd ../..
    exit 1
fi
if [ ! -f "../${PACKAGE}_${VERSION}.orig.tar.xz" ]; then
    printStatus "Downloading sources for version ${PACKAGE}-${VERSION}..."
    curl -L "${SOURCE}" > "../${PACKAGE}_${VERSION}.orig.tar.${SOURCE_EXT}"
    if [ $? -ne 0 ]; then
        printError "Download failed! Process aborted."
        exit 1
    fi
else
    printStatus "Sources already download."
fi

if [ "${PACKAGE}" == "keepassxc" ]; then
    printStatus "Verifying sources..."
    curl -L "https://github.com/keepassxreboot/keepassxc/releases/download/${VERSION}/keepassxc-${VERSION}-src.tar.xz.sig" | \
        gpg --verify - "../${PACKAGE}_${VERSION}.orig.tar.${SOURCE_EXT}"

    if [ $? -ne 0 ]; then
        printError "Signature verification failed! Process aborted."
        exit 1
    fi
fi


printStatus "Creating source package for '${SERIES}'..."

FULL_VERSION="${VERSION}-${PKG_VERSION}~${SERIES}${PPA_VERSION}"

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

runDockerCmd "debuild -us -uc -S" "debuild" "devscripts build-essential fakeroot dh-make"

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

printStatus "Uploading package..."
runDockerCmd "cd .. && dput -u ppa:phoerious/keepassxc \"${CHANGES_NAME}\"" "dput" "dput"

printStatus "Cleaning up packaging mess..."
cd ..
rm "${PACKAGE}_${FULL_VERSION}_source.build"
rm "${PACKAGE}_${FULL_VERSION}_source.changes"
rm "${PACKAGE}_${FULL_VERSION}.debian.tar.gz"
rm "${PACKAGE}_${FULL_VERSION}.dsc"
rm "${PACKAGE}_${VERSION}.orig.tar.${SOURCE_EXT}"

cd ..
