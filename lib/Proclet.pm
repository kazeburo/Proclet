package Proclet;

use strict;
use warnings;
use Parallel::Prefork 0.13;
use Carp;
use Data::Validator;
use Mouse;
use Mouse::Util::TypeConstraints;
use Log::Minimal;

subtype 'ServiceProcs'
    => as 'Int',
    => where { $_ > 0 };

no Mouse::Util::TypeConstraints;

our $VERSION = '0.01';

has '_services' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

my $rule = Data::Validator->new(
    code => { isa => 'CodeRef' },
    worker => { isa => 'ServiceProcs', default => 1 },
)->with('Method');

sub service {
    my($self, $args) = $rule->validate(@_);
    push @{$self->_services}, {
        code => $args->{code},
        worker => $args->{worker},
    };
}

sub run {
    my $self = shift;

    my $max_workers = 0;
    my $max_service = 0;
    my %running;
    my %services;
    for my $service ( @{$self->_services} ) {
        $max_workers += $service->{worker};
        $services{$max_service} = $service;
        $running{$max_service} = [];
        $max_service++;
    }
    croak('no services exists') if !$max_workers;

    my $next;
    my %pid2service;
    my $pm = Parallel::Prefork->new({
        max_workers => $max_workers,
        trap_signals => {
            map { ($_ => 'TERM') } qw/TERM HUP/
        },
        on_child_reap => sub {
            my ( $pm, $exit_pid, $status ) = @_;
            debugf "[parent] on child reap: exit_pid => %s status => %s, service => %s", 
                $exit_pid, $status, exists $pid2service{$exit_pid} ? $pid2service{$exit_pid} : 'undefined';
            if ( exists $pid2service{$exit_pid} ) {
                my $sid = $pid2service{$exit_pid};
                my @pids = grep { $_ != $exit_pid  } @{$running{$sid}};
                $running{$sid} = \@pids;                
                delete $pid2service{$exit_pid};
            }
            debugf "[parent] on_child_reap: running => %s", \%running;
        },
        before_fork => sub {
            $Log::Minimal::AUTODUMP = 1;
            debugf "[parent] before_fork: running => %s", \%running;
            my $pm = shift;
            for my $sid ( 0..$max_service ) {                
                if ( scalar @{$running{$sid}} < $services{$sid}->{worker} ) {
                    $next = $sid;
                    debugf "[parent] before_fork: next => %s", $next;
                    last;
                }
            }
        },
        after_fork => sub {
            my ($pm, $pid) = @_;
            if ( defined $next ) {
                debugf "[parent] child start: sid =>%s", $next;
                push @{$running{$next}}, $pid;
                $pid2service{$pid} = $next;
            }
            else {
                debugf "[parent] child start but next is undefined";
            }
            $next = undef;
        },
    });

    while ($pm->signal_received ne 'TERM' ) {
        $pm->start( sub {
            if ( defined $next ) {
                my $code = $services{$next}->{code};
                $code->();
            }
            else {
                debugf "[%s] child start but next is undefined",$$;
            }
        });
    }

    $pm->wait_all_children();
}

__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Proclet - minimalistic Supervisor

=head1 SYNOPSIS

  use Proclet;

  my $proclet = Proclet->new;

  # add service
  $proclet->service(
      code => sub {
          my $job = $jobqueue->grab;
          work($job);
      },
      worker => 2,
  );

  $proclet->service(
      code => sub {
          my $loader = Plack::Loader->load(
              'Starlet',
              port => $port,
              host => $host || 0,
              max_workers => 4,
          );
          $loader->run($app);
      },
  );

  $proclet->service(
      code => sub {
          exec('/usr/bin/memcached','-p','11211');
      },
  );

  $proclet->run;

=head1 DESCRIPTION

Proclet is minimalistic Supervisor, fork and manage many services from one perl script.

=head1 METHOD

=over 4

=item service

Add services to Proclet.

Attributes are as follows:

=over 4

=item code: CodeRef

Code reference of service

=item worker: Int

Number of children to fork, default is "1"

=back

=item run

run services

=back

=head1 AUTHOR

Masahiro Nagano E<lt>kazeburo {at} gmail.comE<gt>

=head1 SEE ALSO

L<Proc::Launcher::Manager>, related module
L<Parallel::Prefork>, Proclet used internally

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
