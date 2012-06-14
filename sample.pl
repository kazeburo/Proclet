#!/usr/bin/perl

use strict;
use warnings;
use lib qw/lib/;
use Proclet;

my $proclet = Proclet->new;
$proclet->service(
    code => sub {
        local $0 = "$0 (sleep 5)";
        warn $0;
        sleep 5;
    },
    worker => 2
);
$proclet->service(
    code => sub {
        local $0 = "$0 (sleep 2)";
        warn $0;
        sleep 2;
    },
    worker => 3
);
$proclet->service(
    code => sub {
        exec('/usr/bin/memcached');
    },
);

$proclet->run;

