use strict;
use Test::More;
use Proclet;

my $ps = `LC_ALL=C command ps -e -o ppid,pid,command`;
if ( $? == -1 || $? & 127 ) {
    plan skip_all => "command ps failed";
}
else {
    plan tests => 6;
}

my $pid = fork();

die $! if ! defined $pid;

if ( $pid == 0 ) {
    my $proclet = Proclet->new;
    $proclet->service(
        code => sub {
            local $0 = "$0_sp2plet";
            sleep 6;
        },
        worker => 2
    );
    $proclet->service(
        code => sub {
            local $0 = "$0_sp3plet";
            sleep 6;
        },
        worker => 3
    );
    $proclet->run;
    exit;
}

sleep 2;
for (1..2) {
    my $ps = `LC_ALL=C command ps -e -o ppid,pid,command`;

    my $process = 0;
    my $sleep2 = 0;
    my $sleep3 = 0;

    for my $line ( split /\n/, $ps ) {
        next if $line =~ m/^\D/;
        my ($ppid, $cpid, $command) = split /\s+/, $line, 3;
        next if ( $ppid != $pid && $cpid != $pid);
    
        $process++;
        $sleep3++ if $command =~ m!sp3plet!;
        $sleep2++ if $command =~ m!sp2plet!;
    }

    is($process,6);
    is($sleep2,2);
    is($sleep3,3);
    sleep 3;
}

kill 'TERM', $pid;
waitpid( $pid, 0);

