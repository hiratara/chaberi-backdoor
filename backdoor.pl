package main;
use strict;
use warnings;
use POE;
use Chaberi::Backdoor;

Chaberi::Backdoor->new;

my $time = time;
POE::Kernel->run;
print time - $time, "\n";
