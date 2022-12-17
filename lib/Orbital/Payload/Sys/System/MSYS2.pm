use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::System::MSYS2;
# ABSTRACT: System for MSYS2 + MinGW64 subsystem

use Orbital::Transfer::Common::Setup;
use Mu;
use Object::Util magic => 0;
use Module::Util ();
use Sub::Retry;

use Orbital::Transfer::EnvironmentVariables;
use aliased 'Orbital::Transfer::Runnable';

has msystem => (
	is => 'ro',
	default => sub { 'MINGW64' },
);

lazy msystem_base_path => method() {
	my $msystem_lc = lc $self->msystem;
	File::Spec->catfile( $self->msys2_dir, $msystem_lc );
};

lazy msystem_bin_path => method() {
	File::Spec->catfile( $self->msystem_base_path, qw(bin) );
};

has msys2_dir => (
	is => 'ro',
	default => sub {
		qq|C:\\msys64|;
	},
);

lazy perl_path => method() {
	File::Spec->catfile( $self->msystem_bin_path, qw(perl.exe) );
};

lazy paths => method() {
	my $msystem_lc = lc $self->msystem;
	[
		map { $self->msys2_dir . '\\' . $_ } (
			qq|${msystem_lc}\\bin|,
			qq|${msystem_lc}\\bin\\core_perl|,
			qq|usr\\bin|,
		)
	];
};

lazy environment => method() {
	my $env = Orbital::Transfer::EnvironmentVariables->new;

	$env->set_string('MSYSTEM', $self->msystem );

	$env->prepend_path_list('PATH', $self->paths );

	# Skip font cache generation (for fontconfig):
	# <https://github.com/Alexpux/MINGW-packages/commit/fdea2f9>
	# <https://github.com/Homebrew/homebrew-core/issues/10920>
	$env->set_string('MSYS2_FC_CACHE_SKIP', 1 );

	# OpenSSL
	delete $ENV{OPENSSL_CONF};
	$env->set_string('OPENSSL_PREFIX', $self->msystem_base_path);

	# Search @INC for module and use its path:
	#
	# Originally this was using the path to the full `.../lib` for the part
	# that gets sent to `perl -I` but this caused an issue once Babble is
	# used to remove dependencies because now it was picking up all the
	# other modules under the same `.../lib` and the modules straight out
	# of the checkout do not have the same dependencies as what are
	# installed within a CI which prevents using the CI on orbital-transfer
	# itself (that is, testing itself).
	#
	# One fix would be to append the path to the end of the list so it is
	# loaded last, but there isn't a flag for that nor a simple way to do
	# that via `PERL5OPT`.
	#
	# So instead the simplest fix is to use the path to the last part of
	# the module. The EUMMnosearch module would be best placed in a
	# directory with no other module in it (TODO write test for this) and
	# with a unique enough name (which it has) so that no other module
	# might accidentally get loaded.
	#
	# NOTE This approach will not work if the module is fatpacked. In that
	# case, the contents of `EUMMnosearch.pm` should be retrieved from @INC:
	#   map { $_->{'.../EUMMnosearch.pm'} } first { ref($_) =~ /^FatPacked::/ } @INC;
	# and written out to a temporary location.
	#
	# TODO This is highly coupled with Orbital::Payload::Env::Perl. Not
	# good.
	my $eumm_module = 'Orbital::Payload::Env::Perl::System::MSWin32::EUMMnosearch';
	my $eumm_module_final_part = (Module::Util::module_name_parts($eumm_module))[-1];
	my $path = path(Module::Util::find_installed($eumm_module))
		->child( qw(..) x Module::Util::module_path_parts($eumm_module_final_part) )->realpath;
	$env->set_string('PERL5OPT', "-I$path -M$eumm_module_final_part");

	# MSYS/MinGW pkg-config command line is more reliable since it does the
	# needed path conversions. Note that there are three pkg-config
	# packages, one for each subsystem.
	$env->set_string('ALIEN_BUILD_PKG_CONFIG', 'PkgConfig::CommandLine' );

	$env;
};

lazy should_disable_checkspace => method() {
	return $ENV{CI};
};

lazy should_run_update => method() {
	# Should run update on AppVeyor because their version of MSYS2 may be
	# old.
	return 1 if exists $ENV{APPVEYOR};

	# Skip on GitHub Actions.  See <https://github.com/msys2/setup-msys2>
	# for more information on why.
	return 0 if exists $ENV{GITHUB_ACTIONS};

	return ! $ENV{CI};
};

