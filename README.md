# packaging
Packaging tools for [keepassxc][5]

I am actively working on packaging for Debian and have created a [repo][1] for it specifically.

This is a security application, as such it will be much easier to get it into Debian along with other OS's and make people feel better about it if the build tools and process were entirely transparent. Speaking again from a Debian POV, in order for it to be accepted it will need to be inspected and the more tooling and such we can show the easier the process will be.

I will be setting up Vagrant using a clean Jessie box from [Atlas][3]. In order to keep things sane I use the [vagrant-vbguest][2] plugin so I don't have to play with guest additions in the box. Provisioning will initially be done with a shell script for portability but everything will at some point be moved over to Ansible. This will ensure that we have a fully reproducible method to create packages and also that anyone who wishes to inspect the code/tools is able to do so without question. 

Using the above method also means we can swap Debian versions with ease and test any issues that may come up as the project progresses.

At a later point in time, other Vagrantfiles could be added to support additional platforms and tooling created at that point for its specific use.

At some point in the future I would like this to be moved over to the [keepassxc project][4] at some point in time. Concerning access once the repo gets moved over anyone, including myself, could just pr against it as time goes on. Security applications especially see much wider adoption and greater usage if they are fully developed and maintained in the open. Feel free to add comments and such to this. My ultimate goal is to get this built and packaged in Debian-stable at somepoint. I maintain tight control over what goes onto my machines and having it here means one less project I need to build from source and maintain outside of apt.

Thanks! 

[1]: https://github.com/mattyjones/packaging/tree/master/debian
[2]: https://github.com/dotless-de/vagrant-vbguest
[3]: https://atlas.hashicorp.com/debian/boxes/jessie64
[4]: https://github.com/keepassxreboot/keepassxc
[5]: https://keepassxc.org/
