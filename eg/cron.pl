#!/usr/bin/perl

use strict;
use warnings;
use lib qw/lib/;
use Proclet;
use Log::Minimal;

my $proclet = Proclet->new;
$proclet->service(
    tag => 'cron_sample',
    code => sub {
        warnf $0;
        sleep 5;
    },
    worker => 2,
    every => '* * * * *'
);

$proclet->run;