method _pre_run() {
}

method perl_bin_paths() {
	my $msystem_lc = lc $self->msystem;
	local $ENV{PATH} = join ";", @{ $self->paths }, $ENV{PATH};

	chomp( my $site_bin   = `perl -MConfig -e "print \$Config{sitebin}"` );
	chomp( my $vendor_bin = `perl -MConfig -e "print \$Config{vendorbin}"` );
	my @perl_bins = ( $site_bin, $vendor_bin, '/mingw64/bin/core_perl' );
	my @perl_bins_w;
	for my $path_orig ( @perl_bins ) {
		chomp(my $path = `cygpath -w '$path_orig'`);
		push @perl_bins_w, $path;
	}
	join ";", @perl_bins_w;
}

method cygpath($path_orig) {
	local $ENV{PATH} = join ";", @{ $self->paths }, $ENV{PATH};
	chomp(my $path = `cygpath -u $path_orig`);

	$path;
}

lazy should_do_gcc9_workaround => method() {
	return 0;
};

method _install_prep_msys2_disable_checkspace() {
	if( $self->should_disable_checkspace ) {
		# See <https://github.com/Alexpux/MSYS2-pacman/issues/59>.
		# reduce time required to install packages by disabling pacman's disk space checking
		my $disable_checkspace_cmd =
			Runnable->new(
				command => [ qw(bash -c), <<'EOF' ],
sed -i 's/^CheckSpace/#CheckSpace/g' /etc/pacman.conf
EOF
				environment => $self->environment,
			);

		$self->runner->system( $disable_checkspace_cmd )
	}
}

method _install_prep_update_mirror_list() {
	my $repo_main_server = 'http://repo.msys2.org/';
	my @repo_mirrors = (
		$repo_main_server,
		'https://mirror.yandex.ru/mirrors/msys2/',
	);

	my $run_mirror_update_cmd = 1;
	my $mirror_update_cmd =
		Runnable->new(
			command => [ qw(bash -c), <<'EOF' ],
perl -i -lpE 's/^(Server.*(\Qrepo.msys2.org\E|\Qsourceforge.net\E).*)$/# $1/' /etc/pacman.d/mirrorlist.m*
EOF
			environment => $self->environment,
		);

	$self->runner->system( $mirror_update_cmd ) if $run_mirror_update_cmd;
}

method _install_prep_msys2_update() {
	$self->pacman('pacman-mirrors');
	$self->pacman('git');

	# For the `--ask 20` option, see
	# <https://github.com/Alexpux/MSYS2-packages/issues/1141>.
	#
	# Otherwise the message
	#
	#     :: msys2-runtime and catgets are in conflict. Remove catgets? [y/N]
	#
	# is displayed when trying to update followed by an exit rather
	# than selecting yes.
	my $update_runnable = Runnable->new(
		command => [ qw(pacman -Syu --ask 20 --noconfirm) ],
		environment => $self->environment,
	);

	# Kill background processes using DLL:
	# <https://www.msys2.org/news/#2020-05-22-msys2-may-fail-to-start-after-a-msys2-runtime-upgrade>
	my $kill_msys2 = Runnable->new(
		command => [ qw(taskkill /f /fi), "MODULES eq msys-2.0.dll" ],
	);

	if( $self->should_run_update ) {
		# Update
		$self->runner->$_try( system => $update_runnable );
		$self->runner->$_try( system => $kill_msys2 );
	}

	if( $self->should_do_gcc9_workaround ) {
		# Workaround GCC9 update issues:
		# Ada and ObjC support were dropped by MSYS2 with GCC9. See commit
		# <https://github.com/msys2/MINGW-packages/commit/0c60660b0cbb485fa29ea09a229cb368e2d01bae>.
		# and broken dependencies issue in <https://github.com/msys2/MINGW-packages/issues/5434>.
		try_tt {
			my @gcc9_remove = qw(
				mingw-w64-i686-gcc-ada   mingw-w64-i686-gcc-objc
				mingw-w64-x86_64-gcc-ada mingw-w64-x86_64-gcc-objc
			);
			$self->runner->system(
				Runnable->new(
					command => [ qw(pacman -R --noconfirm), @gcc9_remove ],
					environment => $self->environment,
				)
			);
		} catch_tt { };
	}

	# Fix mirrors again after update
	$self->_install_prep_update_mirror_list;

	if( $self->should_run_update ) {
		# Update again
		$self->runner->$_try( system => $update_runnable );
		$self->runner->$_try( system => $kill_msys2 );
	}
}

