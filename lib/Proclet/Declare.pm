package Proclet::Declare;

use strict;
use warnings;
use Proclet;
use parent qw/Exporter/;

our @EXPORT = qw/color env service scheduled worker run/;

our %REGISTRY;

sub _proclet() { ## no critic
    return $REGISTRY{caller(1)} ||= {
        env => {},
        service => [],
        worker => {},
        color => 0,
    };
}

sub color {
    my $color = ! @_ ? 1 : shift;
    _proclet->{color} = $color;
}

sub env {
    my %env = @_;
    while (my ($k, $v) = each %env) {
        _proclet->{env}->{$k} = $v;
    }
}

sub service {
    my $tag = shift;
    my @service = @_;
    my $code = ( ref($service[0]) && ref($service[0]) eq 'CODE' )
        ? $service[0]
        : \@service;
    push @{_proclet->{service}},{ tag => $tag, code => $code };
}

sub scheduled {
    my $tag = shift;
    my $cron = shift;
    my @service = @_;
    my $code = ( ref($service[0]) && ref($service[0]) eq 'CODE' )
        ? $service[0]
        : \@service;
    push @{_proclet->{service}},{ tag => $tag, code => $code, every => $cron };
}

sub worker {
    my %worker = @_;
    while (my ($tag, $worker) = each %worker) {
        _proclet->{worker}->{$tag} = $worker;
    }
}

sub run() { ## no critic
    while (my ($k, $v) = each %{_proclet->{env}}) {
        $ENV{$k} = $v;
    }
    my $proclet = Proclet->new(color => _proclet->{color});
    foreach my $service ( @{_proclet->{service}} ) {
        my $tag = $service->{tag};
        $proclet->service(
            %$service,
            worker => ( exists _proclet->{worker}->{$tag} ) ? _proclet->{worker}->{$tag} : 1
        );
    }
    $proclet->run;
}

1;

__END__

=head1 NAME

Proclet::Declare - Declare interface to Proclet

=head1 SYNOPSIS

  use Proclet::Declare;

  color;
  env(
    DEBUG => 1,
    FOO => 1
  );

  service('web', 'plackup -p 5963 app.psgi');
  service('memcached', '/usr/local/bin/memcached', '-p', '11211');
  service('worker', './bin/worker');
  scheduled('tag', '0 12 * * *', sub { MyDailyWork->run });

  worker(
    'worker' => 5
  );

  run;

=head1 DESCRIPTION

Proclet::Declare supports to use Proclet declare style

=head1 FUNCTIONS

=over 4

=item color

Sets colored log

  color(); #enable
  color(1); #enable
  color(0); #disable

default: disabled

=item env

Environment values

  env(
      FOO => 'abc'
      BAR => 'efg'
  );

=item service

Sets the service

  # coderef
  service('tag', sub { MyWorker->run });
  # exec command
  service('tag', '/usr/local/bin/memcached','-vv');

=item scheduled

scheduled job like cron

  # coderef
  scheduled('tag', '0 12 * * *', sub { MyDailyWork->run });
  # exec command
  scheduled('tag', '0 12 * * *', 'my_daily_job','-execute');

=item worker

Number of children to fork

  worker(
      process_name => 1
      process_name => 5
  );

=item run

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

Tokuhiro Matsuno

=head1 SEE ALSO

L<Proclet>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
