use Orbital::Transfer::Common::Setup;
package Orbital::Payload::Sys::Vagrant;
# ABSTRACT: Vagrant tool for virtualization provisioning

use Moo;

use Capture::Tiny qw(capture_stdout);
use List::Util::MaybeXS qw(first);
use Devel::StrictMode;
use Carp::Assert;
use Text::Trim qw(rtrim);
use Hash::Merge;

method global_status() {
	my ($output, $exit) = capture_stdout {
		local $ENV{VAGRANT_CHECKPOINT_DISABLE} = 1;
		system( qw( vagrant global-status --machine-readable ) );
	};

	return $output;
}

# <https://developer.hashicorp.com/vagrant/docs/cli/machine-readable>
# <https://developer.hashicorp.com/vagrant/docs/v2.3.4/cli/machine-readable>
method parse_machine_readable_output($csv_text) {
	my @headers = qw(timestamp target type data);
	my @data = map {
		my %h;
		my @columns =  map {
			(my $c = $_) =~ s/\Q%!(VAGRANT_COMMA)\E/,/g;
			$c =~ s/\Q\n\E/\n/g;
			$c =~ s/\Q\r\E/\r/g;
			$c;
		} split ',', $_, -1;
		@h{@headers} = ( @columns[0..2], [ @columns[3..$#columns] ] );
		\%h;
	} split /\n/, $csv_text;
	\@data;
}

method process_global_status_data($output) {
	my $data = $self->parse_machine_readable_output($output);

	my %key_data = (
		id => { data => 'machine-id', 'ui' => 'id' },
		provider => { data => 'provider-name', ui => 'provider' },
		state => { data => 'state', ui => 'state' },
		vagrantfile_path => { data => 'machine-home', ui => 'directory' },
		name => { ui => 'name' },
	);

	# Not all keys exist in the data
	my %data_to_key = map { exists $key_data{$_}{data} ? ( $key_data{$_}{data} => $_ ) : () } keys %key_data;
	my %columns_to_key = map { $key_data{$_}{ui} => $_ } keys %key_data;

	affirm {
		$data->[0]{type} eq 'metadata'
		&& $data->[0]{data}[0] eq 'machine-count';
	} if STRICT;

	my $machine_count = $data->[0]{data}[1];

	my $first_ui_idx = first { $data->[$_]{type} eq 'ui' } 0..$#{$data};

	# Split into machine readable and UI sections of output.
	my @machine_readable = $data->@[1..$first_ui_idx-1];
	my @ui = $data->@[$first_ui_idx .. $#{$data} ];

	my @machines = map {
		my $machine_idx = $_;
		my $start_idx = $machine_idx * ( keys %data_to_key );
		my %h = map {
			$data_to_key{ $machine_readable[$_]{type} }
				=> $machine_readable[$_]{data}[0]
		} $start_idx .. $start_idx + ( keys %data_to_key  )-1;

		\%h
	} 0..$machine_count-1;

	my @headers;
	while(1) {
		my $current_row_data = $ui[0]{data}[1];
		shift @ui;
		last if $current_row_data eq '';
		push @headers, rtrim($current_row_data);
	}

	affirm { @headers == 0+keys %columns_to_key } 'Check header length' if STRICT;

	die "Table dash missing in Vagrant output" unless $ui[0]{data}[1] =~ /^-+$/;
	shift @ui;

	my $merger = Hash::Merge->new('LEFT_PRECEDENT');
	for my $machine_idx (0..$machine_count-1) {
		my $start_idx = $machine_idx * ( @headers + 1 );
		my %h = map { $columns_to_key{ $headers[$_] } => rtrim($ui[ $start_idx + $_ ]{data}[1]) } 0 .. $#headers;

		$machines[$machine_idx] = $merger->merge( $machines[$machine_idx], \%h );
	}

	\@machines;
}

method path_to_machine_index() {
	# NOTE The ~ expands for a given user.
	path('~/.vagrant.d/data/machine-index/index');
};

1;
