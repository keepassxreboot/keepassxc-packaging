#!/usr/bin/env sh

# Setup build environment
apt-get -y install build-essential cmake g++

# Install package dependencies
apt-get -y install libxi-dev libxtst-dev qtbase5-dev \
    libqt5x11extras5-dev qttools5-dev qttools5-dev-tools \
    libgcrypt20-dev zlib1g-dev libyubikey-dev libykpers-1-dev

# Extract the package and create the build structure
cd /vagrant/src
tar xf keepassxc-2.1.2
cd keepassxc-2.1.2
mkdir build && cd build

# Create the Makefile with full options
# At some point this should be passed to the user installing the package
cmake .. -DWITH_TESTS=OFF \
-DCMAKE_INSTALL_PREFIX=/usr/local \
-DCMAKE_VERBOSE_MAKEFILE=ON \
-DWITH_GUI_TESTS=ON \
-DWITH_XC_AUTOTYPE=ON \
-DWITH_XC_HTTP=ON

# Build and install the package
make && make install

