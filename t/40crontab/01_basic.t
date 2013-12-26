use strict;
use Test::More;
use Proclet::Crontab;
use Time::Local;

ok( Proclet::Crontab->new('* * * * *')->match(time) );
ok( Proclet::Crontab->new('*/1 * * * *')->match(time) );

sub cron_ok {
    my ($cron, $min, $hour, $mday, $mon, $year) = @_;
    my $time = timelocal(0, $min, $hour, $mday, $mon-1, $year-1900);
    ok( Proclet::Crontab->new($cron)->match($time), "$cron not match " . localtime($time) );
}

sub cron_notok {
    my ($cron, $min, $hour, $mday, $mon, $year) = @_;
    my $time = timelocal(0, $min, $hour, $mday, $mon-1, $year-1900);
    ok( ! Proclet::Crontab->new($cron)->match($time), "$cron match " . localtime($time) );
}

cron_ok('  */5 * * * *', 0, 0, 26, 12, 2013);
cron_ok('  */5 *   * * *  ', 0, 0, 26, 12, 2013);
cron_notok('0 0 13 * 5', 0, 1, 6, 12, 2013);

cron_ok('0 0 * * 0', 0, 0, 13, 8, 2013); # 0==sun
cron_ok('0 0 * * 7', 0, 0, 13, 8, 2013); # 7==sun

cron_ok('0 0 13 * 5', 0, 0, 13, 1, 2013); # defined day and dow => day or dow
cron_ok('0 0 13 * 5', 0, 0, 6, 12, 2013); # defined day and dow => day or dow

sub error_cron {
    my ($cron, $err_match) = @_;
    eval {
        Proclet::Crontab->new($cron);
    };
    like($@, $err_match, "error cron => $cron");
}

error_cron('',qr/incorrect/);
error_cron('* * *',qr/incorrect/);
error_cron('6*5 * * * *',qr/bad format minute/);
error_cron('65 * * * *',qr/bad range minute/);
error_cron('* * * * 9',qr/bad range day_of_week/);

done_testing();




