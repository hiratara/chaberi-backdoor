package main;
use strict;
use warnings;
use POE;
use Chaberi::Backdoor;

Chaberi::Backdoor->new;

POE::Kernel->run;
