# KeePassXC Linux PPA Build Dockerfile
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

FROM ubuntu:14.04

RUN set -x \
    && apt-get update -y \
    && apt-get install --no-install-recommends -y \
        build-essential \
        fakeroot \
        devscripts \
        dh-autoreconf \
        dh-make \
        dput \
        texlive-latex-base \
        texlive-generic-recommended \
        texinfo

RUN set -x \
    && apt-get autoremove --purge \
    && rm -rf /var/lib/apt/lists/*

VOLUME /keepassxc
WORKDIR /keepassxc
