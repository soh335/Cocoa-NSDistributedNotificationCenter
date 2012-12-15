use strict;
use warnings;

use Cocoa::EventLoop;
use Cocoa::NSDistributedNotificationCenter;
use DDP;
use Data::Dumper;

my $cnc = Cocoa::NSDistributedNotificationCenter->new;
$cnc->listen('com.apple.iTunes.playerInfo', sub {
    my $info = shift;
    p $info;
    print ""; 
});
Cocoa::EventLoop->run;
