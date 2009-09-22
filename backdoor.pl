package main;
use strict;
use warnings;
use AnyEvent::Impl::POE;
use AnyEvent;
# use Coro::AnyEvent;
use Chaberi::Backdoor;

my $cv = AE::cv;
Chaberi::Backdoor->new( condvar => $cv );

# into main loop
$cv->recv;
