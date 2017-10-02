# Flatpak

Flatpak is a cross-distribution packaging standard to distribute desktop applications. Flatpak is [available for all major distributions](http://flatpak.org/getting.html).

Applications packaged and executed using Flatpak are containerized using Linux user namespaces and can be configured to access exactly the resources they need.

## Prerequisites

Install `flatpak` and `flatpak-builder`. On Fedora simply run:

```bash
$ dnf install flatpak flatpak-builder
```

Flatpak is available on all major distributions. See the official [getting Flatpak](http://flatpak.org/getting.html) documentation on how to install for other distributions.

Another prerequisite: Add the freedesktop runtime platform and sdk:

```bash
$ flatpak remote-add --from gnome https://sdk.gnome.org/gnome.flatpakrepo
$ flatpak install gnome org.freedesktop.Platform//1.6
$ flatpak install gnome org.freedesktop.Sdk//1.6
```

## Build and install

Build flatpak in local repo ("./.flatpak-test-repo"), then add the remote, and install from the local repo, run:

```bash
$ ./build-flatpak.sh
$ flatpak remote-add --user --no-gpg-verify keepassxc .flatpak-test-repo
$ flatpak install --user keepassxc org.keepassxc.App
```

To rebuild and update the installed flatpak from the local repo, run:

```bash
$ ./build-flatpak.sh
$ flatpak --user update org.keepassxc.App
```

To produce the single file flatpak package, run:

```bash
$ flatpak build-bundle .flatpak-test-repo org.keepassxc.App.flatpak org.keepassxc.App
```

To install flatpak package from single file package, run:

```bash
$ flatpak --user org.keepassxc.App.flatpak
```

The produced single file package can then be added to each new release of KeePassXC on GitHub.
