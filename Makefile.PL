use inc::Module::Install;
name 'Chaberi-Backdoor';
all_from 'lib/Chaberi/Backdoor.pm';

requires 'DBIx::Class';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
