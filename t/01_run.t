use strict;
use Test::More;
use Proclet;
use Parallel::Scoreboard;
use File::Temp qw/tempdir/;

my $sb = Parallel::Scoreboard->new(
    base_dir => tempdir( CLEANUP => 1 )
);

my $pid = fork();

die $! if ! defined $pid;

if ( $pid == 0 ) {
    my $proclet = Proclet->new;
    $proclet->service(
        code => sub {
            $sb->update("sp2plet");
            sleep 6;
        },
        worker => 2
    );
    $proclet->service(
        code => sub {
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

done_testing();

