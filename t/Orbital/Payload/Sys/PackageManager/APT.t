#!/usr/bin/env perl

use Test::Most;

use Orbital::Payload::Sys::PackageManager::APT;
use Orbital::Transfer::Runner::Default;
use Orbital::Payload::Sys::RepoPackage::APT;
use aliased 'Orbital::Transfer::Runnable';

if( ! Orbital::Payload::Sys::PackageManager::APT->loadable ) {
	plan skip_all => 'Test needs Debian system';
} else {
	plan tests => 2;
};

sub init {
	my $runner = Orbital::Transfer::Runner::Default->new;
	my $apt = Orbital::Payload::Sys::PackageManager::APT->new( runner => $runner );

	($runner, $apt);
}

subtest "dpkg package" => sub {
	my ($runner, $apt) = init;

	my $package = Orbital::Payload::Sys::RepoPackage::APT->new( name => 'dpkg' );
	my $version = $apt->installed_version( $package );

	my ($expected_version) = $runner->capture( Runnable->new(
		command => [ qw(dpkg --version) ]
	) ) =~ /program version (\S+)/m;

	my $expected_version_re = qr/^\Q$expected_version\E/;
	like $version, $expected_version_re, 'correct version';

	my @versions = $apt->installable_versions( $package );
	ok grep( { $_ =~ $expected_version_re } @versions), 'dpkg is up to date with installable versions';
};

subtest "Non-existent package" => sub {
	my ($runner, $apt) = init;

	my $package = Orbital::Payload::Sys::RepoPackage::APT->new( name => 'not-a-real-package' );
	throws_ok { $apt->installed_version( $package ) } qr/no packages found/;

	throws_ok { $apt->installable_versions( $package ) } qr/Unable to locate package/;
};

done_testing;
