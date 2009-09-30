package Chaberi::Backdoor::Collector;
use strict;
use warnings;


# k1 => v1, k2 => v2, ..., $cb
sub collect {
	my $cb = pop;
	my %params = @_;

	my $urls = delete $params{urls};

	Chaberi::Backdoor::Collector::Task->new(
		cb => $cb,
		($urls ? (urls => $urls) : ()),
	)->collect;
}


package Chaberi::Backdoor::Collector::Task;
use utf8;
use Moose;
use AnyEvent;
use Coro ();
use Coro::AnyEvent ();
use Chaberi::Backdoor::SearchPages;
use Chaberi::Backdoor::Statistics;
use Chaberi::Backdoor::LoadMembers;

has cb => (
	isa      => 'CodeRef',
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
	my $self       = shift;
	my ($ref_done) = @_;

	my @pages;
	for my $ref_url (@{ $self->urls }){
		my ($url, $name) = @$ref_url;

		my $page = $ref_done->{$url};
		$page->{name} = $name;  # add page name destructively

		push @pages, $page;
	}

	return \@pages;
}

sub collect{
	my $self = shift;

	my $cv = AE::cv;
	my %done;

	for my $ref_url (@{ $self->urls }){
		my ($url, $name) = @$ref_url;

		$cv->begin;
		Coro::async {
			my $page = Chaberi::Backdoor::SearchPages::search $url;
			$page = Chaberi::Backdoor::LoadMembers::load $page;
			$page = Chaberi::Backdoor::Statistics::update $page;

			$done{ $page->{url} } = $page;
			$cv->end;
		};
	}

	$cv->cb(sub {
		$self->cb->(
			{
				pages => $self->_merge_all_pages( \%done ), 
			}
		);
	} );
}


__PACKAGE__->meta->make_immutable;
no  Moose;

1;

__END__

=head1 NAME

Chaberi::Backdoor::Collector - collect all page's results

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
