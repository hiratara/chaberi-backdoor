package main;
use strict;
use warnings;
use utf8;
use File::Basename qw/dirname/;
use AnyEvent::Impl::EV ();
use AnyEvent ();
use AnyEvent::HTTP;
use Chaberi::AnyEvent::LobbyPage qw/chaberi_lobby_page/;
use Chaberi::Backdoor::Schema;
use Data::Monad::CondVar;
use Template;
use Encode;
use JSON;

my $start_epoch = time;

my @urls = (
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

my $timeout = 60 * 3;
my $margine = 20 * 60;  # 範囲が連続していると見なす幅


sub _get_members($$$){
	my ( $address, $port, $ref_rooms) = @_;
	my $url = 'http://localhost:10081?' . 
	          join '&', ('address=' . $address), 
	                    ('port=' . $port), 
	                    (map { 'room=' . $_ } @$ref_rooms);

	as_cv { http_get $url, timeout => 30, $_[0] }->map(sub {;
		my ($data, $headers) = @_;
		return undef unless ($headers->{Status} =~ /^2/);
		return JSON->new->utf8(1)->decode($data);
	});
}


sub _calc_range{
	my ($room, $nick) = @_;
	my $schema = Chaberi::Backdoor::Schema->default_schema;

	my $now_epoch = time;
	my $rs = $schema->resultset('EnterRange');

	my $cur_epoch = $rs->search(
		{
			room_id  => $room->id,
			nick_id  => $nick->id,
		}, 
	)->get_column('epoch2')->max;
	if ( $cur_epoch and $now_epoch - $cur_epoch < $margine ) {
		# 前回の範囲を拡張する
		my $range = $rs->search(
			{
				room_id	 => $room->id,
				nick_id	 => $nick->id,
				epoch2	 => $cur_epoch,
			}, 
		)->first;
		$range->epoch2($now_epoch);
		$range->update;
		return $range;
	} else {
		# 新規範囲を作成
		return $rs->create(
			{
				room_id => $room->id,
				nick_id => $nick->id,
				epoch1 => $now_epoch,
				epoch2 => $now_epoch,
			}
		);
	}
}


sub crowl_url {
	my ( $ref_url ) = @_;
	my ($url, $name) = @$ref_url;

	return chaberi_lobby_page($url)->flat_map(sub {
		my $lobby = shift or return AnyEvent::CondVar->unit();
		return _get_members(
			$lobby->{host}, $lobby->{port}, 
			[map { $_->{id} } @{$lobby->{rooms}}]
		)->map(sub {
			my $room_data = shift or return;
			return $lobby, $room_data;
		});
	})->map(sub {
		my ($lobby, $room_data) = @_;
		my %statuses = map { $_->{room_id} => $_->{room_status} } @$room_data;

		my $schema = Chaberi::Backdoor::Schema->default_schema;
		my @rooms;
		for my $room ( @{$lobby->{rooms}} ){
			my $status = $statuses{ $room->{id} };

			my $obj_room = $schema->resultset('Room')->find({
				unique_key => $room->{link},
			});

			my @members;
			for my $member ( @{ $status->{members} } ){
				my $range;
				if( $obj_room ){
					my $obj_nick = $schema->resultset('Nick')->find_or_new(
						name => $member->{name},
					)->insert();

					my $obj_range = _calc_range $obj_room, $obj_nick ;
					$range = [$obj_range->epoch1, $obj_range->epoch2];
				}
				push @members, {
					name  => $member->{name},
					range => $range,
					# Do we need neither $_->status nor $_->is_owner ??
				};
			}

			push @rooms, {
				name    => $room->{name}, 
				url     => $room->{link}, 
				ad      => $status->{advertising},
				members => \@members,
			};

		}

		# return "$page"
		return {
			url   => $url   ,
			name  => $name  , # add page name destructively
			rooms => \@rooms,
		};
	});
}


sub crowl {
	my $ref_urls = shift;

	my @cvs;
	my %pages;
	for my $ref_url ( @$ref_urls ){
		push @cvs, crowl_url($ref_url)->map(sub {
			$pages{$ref_url->[0]} = $_[0];
			return; # void
		});
	}

	AnyEvent::CondVar->sequence(@cvs)->map(sub {
		{pages => [map { $pages{$_->[0]} } @$ref_urls]};
	});
}


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

my $config;
sub config() {
	unless ($config) {
		my $file = dirname(__FILE__) . '/config.pl';
		-f $file and $config = do $file;
	}
	return $config;
}

sub output{
	my $info = shift;

	my $data = {
		info      => $info,
		finished  => scalar localtime,
		exec_time => time - $start_epoch,
	};

	my $tt = Template->new(
		ENCODING => 'utf8', 
	);
	$tt->process(
		dirname(__FILE__) . '/moto.tt', {FUNC_LV => \&_level, %$data}, \my $out
	) or die $tt->error;

	{
		open my $fh, '>:utf8', config->{output_dir} . '/out.html' or die;
		print $fh $out;
		close $fh;
	}

	{
		open my $fh, '>:utf8', config->{output_dir} . '/out.json' or die;
		print $fh JSON->new->utf8( 0 )->encode( $data );
		close $fh;
	}

	return
}


crowl(\@urls)->timeout($timeout)->map(sub {
	my $info = shift or return AnyEvent::CondVar->fail("timeouted");
	output $info;
	return;  # void
})->recv;
