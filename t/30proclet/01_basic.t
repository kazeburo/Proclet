use strict;
use Test::More;
use File::Temp qw/tempdir/;

my $logfile = File::Temp::tmpnam();
my $pid = fork();
$ENV{PROCLET_TESTFILE} = $logfile;

die $! if ! defined $pid;

if ( $pid == 0 ) {
    chdir 't/30proclet/procfile';
    exec $^X, '../../../bin/proclet', 'start';
    exit;
}

sleep 2;
open(my $fh, $logfile);
my $logok;
while( <$fh> ) {
    $logok++;
}
close $fh;
ok($logok);
kill 'TERM', $pid;
waitpid( $pid, 0);

done_testing();
