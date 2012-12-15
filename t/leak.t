use strict;
use warnings;

use Test::More;
use Test::LeakTrace;
use Cocoa::EventLoop;
use Cocoa::NSDistributedNotificationCenter;
use DDP;
use Data::Dumper;

no_leaks_ok {
    my $done;
    my $cnc; $cnc = Cocoa::NSDistributedNotificationCenter->new;
    $cnc->listen('com.apple.iTunes.playerInfo', sub {
        my $info = shift;
        $cnc = undef;
        $done++;
    });
    Cocoa::EventLoop->run_while(0.1) while !$done;
};

done_testing;
