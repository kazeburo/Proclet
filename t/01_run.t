use strict;
use Test::More;
use Proclet;
use Parallel::Scoreboard;
use File::Temp qw/tempdir/;

my $sb = Parallel::Scoreboard->new(
    base_dir => tempdir( CLEANUP => 1 )
);


my $logfile = File::Temp::tmpnam();
my $pid = fork();

die $! if ! defined $pid;

if ( $pid == 0 ) {
    my $proclet = Proclet->new(
        logger => sub {
            my $log = shift;
            open( my $fh, '>>:unix', $logfile );
            print $fh $log;
            close $fh;
        },
    );
    $proclet->service(
        code => sub {
            warn 'sp2plet';
            $sb->update("sp2plet");
            sleep 6;
        },
        worker => 2
    );
    $proclet->service(
        code => sub {
            warn 'sp3plet';
            $sb->update("sp3plet");
            sleep 6;
        },
        worker => 3
    );
    $proclet->run;
    exit;
}

sleep 2;
for (1..2) {
    my $process = 0;
    my $sleep2 = 0;
    my $sleep3 = 0;

    my $stats = $sb->read_all();
    for my $pid (sort { $a <=> $b } keys %$stats) {
        $process++;
        $sleep3++ if $stats->{$pid} =~ m!sp3plet!;
        $sleep2++ if $stats->{$pid} =~ m!sp2plet!;
    }

    is($process,5);
    is($sleep2,2);
    is($sleep3,3);
    sleep 3;
}

kill 'TERM', $pid;
waitpid( $pid, 0);

open(my $fh, $logfile);
my $logok;
while( <$fh> ) {
    $logok++ if $_ =~ m!^\d{2}:\d{2}:\d{2} \d\.\d[ ]+\| sp[23]plet!;
}
is($logok, 10);
done_testing();

