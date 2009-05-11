package Chaberi::Backdoor::Schema;
use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes;

sub _get_current_dir{
	(my $ret = $0) =~ s|[^/]+$|| or die;
	return $ret;
}

*default_schema = ( sub {
	my $_schema;
	return sub {
		my $class = shift;
		$_schema = $class->connect(
			sprintf(
				'dbi:SQLite:dbname=%sdatabase/chat_watch', 
				_get_current_dir(),
			)
		) unless $_schema;
		return $_schema;
	};
} )->();

1;
