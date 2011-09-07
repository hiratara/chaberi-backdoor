use inc::Module::Install;
name 'Chaberi-Backdoor';
all_from 'lib/Chaberi/Backdoor.pm';

requires 'DBIx::Class';
requires 'Template';
requires 'Plack';
requires 'Twiggy';
requires 'JSON';
requires 'Coro';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
test_requires 'Amon2';
auto_set_repository;
auto_include;
WriteAll;
