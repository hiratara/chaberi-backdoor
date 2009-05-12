package Chaberi::Backdoor::Collector;
use MooseX::POE;
use POE;
use Chaberi::Backdoor::SearchPages;

with 'POE::Component::Chaberi::Role::NextEvent', 
     'POE::Component::Chaberi::Role::RetainSession';

has cont => (
	isa      => 'ArrayRef',
	is       => 'ro',
	required => 1,
);

has _urls => (
	isa     => 'ArrayRef',
	is      => 'ro',
	default => sub { [] },
);

has _done => (
	isa     => 'HashRef',
	is      => 'ro',
	default => sub { {} },
);


sub START{
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	$self->retain_session;

	# set pages to search.
	for my $ch (0 .. 2) {
		for my $p (1 .. 5) {
			push @{ $self->_urls }, "http://ch$ch.chaberi.com/$p";
		}
	}
}


event exec => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];

	for (@{ $self->_urls }){
		my $www = Chaberi::Backdoor::SearchPages->new(
			cont => $self->next_event('finished'),
			url  => $_,
		);
		$www->yield( 'exec' );
	}
};


=over

{
	pages => [
		{  # $page
			_host => 'socket host',  # temporary
			_port => 'socket port',  # temporary
			name  => 'ページ名',
			url   => 'URL',
			rooms => [
				{ # room
					_id  => 'ID in chaberi',  # temporary
					url  => 'URL',
					name => '部屋名',
					ad   => '呼び込み'
					members => [
						{ # member
							name  => 'ニック',
							range => [epoch1, epoch2],
						},
						...
					]
				},
				...
			],
		},
		...
	],
}

=cut

event finished => sub {
	my ($self, $page) = @_[OBJECT, ARG0 .. $#_];

	# record ended pages
	$self->_done->{ $page->{url} } = $page;

	if( keys %{ $self->_done } >= @{ $self->_urls } ){
		# exit
		$self->release_session;
		$poe_kernel->post(
			@{ $self->cont } => { 
				pages => [ map { $self->_done->{$_} } @{ $self->_urls } ], 
			},
		);
	}

};

no  MooseX::POE;

__END__

=head1 NAME

Chaberi::Backdoor::Collector - collect all page's results

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
