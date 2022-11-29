use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::System::Debian::Meson;
# ABSTRACT: Install and setup meson build system

use Orbital::Transfer::Common::Setup;
use Mu;
use Orbital::Transfer::EnvironmentVariables;
use aliased 'Orbital::Transfer::Runnable';
use Object::Util magic => 0;

has platform => (
	is => 'ro',
	required => 1,
);

has runner => (
	is => 'ro',
	required => 1,
);

method environment() {
	my $py_user_base_bin = $self->runner->capture(
		Runnable->new(
			command => [ qw(python3 -c), "import site, os; print(os.path.join(site.USER_BASE, 'bin'))" ],
			environment => $self->platform->environment
		)
	);
	chomp $py_user_base_bin;

	my $py_user_site_pypath = $self->runner->capture(
		Runnable->new(
			command => [ qw(python3 -c), "import site; print(site.USER_SITE)" ],
			environment => $self->platform->environment
		)
	);
	chomp $py_user_site_pypath;
	Orbital::Transfer::EnvironmentVariables
		->new
		->$_tap( 'prepend_path_list', 'PATH', [ $py_user_base_bin ] )
		->$_tap( 'prepend_path_list', 'PYTHONPATH', [ $py_user_site_pypath ] )
}

method setup() {
	$self->runner->system(
		Runnable->new(
			command => $_,
			environment => $self->environment,
		)
	) for(
		[ qw(pip3 install --user -U setuptools wheel) ],
		[ qw(pip3 install --user -U meson) ],
	);
}

method install_pip3_apt( $apt ) {
	my $pip3 = Orbital::Payload::Sys::RepoPackage::APT->new( name => 'python3-pip' );
	$self->runner->system(
		$apt->install_packages_command( $pip3 )
	) unless $apt->$_try( installed_version => $pip3 );
}

1;
