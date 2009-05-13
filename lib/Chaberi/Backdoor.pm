package Chaberi::Backdoor;
use MooseX::POE;
use Template;
use Chaberi::Backdoor::SearchPages;

with 'POE::Component::Chaberi::Role::NextEvent';

has timeout_sec => (
	isa => 'Int',
	is  => 'ro',
	default => 60 * 3,
);

has _start_epoch => (
	isa     => 'Int',
	is      => 'ro',
	default => sub { scalar time },
);

has _timeout_alarm => (
	isa => 'Int',
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


# events =======================
sub START {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	my $collector = Chaberi::Backdoor::Collector->new(
		cont => $self->next_event('finished'),
	);
	$collector->yield('exec');

	# set timeout
	$self->_timeout_alarm( 
		$poe_kernel->delay_set( timeout => $self->timeout_sec )
	);
}

event finished => sub {
	my ($self, $info) = @_[OBJECT, ARG0 .. $#_];

	# reset timeout timer
	$poe_kernel->alarm_remove( $self->_timeout_alarm );

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
};


event timeout => sub {
	die "timeouted\n";
};


no  MooseX::POE;

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
