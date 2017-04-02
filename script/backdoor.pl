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
use Text::Xslate;
use Encode;
use JSON;

my $start_epoch = time;

my @urls = (
	['http://ch1.chaberi.com/' , 'ブルー/トップ'],
	['http://ch1.chaberi.com/2', 'ブルー/2'],
	['http://ch1.chaberi.com/3', 'ブルー/3'],
);

my $timeout = 60 * 3;
my $margine = 20 * 60;  # 範囲が連続していると見なす幅

my $config;
sub config() {
	unless ($config) {
		my $file = dirname(__FILE__) . '/config.pl';
		-f $file and $config = do $file;
	}
	return $config;
}

sub _get_members($$$){
	my ( $address, $port, $ref_rooms) = @_;
	my $url = 'http://localhost:10082?' .
	          join '&', ('address=' . $address), 
	                    ('port=' . $port), 
	                    (map { 'room=' . $_ } @$ref_rooms);

	my $guard = http_get $url, timeout => 30, (my $cv = AE::cv);
	$cv->canceler(sub { undef $guard });

	$cv->map(sub {
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

sub _convert_link ($) {
    my $orig_url = shift;
    if ($orig_url =~ m{^http://ch(\d).chaberi.com/chat/([^/]+)/(\d+)$}) {
        config->{url_base} . "$1/$2/$3";
    } else {
	$orig_url;
    }
}

sub _polish_room_info($$) {
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
		for my $member ( @{ $status->{members} } ) {
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
			url     => _convert_link $room->{link},
			ad      => $status->{advertising},
			members => \@members,
		};

	}

	cv_unit @rooms;
}


sub crowl_url {
	my ( $ref_url ) = @_;
	my ($url, $name) = @$ref_url;

	call_cc {
		my $cont = shift;

		chaberi_lobby_page($url)->flat_map(sub {
			my $lobby = shift or return $cont->();
			return _get_members(
				$lobby->{host}, $lobby->{port},
				[map { $_->{id} } @{$lobby->{rooms}}]
			)->flat_map(sub {
				my $room_data = shift or return $cont->();
				_polish_room_info($lobby, $room_data);
			});
		});
	}->catch(sub {
		warn @_;
		cv_unit;
	})->map(sub {
		# return "$page"
		return {
			url   => $url   ,
			name  => $name  , # add page name destructively
			rooms => [@_],
		};
	});
}


sub crowl {
	my $ref_urls = shift;

	AnyEvent::CondVar->all(map { crowl_url($_) } @$ref_urls)
		->map(sub { {pages => [map { @$_ } @_]} });
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

	my $tx = Text::Xslate->new(
		function => {level => \&_level}
	);
	my $out = $tx->render(
		dirname(__FILE__) . '/moto.tt', $data
	);

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


my $info = crowl(\@urls)->timeout($timeout)->recv or die "timeouted";
output $info;
