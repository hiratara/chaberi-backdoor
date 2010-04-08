package main;
use strict;
use warnings;
use utf8;
use AnyEvent::Impl::EV ();
use AnyEvent ();
use Coro;
use Coro::Timer ();
use Coro::AnyEvent ();
use Chaberi::Coro;
use Chaberi::Backdoor::Schema;
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

	my $lobby = Chaberi::Coro::lobby_page $url or return undef;

	my $room_data = Chaberi::Coro::get_members 
		$lobby->{host}, 
		$lobby->{port}, 
		[ map { $_->{id} } @{ $lobby->{rooms} } ] or return undef;
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
}


sub crowl {
	my $ref_urls = shift;

	my @coros;
	my %pages;
	for my $ref_url ( @$ref_urls ){
		push @coros, Coro::async {
			$pages{ $ref_url->[0] } = crowl_url $ref_url;
		};
	}

	$_->join for @coros;

	# return "$info"
	return { pages => [ map { $pages{$_->[0]} } @$ref_urls ] };
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
	$tt->process('moto.tt', {FUNC_LV => \&_level, %$data}, \my $out) 
	                                                        or die $tt->error;

	{
		open my $fh, '>:utf8', 'out.html' or die;
		print $fh $out;
		close $fh;
	}

	{
		open my $fh, '>:utf8', 'out.json' or die;
		print $fh JSON->new->utf8( 0 )->encode( $data );
		close $fh;
	}

	return
}


my $info;

{
	my $timeouted = Coro::Timer::timeout $timeout;

	my $cur_coro = $Coro::current;
	Coro::async {
		$info = crowl \@urls;
		$cur_coro->ready;
	};
	schedule;

	die "timeouted\n" if $timeouted;
}

output $info;
