#! /bin/sh
# This file is used by gitpkg to extract a byte identical .orig.tar.gz
# file using pristine-tar.  To use it you need pristine-tar, and to
# configure HOOK_FILE=debian/gitpkg-hook.sh in one of the places that
# gitpkg looks (currently _not_ the environment).

ORIGTGZ="${DEB_DIR}/${DEB_SOURCE}/${DEB_SOURCE}_${DEB_VERSION%-*}.orig.tar.gz"
echo "(cd $REPO_ROOT &&  pristine-tar checkout ${ORIGTGZ})"
(cd $REPO_ROOT &&  pristine-tar checkout ${ORIGTGZ})
