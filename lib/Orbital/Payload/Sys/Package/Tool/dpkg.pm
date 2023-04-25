use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::Package::Tool::dpkg;
# ABSTRACT: dpkg package manager

use Orbital::Transfer::Common::Setup;
use Mu;
use aliased 'Orbital::Transfer::Runnable';

method installed_version( $package ) {
	try_tt {
		my ($show_output) = $self->runner->capture(
			Runnable->new(
				command => [ qw(dpkg-query --show), $package->name ]
			)
		);

		chomp $show_output;
		my ($package_name, $version) = split "\t", $show_output;

		$version;
	} catch_tt {
		die "dpkg-query: no packages found matching @{[ $package->name ]}";
	}
}

with qw(Orbital::Transfer::Role::HasRunner);

1;
