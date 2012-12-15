use strict;
use warnings;

use Test::More;
use Test::LeakTrace;

use Cocoa::NSDistributedNotificationCenter;

no_leaks_ok {
    my $cnc = Cocoa::NSDistributedNotificationCenter->new;
    undef $cnc;
};

done_testing;
