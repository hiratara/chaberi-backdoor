package Chaberi::Backdoor::Schema;
use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes;

*default_schema = do {
	my $_schema;
	sub {
		my $class = shift;
		$_schema = $class->connect(
			'dbi:SQLite:dbname=./database/chat_watch'
		) unless $_schema;
		return $_schema;
	};
};

1;
