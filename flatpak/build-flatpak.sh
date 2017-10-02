#!/usr/bin/env bash
set -e

flatpak-builder \
    --force-clean \
    --ccache \
    --require-changes \
    --repo=.flatpak-test-repo \
    --arch=$(flatpak --default-arch) \
    --subject="build of org.keepassxc.App, $(date)" \
    build \
    org.keepassxc.App.json

