package Chaberi::Backdoor::Schema::Room;
use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table("room");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "chat_id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "unique_key",
  { data_type => "text", is_nullable => 0, size => undef },
  "name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
  "url",
  { data_type => "TEXT", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "enter_ranges",
  "Chaberi::Backdoor::Schema::EnterRange",
  { "foreign.room_id" => "self.id" },
);
__PACKAGE__->belongs_to("chat_id", "Chaberi::Backdoor::Schema::Chat", { id => "chat_id" });

1;

