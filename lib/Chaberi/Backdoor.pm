package Chaberi::Backdoor;
use strict;
use warnings;

# k1 => v1, k2 => v2, ..., $cb
sub run{
	my $cb = pop;
	my %params = @_;

	my $timeout = delete $params{timeout_sec};

	Chaberi::Backdoor::Task->new(
		cb => $cb,
		($timeout ? (timeout_sec => $timeout) : ()),
	)->run;
}


package Chaberi::Backdoor::Task;
use Moose;
use Template;
use Chaberi::Backdoor::Collector;

has timeout_sec => (
	isa => 'Int',
	is  => 'ro',
	default => 60 * 3,
);

has cb => (
	isa      => 'CodeRef',
	is       => 'ro',
	required => 1,
);

has _start_epoch => (
	isa     => 'Int',
	is      => 'ro',
	default => sub { scalar time },
);

has _timeout_timer => (
	isa => 'Maybe[Object]',
	is  => 'rw',
);


# subroutine 
sub _level {
	my $member = shift;
	my ($epoch1, $epoch2) = @{ $member->{range} || [0, 0] };
	my $len = ($epoch2 - $epoch1) / 60;
	if ($len < 10) {
		return 1;
	} elsif ($len < 30) {
		return 2;
	} elsif ($len < 60) {
		return 3;
	} elsif ($len < 180) {
		return 4;
	} else {
		return 5;
	}
}

sub finished {
	my $self = shift;
	my ($info) = @_;

	# reset timeout timer
	$self->_timeout_timer( undef );

	my $tt = Template->new(
		ENCODING => 'utf8', 
	);
	$tt->process('moto.tt', {
		info      => $info,
		FUNC_LV   => \&_level,
		finished  => scalar localtime,
		exec_time => time - $self->_start_epoch,
	}, \my $out) or die $tt->error;

	open my $fh, '>:utf8', 'out.html' or die;
	print $fh $out;
	close $fh;

	# callback
	$self->cb->();
};

sub run {
	my $self = shift;

	Chaberi::Backdoor::Collector::collect
		sub { $self->finished(@_); };

	# set timeout
	$self->_timeout_timer( 
		AE::timer $self->timeout_sec, 0, sub {
			# XXX should not die with AnyEvent loop
			die "timeouted\n";
		}
	);
}

__PACKAGE__->meta->make_immutable;
no  Moose;

__END__


=head1 NAME

Chaberi::Backdoor - backdoor of chaberi

=head1 DESCRIPTION

get chaberi data and make a html.

Backdoor -> Collector -> SearchPages -> LoadMembers -> Statistics +
                ^                                                 |
                |                                                 |
                +----------<------------<-------------<-----------+

SearchPages make page data(hashref), and Loadmembers and Statistics marge
information into it.

Collector catches the all page data, and write it down in html.

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
