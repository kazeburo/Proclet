use strict;
use Test::More;
use File::Temp qw/tempdir/;

my $logfile = File::Temp::tmpnam();
my $pid = fork();
$ENV{PROCLET_TESTFILE} = $logfile;

die $! if ! defined $pid;

if ( $pid == 0 ) {
    exec $^X, 't/DeclareProclet.pl';
    die $!;
}

sleep 3;
kill 'TERM', $pid;
waitpid( $pid, 0);

open(my $fh, $logfile);
my %logok;
while( <$fh> ) {
    chomp;
    my @l = split / /;
    $logok{$l[0]} ||= {};
    $logok{$l[0]}->{$l[1]} = 1;
}

is( scalar keys %{$logok{w1}}, 1);
is( scalar keys %{$logok{w2}}, 2);

done_testing();


