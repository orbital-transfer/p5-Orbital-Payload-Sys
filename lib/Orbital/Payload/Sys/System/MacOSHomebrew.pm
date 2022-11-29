use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::System::MacOSHomebrew;
# ABSTRACT: macOS with homebrew

use Mu;
use IPC::System::Simple ();
use Object::Util magic => 0;

use Orbital::Transfer::EnvironmentVariables;
use Orbital::Transfer::Runner::Default;
use aliased 'Orbital::Transfer::Runnable';

lazy homebrew_prefix => method() {
	path("/usr/local");
};

lazy environment => method() {
	my $env = Orbital::Transfer::EnvironmentVariables
		->new;

	# Set up Homebrew bin path
	$env->prepend_path_list( 'PATH', [ $self->homebrew_prefix->child('bin')->stringify ]  );

	if( $self->should_install_openssl ) {
		# Set up for OpenSSL (linking and utilities)
		$env->prepend_path_list( 'PKG_CONFIG_PATH', [ $self->homebrew_prefix->child('opt/openssl/lib/pkgconfig')->stringify ]  );
		$env->prepend_path_list( 'PATH', [ $self->homebrew_prefix->child('opt/openssl/bin')->stringify ]  );
	}

	# Set up for libffi linking
	$env->prepend_path_list( 'PKG_CONFIG_PATH', [ $self->homebrew_prefix->child('opt/libffi/lib/pkgconfig')->stringify ]  );

	# Add Homebrew gettext utilities to path
	$env->prepend_path_list( 'PATH', [ $self->homebrew_prefix->child('opt/gettext/bin')->stringify ]  );

	# TODO check if this is still necessary
	# Only necessary if using system Perl on mac with multiple arch in ccflags
	# <https://mail.gnome.org/archives/gtk-perl-list/2016-October/msg00004.html>
	$env->set_string('ARCHFLAGS', '-arch x86_64' );

	$env;
};

lazy should_run_update => method() {
	return ! $ENV{CI};
};

lazy should_install_xquartz => method() {
	return 0;
};

lazy should_install_pkgconfig => method() {
	return 1;
};

lazy should_install_openssl => method() {
	return 1;
};

method _pre_run() {

}

method _install() {
	local $ENV{HOMEBREW_NO_AUTO_UPDATE} = 0 + ! $self->should_run_update;
	if( $self->should_run_update ) {
		print STDERR "Updating homebrew\n";
		$self->runner->$_try( system =>
			Runnable->new(
				command => [ qw(brew update) ]
			)
		);
	}

	# Remove old Python package
	$self->runner->$_try( system =>
		Runnable->new(
			command => [ qw(brew unlink python@2) ]
		)
	);

	if( $self->should_install_xquartz ) {
		# Set up for X11 support
		print STDERR "Installing xquartz homebrew cask for X11 support\n";
		$self->runner->$_try( system =>
			Runnable->new(
				command => $_
			)
		) for (
			[ qw(brew tap Caskroom/cask) ],
			[ qw(brew install Caskroom/cask/xquartz) ]
		);
	}

	if( $self->should_install_pkgconfig ) {
		# Set up for pkg-config
		$self->runner->$_try( system =>
			Runnable->new(
				command => [ qw(brew install pkg-config) ]
			)
		);
	}

	if( $self->should_install_openssl ) {
		# Set up for OpenSSL (linking and utilities)
		$self->runner->$_try( system =>
			Runnable->new(
				command => [ qw(brew install openssl) ]
			)
		);
	}
}

method install_packages($repo) {
	local $ENV{HOMEBREW_NO_AUTO_UPDATE} = 0 + ! $self->should_run_update;
	my @packages = @{ $repo->homebrew_get_packages };
	print STDERR "Installing repo native deps\n";
	if( @packages ) {
		# Skip font cache generation (for fontconfig):
		# <https://github.com/Homebrew/homebrew-core/pull/10947#issuecomment-285946088>
		my $has_fontconfig_dep = eval {
			use autodie qw(:system);
			system( qq{brew deps --union @packages | grep ^fontconfig\$ && brew install --force-bottle --build-bottle fontconfig} );
		};

		my @deps_to_install = grep {
			my $dep = $_;
			eval {
				use autodie qw(:system);
				system( qq{brew ls @packages >/dev/null 2>&1} );
			};
			$@ ? 1 : 0;
		} @packages;
		print STDERR "Native deps to install: @deps_to_install\n";

		if(@deps_to_install) {
			system( qq{brew install @deps_to_install || true} );
			system( qq{brew install @packages || true} );
		}
	}
}

with qw(
	Orbital::Transfer::System::Role::Config
	Orbital::Transfer::System::Role::DefaultRunner
	Orbital::Payload::Env::Perl::System::Role::PerlPathCurrent
	Orbital::Payload::Env::Perl::System::Role::Perl
);

1;
