package Chaberi::Backdoor::Statistics;
use MooseX::POE;
use Chaberi::Backdoor::Schema;

our $MARGINE = 20 * 60;  # 範囲が連続していると見なす幅


has cont => (
	isa      => 'ArrayRef',
	is       => 'ro',
	required => 1,
);


has page => (
	isa      => 'HashRef',
	is       => 'ro',
	required => 1,
);


# subroutine =====================================
sub _calc_range{
	my ($schema, $room, $nick, $epoch) = @_;

	my $rs = $schema->resultset('EnterRange');

	my $cur_epoch = $rs->search(
		{
			room_id  => $room->id,
			nick_id  => $nick->id,
		}, 
	)->get_column('epoch2')->max;
	if ( $cur_epoch and $epoch - $cur_epoch < $MARGINE ) {
		# 前回の範囲を拡張する
		my $range = $rs->search(
			{
				room_id	 => $room->id,
				nick_id	 => $nick->id,
				epoch2	 => $cur_epoch,
			}, 
		)->first;
		$range->epoch2($epoch);
		$range->update;
		return $range;
	} else {
		# 新規範囲を作成
		return $rs->create(
			{
				room_id => $room->id,
				nick_id => $nick->id,
				epoch1 => $epoch,
				epoch2 => $epoch,
			}
		);
	}
}


# events =====================================

sub START {}

event exec => sub {
	my ($self) = @_[OBJECT, ARG0 .. $#_];

	my $schema = Chaberi::Backdoor::Schema->default_schema;

	# load DB data
	for my $room_info ( @{ $self->page->{rooms} }){
		my $room = $schema->resultset('Room')->find({
			unique_key => $room_info->{link},
		});
		for my $member ( $room_info->{status}->all_members ){
#	my $nick = $_schema->resultset('Nick')->find_or_new(
#		name => normalize_nick($name_str),
#	)->insert();
			my $nick = $schema->resultset('Nick')->find({
				name => $member->name,
			});
			if($nick and $room){
				my $range = _calc_range($schema, $room, $nick, time);
			}
		}
	}


	$POE::Kernel::poe_kernel->post(
		@{ $self->cont }, $self->page
	);
};

no  MooseX::POE;
1;


=head1 NAME

Chaberi::Backdoor::Statistics - culculation with DB.

=head1 DESCRIPTION

=head1 AUTHOR

hiratara E<lt>hira.tara@gmail.comE<gt>

=cut
