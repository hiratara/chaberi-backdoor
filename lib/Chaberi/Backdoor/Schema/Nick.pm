package Chaberi::Backdoor::Schema::Nick;
use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("PK::Auto", "Core");
__PACKAGE__->table("nick");
__PACKAGE__->add_columns(
  "id",
  { data_type => "INTEGER", is_nullable => 0, size => undef },
  "name",
  { data_type => "TEXT", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "enter_ranges",
  "Chaberi::Backdoor::Schema::EnterRange",
  { "foreign.nick_id" => "self.id" },
);
1;
