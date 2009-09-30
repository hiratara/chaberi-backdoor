package Chaberi::Backdoor::Collector;
use strict;
use warnings;
use utf8;
use Coro ();
use Chaberi::Backdoor::SearchPages;
use Chaberi::Backdoor::Statistics;
use Chaberi::Backdoor::LoadMembers;

our @URLS = (
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
	my ($urls, $ref_done) = @_;

	my @pages;
	for my $ref_url ( @$urls ){
		my ($url, $name) = @$ref_url;

		my $page = $ref_done->{$url};
		$page->{name} = $name;  # add page name destructively

		push @pages, $page;
	}

	return \@pages;
}

sub collect{
	my $urls = shift || \@URLS;

	my @coros;
	my %done;

	for my $ref_url ( @$urls ){
		my ($url, $name) = @$ref_url;

		push @coros, Coro::async {
			my $page = Chaberi::Backdoor::SearchPages::search $url;
			$page = Chaberi::Backdoor::LoadMembers::load $page;
			$page = Chaberi::Backdoor::Statistics::update $page;

			$done{ $page->{url} } = $page;
		};
	}

	$_->join for @coros;

	return {
		pages => (_merge_all_pages $urls, \%done), 
	};
}


1;

__END__

=head1 NAME

Chaberi::Backdoor::Collector - collect all page's results

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
