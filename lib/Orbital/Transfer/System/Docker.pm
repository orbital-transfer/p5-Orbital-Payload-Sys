use Modern::Perl;
package Orbital::Transfer::System::Docker;
# ABSTRACT: Helper for Docker

use Mu;
use Orbital::Transfer::Common::Setup;

classmethod is_inside_docker() {
	my $cgroup = path('/proc/1/cgroup');
	return -f $cgroup  && $cgroup->slurp_utf8 =~ m,/(lxc|docker)/[0-9a-f]{64},s;
}

1;
