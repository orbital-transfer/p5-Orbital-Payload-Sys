use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::System::Docker;
# ABSTRACT: Helper for Docker

use Orbital::Transfer::Common::Setup;
use Mu;

classmethod _check_cgroup() {
	my $cgroup = path('/proc/1/cgroup');
	return -f $cgroup  && $cgroup->slurp_utf8 =~ m,/(lxc|docker)/[0-9a-f]{64},s;
}

classmethod _check_dockerenv() {
	return -f path('/.dockerenv');
}

classmethod is_inside_docker() {
	return $class->_check_dockerenv
		|| $class->_check_cgroup;
}

1;
