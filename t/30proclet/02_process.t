use strict;
use Test::More;
use File::Temp qw/tempdir tempfile/;

my ($tmpfh, $logfile) = tempfile(UNLINK=>0,EXLOCK=>0);
my $pid = fork();
$ENV{PROCLET_TESTFILE} = $logfile;

die $! if ! defined $pid;

if ( $pid == 0 ) {
    chdir 't/30proclet/procfile';
    exec $^X, '-I../../../lib','../../../bin/proclet', 'start','w2';
    exit;
}

for (1..10) {
    open( my $fh, $logfile);
    my @lines = <$fh>;
    last if @lines > 2;
    sleep 1;
}

open(my $fh, $logfile);
my %logok;
while( <$fh> ) {
    chomp;
    my @l = split / /;
    $logok{$l[0]} ||= {};
    $logok{$l[0]}->{$l[1]} = 1;
}
close $fh;
ok(!exists $logok{w1});
is( scalar keys %{$logok{w2}},2);

kill 'TERM', $pid;
waitpid( $pid, 0);
unlink($logfile);
done_testing();
