import testinfra.utils.ansible_runner
from ansible.vars import VariableManager

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    '.molecule/ansible_inventory').get_hosts('all')
#
#
# def test_hosts_file(File):
#     f = File('/etc/hosts')
#
#     assert f.exists
#     assert f.user == 'root'
#     assert f.group == 'root'


# def test_build_pkgs(Package):
#     variable_manager = VariableManager()
#     j = variable_manager.get_vars
#
#     for i in j:
#         print i
#
#     print variable_manager.get_vars
#
#     # for i in build_pkgs
#     g = Package('devscripts')
#
#     assert g.is_installed
