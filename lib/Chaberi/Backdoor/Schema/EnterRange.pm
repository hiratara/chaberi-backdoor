package Chaberi::Backdoor::Schema::EnterRange;
use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("PK::Auto", "Core");
__PACKAGE__->table("enter_range");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "nick_id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "room_id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "epoch1",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "epoch2",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to("nick_id", "Chaberi::Backdoor::Schema::Nick", { id => "nick_id" });
__PACKAGE__->belongs_to("room_id", "Chaberi::Backdoor::Schema::Room", { id => "room_id" });

1;

