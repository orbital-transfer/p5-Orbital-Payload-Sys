package Orbital::Payload::Sys::System::Docker::Runner;
# ABSTRACT: Runner for Docker

use Mu;
use Orbital::Transfer::Common::Setup;

use Orbital::Payload::Sys::System::Docker;

extends qw(Orbital::Transfer::Runner::Default);

around _system_with_env_args => sub {
	my ( $orig, $class, @args ) = @_;
	my ($runnable) = @args;
	my @system_args = $orig->($class, @args);
	my $env = $system_args[0];
	my $user_args = $system_args[3];
	if( ! $runnable->admin_privilege && Orbital::Payload::Sys::System::Docker->is_inside_docker ) {
		# become a non-root user
		$user_args->{group} = '1000';
		$user_args->{user} = 1000;
		$env->{HOME} = '/home/notroot';
	}

	return @system_args;
};

1;
