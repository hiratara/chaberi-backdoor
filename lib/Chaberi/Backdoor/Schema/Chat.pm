package Chaberi::Backdoor::Schema::Chat;
use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components(qw/UTF8Columns PK::Auto Core/);
__PACKAGE__->table("chat");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
);
__PACKAGE__->utf8_columns(qw/name/);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "rooms",
  "Chaberi::Backdoor::Schema::Room",
  { "foreign.chat_id" => "self.id" },
);

1;

