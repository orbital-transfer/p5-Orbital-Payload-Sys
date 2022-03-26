use Modern::Perl;
package Orbital::Payload::Sys::System::Debian;
# ABSTRACT: Debian-based system

use Mu;
use Orbital::Transfer::Common::Setup;
use Orbital::Payload::Sys::System::Debian::Meson;
use Orbital::Payload::Sys::System::Docker;

use Orbital::Payload::Sys::PackageManager::APT;
use Orbital::Payload::Sys::RepoPackage::APT;

use Orbital::Transfer::EnvironmentVariables;
use Object::Util magic => 0;

lazy apt => method() {
	Orbital::Payload::Sys::PackageManager::APT->new(
		runner => $self->runner
	);
};

lazy x11_display => method() {
	':99.0';
};

lazy environment => method() {
	Orbital::Transfer::EnvironmentVariables
		->new
		->$_tap( 'set_string', 'DISPLAY', $self->x11_display );
};

method _prepare_x11() {
	#system(qw(sh -e /etc/init.d/xvfb start));
	unless( fork ) {
		exec(qw(Xvfb), $self->x11_display);
	}
	sleep 3;
}

method _pre_run() {
	$self->_prepare_x11;
}

method _install() {
	if( Orbital::Payload::Sys::System::Docker->is_inside_docker ) {
		# create a non-root user
		say STDERR "Creating user nonroot (this should only occur inside Docker)";
		system(qw(useradd -m notroot));
		system(qw(chown -R notroot:notroot /build));
	}

	my @packages = map {
		Orbital::Payload::Sys::RepoPackage::APT->new( name => $_ )
	} qw(xvfb xauth);
	unless( $self->apt->are_all_installed(@packages) ) {
		$self->runner->system(
			$self->apt->update_command
		);
		$self->runner->system(
			$self->apt->install_packages_command(@packages)
		);
	}
}

method install_packages($repo) {
	my @packages = map {
		Orbital::Payload::Sys::RepoPackage::APT->new( name => $_ )
	} @{ $repo->debian_get_packages };

	if(@packages && ! $self->apt->are_all_installed(@packages)) {
		$self->runner->system(
			$self->apt->update_command
		);
		$self->runner->system(
			$self->apt->install_packages_command(@packages)
		);
	}

	if( grep { $_->name eq 'meson' } @packages ) {
		my $meson = Orbital::Payload::Sys::System::Debian::Meson->new(
			runner => $self->runner,
			platform => $self,
		);
		$meson->install_pip3_apt($self->apt);
		$meson->setup;
	}
}

method process_git_path($path) {
	if( Orbital::Payload::Sys::System::Docker->is_inside_docker ) {
		system(qw(chown -R notroot:notroot), $path);
	}
}

with qw(
	Orbital::Transfer::System::Role::Config
	Orbital::Payload::Sys::System::Role::RunnerAuto
	Orbital::Payload::Env::Perl::System::Role::PerlPathCurrent
	Orbital::Payload::Env::Perl::System::Role::Perl
);

1;
