package Orbital::Payload::Sys::System::Role::RunnerAuto;
# ABSTRACT: Automatically choose runner

use Mu::Role;
use Orbital::Transfer::Common::Setup;

use Orbital::Payload::Sys::System::Docker::Runner;

lazy runner => method() {
	Orbital::Payload::Sys::System::Docker::Runner->new;
};

1;
