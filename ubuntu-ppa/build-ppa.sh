#!/usr/bin/env bash

printUsage() {
    echo "Usage: $(basename $0) OPTIONS"
    cat << EOF

Build and publish Ubuntu PPA source packages

Options:
  -s, --series        Ubuntu release series to build (required)
  -c, --changelog     CHANGELOG file (required)
  -d, --docker-img    Ubuntu Docker image to use (required)
  -p, --pkg-version   Package build version (default: 1)
  -v, --ppa-version   PPA package version (default: 1)
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

runDockerCmd() {
    local tmpuser="tmpuser${RANDOM}"
    docker run --rm \
            -e "DEBEMAIL=team@keepassxc.org" -e "DEBFULLNAME=KeePassXC Team" \
            -v "$(realpath ..):/debuild:rw" \
            "$DOCKER_IMG" \
            bash -c "command -v debuild > /dev/null || \
                     (apt-get --yes update && apt-get --yes --no-install-recommends install ${2}); \
                     useradd -u $(id -u) ${tmpuser} && cd /debuild/${SERIES} && \
                     su ${tmpuser} -c '${1}'"
}

PKG_VERSION="1"
PPA_VERSION="1"
URGENCY="medium"
GPG_KEY="BF5A669F2272CF4324C1FDA8CFB4C2166397D0D2"

while [ $# -ge 1 ]; do
    ARG="$1"
    case "$ARG" in
        -s|--series)
            SERIES="$2"
            shift ;;

        -c|--changelog)
            CHANGELOG_FILE="$2"
            shift ;;

        -d|--docker-img)
            DOCKER_IMG="$2"
            shift ;;

        -p|--pkg-version)
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

if [ "$SERIES" == "" ] || [ "$CHANGELOG_FILE" == "" ] || [ "$DOCKER_IMG" == "" ]; then
    printUsage >&2
    exit 1
fi

FULL_CL="$(grep -Pzo "^\d+\.\d+\.\d+ \(\d+-\d+-\d+\)\n=+(?:(?:\n\s*-[^\n]+)+)" "$CHANGELOG_FILE" | tr -d '\0')"
VERSION="$(echo "$FULL_CL" | grep -Pzo "\d+\.\d+\.\d+" | tr -d '\0')"
CHANGELOG="$(echo "$FULL_CL" | grep -Pzo "(?s)(?<====\n\n).+" | tr -d '\0' | sed 's/^\s*- /  * /')"
DATE="$(date -R)"


if [ ! -f "keepassxc_${VERSION}.orig.tar.xz" ]; then
    printStatus "Downloading sources for version ${VERSION}..."
    curl -L "https://github.com/keepassxreboot/keepassxc/releases/download/${VERSION}/keepassxc-${VERSION}-src.tar.xz" \
        > "keepassxc_${VERSION}.orig.tar.xz"
    if [ $? -ne 0 ]; then
        printError "Download failed! Process aborted."
        exit 1
    fi
else
    printStatus "Sources already download."
fi

printStatus "Verifying sources..."
curl -L "https://github.com/keepassxreboot/keepassxc/releases/download/${VERSION}/keepassxc-${VERSION}-src.tar.xz.sig" | \
    gpg --verify - "keepassxc_${VERSION}.orig.tar.xz"

if [ $? -ne 0 ]; then
    printError "Signature verification failed! Process aborted."
    exit 1
fi

if [ ! -d "./${SERIES}/debian" ]; then
    printError "No source folder for series '${SERIES}'!"
    cd ..
    exit 1
fi

printStatus "Creating source package for '${SERIES}'..."

cd "./${SERIES}"

FULL_VERSION="${VERSION}-${PKG_VERSION}~${SERIES}${PPA_VERSION}"

if $(grep -q "^keepassxc (${FULL_VERSION})" debian/changelog); then
    printError "Changelog entry for '${FULL_VERSION}' already exists!"
    cd ..
    exit 1
fi

TMP_CL="$(cat debian/changelog)"
echo -e "keepassxc (${FULL_VERSION}) ${SERIES}; urgency=${URGENCY}\n" > debian/changelog
echo "$CHANGELOG" >> debian/changelog
echo -e "\n -- KeePassXC Team <team@keepassxc.org>  ${DATE}" >> debian/changelog

if [ "$TMP_CL" != "" ] && [ "$TMP_CL" != $'\n' ]; then
    echo >> debian/changelog
    echo "$TMP_CL" >> debian/changelog
fi

runDockerCmd "debuild -us -uc -S" "devscripts fakeroot dh-make"

# reproduce what debsign would do, so we can sign on non-Debian based systems
printStatus "Signing DSC file..."
DSC_NAME="keepassxc_${FULL_VERSION}.dsc"
gpg --clearsign --local-user "${GPG_KEY}" "../${DSC_NAME}"
rm "../${DSC_NAME}"
mv "../${DSC_NAME}.asc" "../${DSC_NAME}"
MD5SUM=$(md5sum "../${DSC_NAME}" | awk '{ print $1 }')
SHA1UM=$(sha1sum "../${DSC_NAME}" | awk '{ print $1 }')
SHA256UM=$(sha256sum "../${DSC_NAME}" | awk '{ print $1 }')
SIZE=$(du -b "../${DSC_NAME}" | awk '{ print $1 }')

printStatus "Updating CHANGES file..."
CHANGES_NAME="keepassxc_${FULL_VERSION}_source.changes"
sed -i "s/ [0-f]\\{40\\} [0-9]\+ \(.\+\.dsc\)/ ${SHA1UM} ${SIZE} \1/" "../${CHANGES_NAME}"
sed -i "s/ [0-f]\\{64\\} [0-9]\+ \(.\+\.dsc\)/ ${SHA256UM} ${SIZE} \1/" "../${CHANGES_NAME}"
sed -i "s/ [0-f]\\{32\\} [0-9]\+ \(.\+\.dsc\)/ ${MD5SUM} ${SIZE} \1/" "../${CHANGES_NAME}"

printStatus "Signing CHANGES file..."
gpg --clearsign --local-user "${GPG_KEY}" "../${CHANGES_NAME}"
rm "../${CHANGES_NAME}"
mv "../${CHANGES_NAME}.asc" "../${CHANGES_NAME}"

printStatus "Uploading package..."
runDockerCmd "cd .. && dput -u ppa:phoerious/keepassxc \"${CHANGES_NAME}\"" "dput"

cd ..
