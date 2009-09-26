package main;
use strict;
use warnings;
use AnyEvent::Impl::EV;
use AnyEvent;
# use Coro::AnyEvent;
use Chaberi::Backdoor;

my $cv = AE::cv;
Chaberi::Backdoor::run sub {
	$cv->send;
};

# into main loop
$cv->recv;
