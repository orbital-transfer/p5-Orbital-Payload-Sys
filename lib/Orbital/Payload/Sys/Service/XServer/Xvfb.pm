use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::Service::XServer::Xvfb;
# ABSTRACT: Represents an Xvfb server

use Orbital::Transfer::Common::Setup;
use Mu;

use Orbital::Payload::Sys::Package::Spec::APT;

lazy x11_display => method() {
	':99.0';
};

method start() {
	#system(qw(sh -e /etc/init.d/xvfb start));
	unless( fork ) {
		exec(qw(Xvfb), $self->x11_display);
	}
	sleep 3;
}

method _debian_packages() {
	my @packages = map {
		Orbital::Payload::Sys::Package::Spec::APT->new( name => $_ )
	} qw(xvfb xauth);

	\@packages;
}

1;
