package Chaberi::Backdoor;
use MooseX::POE;
use Template;
use Chaberi::Backdoor::SearchPages;

with 'POE::Component::Chaberi::Role::NextEvent';

sub _level {
	my $ref = shift;
	my ($epoch1, $epoch2) = @{ $ref->{range} || [0, 0] };
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

sub START {
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	my $collector = Chaberi::Backdoor::Collector->new(
		cont => $self->next_event('finished'),
	);
	$collector->yield('exec');
}

event finished => sub {
	my ($self, $info) = @_[OBJECT, ARG0 .. $#_];
	my $tt = Template->new(
		ENCODING => 'utf8', 
	);
	$tt->process('moto.tt', {
		info    => $info,
		FUNC_LV => \&_level,

	}, \my $out) or die $tt->error;

	open my $fh, '>:utf8', 'out.html' or die;
	print $fh $out;
	close $fh;
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
