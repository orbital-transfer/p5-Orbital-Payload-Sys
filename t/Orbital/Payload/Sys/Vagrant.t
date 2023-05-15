#!/usr/bin/env perl

use Test2::V0;

use lib 't/lib';

use Orbital::Payload::Sys::Vagrant;
use File::Which;

subtest "Global status" => sub {
	# NOTE The example data does not have the right space padding that the
	# actual Vagrant output has for the UI type output, but this is not a
	# problem.
	subtest "Parse empty example output" => sub {
		my $data = Orbital::Payload::Sys::Vagrant->new->process_global_status_data(<<'EOF');
1684113113,,metadata,machine-count,0
1684113113,,ui,info,id
1684113113,,ui,info,name
1684113113,,ui,info,provider
1684113113,,ui,info,state
1684113113,,ui,info,directory
1684113113,,ui,info,
1684113113,,ui,info,--------------------------------------------------------------------
1684113113,,ui,info,There are no active Vagrant environments on this computer! Or%!(VAGRANT_COMMA)\nyou haven't destroyed and recreated Vagrant environments that were\nstarted with an older version of Vagrant.
EOF

		is( $data, [] );
	};

	subtest "Parse example output" => sub {
		my $data = Orbital::Payload::Sys::Vagrant->new->process_global_status_data(<<'EOF');
1684035540,,metadata,machine-count,2
1684035540,,machine-id,e8ad859
1684035540,,provider-name,virtualbox
1684035540,,machine-home,/path/to/orbital-transfer-example/perl-gtk3-starter-basic
1684035540,,state,saved
1684035540,,machine-id,4ef0194
1684035540,,provider-name,virtualbox
1684035540,,machine-home,/path/to/sw_projects/PDLPorters/pdl/i386-box
1684035540,,state,running
1684035540,,ui,info,id
1684035540,,ui,info,name
1684035540,,ui,info,provider
1684035540,,ui,info,state
1684035540,,ui,info,directory
1684035540,,ui,info,
1684035540,,ui,info,---------------------------------------------------------------------------------------------------------------------------------------------------------
1684035540,,ui,info,e8ad859
1684035540,,ui,info,default
1684035540,,ui,info,virtualbox
1684035540,,ui,info,saved
1684035540,,ui,info,/path/to/orbital-transfer-example/perl-gtk3-starter-basic
1684035540,,ui,info,
1684035540,,ui,info,4ef0194
1684035540,,ui,info,i386
1684035540,,ui,info,virtualbox
1684035540,,ui,info,running
1684035540,,ui,info,/path/to/sw_projects/PDLPorters/pdl/i386-box
1684035540,,ui,info,
1684035540,,ui,info, \nThe above shows information about all known Vagrant environments\non this machine. This data is cached and may not be completely\nup-to-date (use "vagrant global-status --prune" to prune invalid\nentries). To interact with any of the machines%!(VAGRANT_COMMA) you can go to that\ndirectory and run Vagrant%!(VAGRANT_COMMA) or you can use the ID directly with\nVagrant commands from any directory. For example:\n"vagrant destroy 1a2b3c4d"
EOF
		is( $data, array {
				item hash {
					field 'id'        => 'e8ad859';
					field 'name'      => 'default';
					field 'provider'  => 'virtualbox';
					field 'state'     => 'saved';
					field 'vagrantfile_path' => '/path/to/orbital-transfer-example/perl-gtk3-starter-basic';
				};
				item hash {
					field 'id'        => '4ef0194';
					field 'name'      => 'i386';
					field 'provider'  => 'virtualbox';
					field 'state'     => 'running';
					field 'vagrantfile_path' => '/path/to/sw_projects/PDLPorters/pdl/i386-box';
				};
				end;
			}, 'parsed output');
	};

	subtest "Call actual vagrant global-status" => sub {
		skip_all "No vagrant executable" unless which 'vagrant';
		my $output = Orbital::Payload::Sys::Vagrant->new->global_status;
		ok $output, 'got output';

		my $data = Orbital::Payload::Sys::Vagrant->new->process_global_status_data($output);
		is( $data, D() );
	};
};

done_testing;
