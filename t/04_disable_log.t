use strict;
use Test::More;
use Proclet;
use Test::Requires {
    'Capture::Tiny' => '0.21',
};
use File::Temp qw/tempdir/;

my $stderr  = Capture::Tiny::capture_stderr {
    my $pid = fork();
    die "cannot fork: $!" if ! defined $pid;
    if ( $pid == 0 ) {
        my $proclet = Proclet->new(
            enable_log_worker => 0,
        );
        $proclet->service(
            code => sub {
                warn 'proclet disable log';
                sleep 1;
            },
        );
        $proclet->run;
        exit;
    }
    sleep 3;
    kill 'TERM', $pid;
    waitpid( $pid, 0);
};

my $ok = 0;
for my $l ( split /\n/, $stderr ) {
    like $l, qr/^(Start callback|proclet disable log at)/;
    $ok++ if $l =~ m!^proclet disable log at!;
}
ok($ok);
done_testing();

