#!/usr/bin/env perl

use Test::Most tests => 1;

use lib 't/lib';

use Orbital::Transfer::Test::Oracle::Ansible;

subtest "Run Ansible" => sub {
	my $ansible = Orbital::Transfer::Test::Oracle::Ansible->new;
	plan skip_all => 'Unable to query Ansible' unless $ansible->can_query;
	my $data = $ansible->query_localhost_builtin_setup;
	ok $data, 'has data';
};

done_testing;
