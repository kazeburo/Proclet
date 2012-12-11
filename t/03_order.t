use strict;
use Test::More;
use Proclet;
use File::Temp qw/tempdir/;

my $logfile = File::Temp::tmpnam();
my $pid = fork();

if ( $pid == 0 ) {
    my $proclet = Proclet->new(
        logger => sub {
            my $log = shift;
            open( my $fh, '>>:unix', $logfile );
            print $fh $log;
            close $fh;
        },
        spawn_interval => 1,
    );
    $proclet->service(
        code => sub {
            warn 'sp2';
            sleep 1 for 1..60;
        },
        worker => 2
    );
    $proclet->service(
        code => sub {
            warn 'sp3';
            sleep 1 for 1..60;
        },
        worker => 3
    );
    $proclet->run;
    exit;
}

sleep 8;

kill 'TERM', $pid;
waitpid( $pid, 0);

open(my $fh, $logfile);
my @log;
while( <$fh> ) {
    if ( $_ =~ m!^\d{2}:\d{2}:\d{2} \d\.\d[ ]+\| (sp[23])! ) {
        push @log , $1;
    }
}
is_deeply(\@log, [qw/sp2 sp2 sp3 sp3 sp3/]);
unlink($logfile);
done_testing();