method _install_prep_msys2() {
	$self->_install_prep_msys2_disable_checkspace;

	$self->_install_prep_update_mirror_list;

	$self->_install_prep_msys2_update;
}

method _install() {
	$self->_install_prep_msys2;

	# build tools
	$self->pacman(qw(mingw-w64-x86_64-make mingw-w64-x86_64-toolchain autoconf automake libtool make patch mingw-w64-x86_64-libtool));

	# OpenSSL
	$self->pacman(qw(mingw-w64-x86_64-openssl));

	# There is not a corresponding cc for the mingw64 gcc. So we copy it in place.
	$self->run(qw(cp -pv /mingw64/bin/gcc /mingw64/bin/cc));
	$self->run(qw(cp -pv /mingw64/bin/mingw32-make /mingw64/bin/gmake));

	# Workaround for Data::UUID installation problem.
	# See <https://github.com/rjbs/Data-UUID/issues/24>.
	mkdir 'C:\tmp';

	$self->_install_perl;
}

method _install_perl() {
        # Use shorter path particularly on Windows to avoid Win32 MAX_PATH
        # issues.
        my $tmpdir         = Path::Tiny->tempdir;
        my $cpm_home_dir   = $tmpdir->child( qw(.perl-cpm) );
        my $cpanm_home_dir = $tmpdir->child( qw(.cpanm) );
        local $ENV{PERL_CPANM_HOME} = $cpanm_home_dir;

	$self->pacman(qw(mingw-w64-x86_64-perl));
	# Do not install wget right now. Currently broken (needs to be rebuilt).
	# See <https://github.com/msys2/MINGW-packages/pull/9467#issuecomment-956517299>.
	#$self->pacman(qw(mingw-w64-x86_64-wget)); # needed for cpanm
	$self->build_perl->script( 'pl2bat', $self->build_perl->which_script('pl2bat') );
	{
		local $ENV{PERL_MM_USE_DEFAULT} = 1;
		$self->build_perl->script( qw(cpan App::cpanminus) );
	}
	try_tt {
		$self->build_perl->script( qw(cpanm --mirror-only --info strict));
	} catch_tt {};
	if( $ENV{ORBITAL_MSYS2_CPM_PARALLEL_FORK} ) {
		$self->build_perl->script( qw(cpanm --notest), $_ ) for (
			# App::cpm
			'https://github.com/orbital-transfer/cpm.git@multi-worker-win32',
			# Parallel::Pipes
			'https://github.com/orbital-transfer/Parallel-Pipes.git@multi-worker-win32',
		);
	} else {
		$self->build_perl->script( qw(cpanm --notest), $_ ) for (
			'App::cpm'
		);
	}
	$self->build_perl->script( qw(cpanm --notest ExtUtils::MakeMaker Module::Build App::pmuninstall) );
	$self->build_perl->script( qw(cpanm --notest Win32::Process IO::Socket::SSL) );
}

method run( @command ) {
	$self->runner->system( Runnable->new(
		command => [ @command ],
		environment => $self->environment
	));
}

method pacman(@packages) {
	return unless @packages;
	$self->runner->system(
		Runnable->new(
			command => [ qw(pacman -S --needed --noconfirm), @packages ],
			environment => $self->environment,
		)
	);
}

method choco(@packages) {
	return unless @packages;
	$self->runner->system(
		Runnable->new(
			command => [ qw(choco install -y), @packages ],
			environment => $self->environment,
		)
	);
}

method install_packages($repo) {
	my @mingw_packages = @{ $repo->msys2_mingw64_get_packages };
	my @choco_packages = @{ $repo->chocolatey_get_packages };
	print STDERR "Installing repo native deps\n";
	retry 3, 0, sub {
		$self->pacman(@mingw_packages);
	};
	retry 3, 0, sub {
		$self->choco(@choco_packages);
	};
}

with qw(
	Orbital::Transfer::System::Role::Config
	Orbital::Transfer::System::Role::DefaultRunner
	Orbital::Payload::Env::Perl::System::Role::Perl
);

1;
