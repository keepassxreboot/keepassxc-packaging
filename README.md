# packaging
Packaging tools for [keepassxc][5]

This is a security application, as such it will be much easier to get it into Debian along with other OS's and make people feel better about it if the build tools and process were entirely transparent. Speaking again from a Debian POV, in order for it to be accepted it will need to be inspected and the more tooling and such we can show the easier the process will be.

I will be setting up Vagrant using a clean Jessie box from [Atlas][3]. In order to keep things sane I use the [vagrant-vbguest][2] plugin so I don't have to play with guest additions in the box. Provisioning will Ansible, to ensure that we have a fully reproducible method to create packages and also that anyone who wishes to inspect the code/tools is able to do so without question. 

Using the above method also means we can swap platforms and versions with ease and test any issues that may come up as the project progresses.


[2]: https://github.com/dotless-de/vagrant-vbguest
[3]: https://atlas.hashicorp.com/debian/boxes/jessie64
[5]: https://keepassxc.org/
