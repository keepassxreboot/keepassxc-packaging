import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '.molecule/ansible_inventory').get_hosts('all')


def test_keepassxc_src_file(File):
    f = File('/home/builder/project/keepassxc-2.1.2.tar.gz')

    assert f.exists
    assert f.sha256sum == '8cd94a401910ff67cadeed3d7d1b285f1e5d82ac8622a05b5c7eae60f28f1710'
    assert f.user == 'builder'
    assert f.group == 'builder'
