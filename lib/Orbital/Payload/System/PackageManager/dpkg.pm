use Modern::Perl;
package Orbital::Payload::System::PackageManager::dpkg;
# ABSTRACT: dpkg package manager

use Mu;
use Orbital::Transfer::Common::Setup;
use aliased 'Orbital::Transfer::Runnable';
use Try::Tiny;

method installed_version( $package ) {
	try {
		my ($show_output) = $self->runner->capture(
			Runnable->new(
				command => [ qw(dpkg-query --show), $package->name ]
			)
		);

		chomp $show_output;
		my ($package_name, $version) = split "\t", $show_output;

		$version;
	} catch {
		die "dpkg-query: no packages found matching @{[ $package->name ]}";
	}
}

with qw(Orbital::Transfer::Role::HasRunner);

1;
