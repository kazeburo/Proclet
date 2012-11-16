use strict;
use warnings;
use Proclet::Declare;

service(
    'w1',
    $^X,
    '-e',
    'for(1..100){ open(my $fh, ">>:unix", $ENV{PROCLET_TESTFILE}) or die $!; print $fh "w1 $$\n"; close $fh; sleep 1}'
);

service(
    'w2',
    $^X,
    '-e',
    'for(1..100){ open(my $fh, ">>:unix", $ENV{PROCLET_TESTFILE}) or die $!; print $fh "w2 $$\n"; close $fh; sleep 1}'
);

worker(
    'w2' => 2
);

run;

