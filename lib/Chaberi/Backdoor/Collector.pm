package Chaberi::Backdoor::Collector;
use utf8;
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

has urls => (
	isa => 'ArrayRef[ArrayRef]',
	is  => 'ro',
	default => sub { [
		['http://ch1.chaberi.com/' , 'ブルー/トップ'],
		['http://ch1.chaberi.com/2', 'ブルー/2'],
		['http://ch1.chaberi.com/3', 'ブルー/3'],
		['http://ch1.chaberi.com/4', 'ブルー/4'],
		['http://ch1.chaberi.com/5', 'ブルー/5'],
		['http://ch2.chaberi.com/' , 'オレンジ/トップ'],
		['http://ch2.chaberi.com/2', 'オレンジ/2'],
		['http://ch2.chaberi.com/3', 'オレンジ/3'],
		['http://ch2.chaberi.com/4', 'オレンジ/4'],
		['http://ch2.chaberi.com/5', 'オレンジ/5'],
		['http://ch3.chaberi.com/' , 'グリーン/トップ'],
		['http://ch3.chaberi.com/2', 'グリーン/2'],
		['http://ch3.chaberi.com/3', 'グリーン/3'],
		['http://ch3.chaberi.com/4', 'グリーン/4'],
		['http://ch3.chaberi.com/5', 'グリーン/5'],
	] },
);

has _done => (
	isa     => 'HashRef',
	is      => 'ro',
	default => sub { {} },
);



# subroutin  ===============================

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

# destructively method
sub _merge_all_pages{
	my $self = shift;
	my @pages;
	for my $ref_url (@{ $self->urls }){
		my ($url, $name) = @$ref_url;

		my $page = $self->_done->{$url};
		$page->{name} = $name;  # add page name destructively

		push @pages, $page;
	}

	return \@pages;
}

# POE events ===============================
sub START{
	my ($self) = @_[OBJECT, ARG0 .. $#_];
	$self->retain_session;
}


event exec => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];

	for (@{ $self->urls }){
		my $www = Chaberi::Backdoor::SearchPages->new(
			cont => $self->next_event('finished'),
			url  => $_->[0],
		);
		$www->yield( 'exec' );
	}
};


event finished => sub {
	my ($self, $page) = @_[OBJECT, ARG0 .. $#_];

	# record ended pages
	$self->_done->{ $page->{url} } = $page;

	if( keys %{ $self->_done } >= @{ $self->urls } ){
		# exit
		$self->release_session;
		$poe_kernel->post(
			@{ $self->cont } => { 
				pages => $self->_merge_all_pages, 
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
