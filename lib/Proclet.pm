package Proclet;

use strict;
use warnings;
use Parallel::Prefork 0.13;
use Carp;
use Data::Validator;
use Mouse;
use Mouse::Util::TypeConstraints;
use Log::Minimal env_debug => 'PROCLET_DEBUG';
use IO::Select;
use Term::ANSIColor;
use File::Which;
use Time::Crontab;

subtype 'ServiceProcs'
    => as 'Int'
    => where { $_ >= 0 };

subtype 'ServicePort'
    => as 'Int'
    => where { $_ > 0 && $_ % 1000 == 0 };

subtype 'Proclet::Service'
    => as 'HashRef'
    => message { "This argument must be String or ArrayRef or CodeRef" };
coerce 'Proclet::Service'
    => from 'ArrayRef' => via {
        my $command = $_;
        +{generator => sub {
            my @command = @{$command};
            my $bash = which("bash");
            if ( @command == 1 && $bash ) { unshift @command, $bash, "-c" }
            sub {
                exec(@command);
                die $!
            }
        }}
    }
    => from 'Str' => via {
        my $o_command = $_;
        +{generator => sub {
            my $port = shift;
            my $command = $o_command; #copy
            $command =~ s/\$PORT/$port/g if $port;
            my @command = ($command);
            if ( my $bash = which("bash") ) { unshift @command, $bash, "-c" }
            sub {
                exec @command;
                die $!
            }
        }}
    }
    => from 'CodeRef' => via {
        my $command = $_;
        +{generator => sub { $command }};
    };


subtype 'Proclet::Scheduler'
    => as 'CodeRef'
    => message { "This argument must be String or CodeRef" };
coerce 'Proclet::Scheduler'
    => from 'Str' => via {
        my $str = $_;
        my $crontab = Time::Crontab->new($str);
        sub {
            my $unixtime = shift;
            $crontab->match($unixtime);
        }
    };


no Mouse::Util::TypeConstraints;

our $VERSION = '0.32';

has '_services' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

has 'spawn_interval' => (
    is => 'ro',
    isa => 'Int',
    default => 0,
);

has 'err_respawn_interval' => (
    is => 'ro',
    isa => 'Int',
    default => 1,
);

has 'color' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'logger' => (
    is => 'ro',
    isa => 'CodeRef',
    required => 0,
);

has 'enable_log_worker' => (
    is => 'ro',
    isa => 'Int',
    default => 1,
);

# for Procfile port assignment
has '_base_port' => (
    is => 'ro',
    isa => 'ServicePort',
    required => 0,
);

my $rule = Data::Validator->new(
    code => { isa => 'Proclet::Service', coerce => 1 },
    worker => { isa => 'ServiceProcs', default => 1 },
    tag => { isa => 'Str', optional => 1 },
    every => { isa => 'Proclet::Scheduler', coerce => 1, optional => 1 },
)->with('Method');

our @COLORS = qw/green magenta blue yellow cyan/;

sub service {
    my($self, $args) = $rule->validate(@_);
    $self->{service_num} ||= 0;
    $self->{service_num}++;
    $self->{tags} ||= {};
    my $tag = ( exists $args->{tag} && defined $args->{tag} ) ? $args->{tag} : $self->{service_num};
    die "tag: $tag is already exists" if exists $self->{tags}->{$tag};
    $self->{tags}->{$tag} = 1;
    my $port = 0;
    if ( $self->{_base_port} ) {
        $port = $self->{_base_port};
        $self->{_base_port} += 100;
    }
    my $cron = ( exists $args->{every} && defined $args->{every} ) ? $args->{every} : '';
    push @{$self->_services}, {
        code => $args->{code},
        worker => $args->{worker},
        tag => $tag,
        start_port => $port,
        color => $COLORS[ $self->{service_num} % @COLORS ],
        cron => $cron
    };
}

my $LOGGER = '__log__';

sub run {
    my $self = shift;

    my %services;
    my @services;
    for my $service ( @{$self->_services} ) {
        my $worker = $service->{worker};
        for ( my $i = 1; $i <= $worker; $i++ ) {
            my $sid = $service->{tag} . '.' . $i;
            $services{$sid} = { %$service };
            my $port =  $services{$sid}{start_port} + $i - 1;
            my $code_generator = $services{$sid}{code}{generator};
            my $code = $code_generator->($port);
            if ( $services{$sid}{cron} ) {
                $code = $self->cron_worker($code,$services{$sid}{cron});
            }
            $services{$sid}{code} = $code;
            if ( $self->enable_log_worker ) {
                $services{$sid}->{pipe} = $self->create_pipe;
            };
            push @services, $sid;
        }
    }
    croak('no services exists') if ! @services;

    if ( $self->enable_log_worker ) {
        $services{$LOGGER} = {
            code => $self->log_worker(),
        };
        push @services, $LOGGER;
    }

    my $next;
    my %pid2service;
    my %running;
    my $wait_all_children;
    my $pm = Parallel::Prefork->new({
        spawn_interval => $self->spawn_interval,
        err_respawn_interval => $self->err_respawn_interval,
        max_workers => scalar @services,
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM',
            INT  => 'INT',
        },
        on_child_reap => sub {
            my ( $pm, $exit_pid, $status ) = @_;
            local $Log::Minimal::AUTODUMP = 1;
            debugf "[Proclet] on child reap: exit_pid => %s status => %s, service => %s", 
                $exit_pid, $status, exists $pid2service{$exit_pid} ? $pid2service{$exit_pid} : 'undefined';
            if ( exists $pid2service{$exit_pid} ) {
                my $sid = $pid2service{$exit_pid};
                delete $running{$sid};
                delete $pid2service{$exit_pid};
                if ( $wait_all_children ) {
                    if ( scalar keys %running == 1 && exists $running{$LOGGER} ) {
                        kill 'TERM', $running{$LOGGER};
                        sleep(1) && kill 'TERM', $running{$LOGGER}; #safe
                    }
                }
            }
            debugf "[Proclet] on_child_reap: running => %s", \%running;
        },

        before_fork => sub {
            local $Log::Minimal::AUTODUMP = 1;
            debugf "[Proclet] before_fork: running => %s", \%running;
            my $pm = shift;
            if ( $self->enable_log_worker && ! exists $running{$LOGGER} ) {
                $next = $LOGGER;
            }
            else {
                for my $sid ( @services ) {
                    if ( ! exists $running{$sid} ) {
                        $next = $sid;
                        last;
                    }
                }
            }
            debugf "[Proclet] before_fork: next => %s", $next;
        },
        after_fork => sub {
            my ($pm, $pid) = @_;
            local $Log::Minimal::AUTODUMP = 1;
            if ( defined $next ) {
                debugf "[Proclet] child start: sid =>%s", $next;
                $pid2service{$pid} = $next;
                $running{$next} = $pid;
            }
            else {
                debugf "[Proclet] child start but next is undefined";
            }
            $next = undef;
        },
    });

    while ($pm->signal_received !~ m!^(?:TERM|INT)$! ) {
        $pm->start( sub {
            if ( defined $next ) {
                my $service = delete $services{$next};
                if ( ! $self->enable_log_worker ) {
                    $service->{code}->();
                }
                elsif ( $service->{pipe} ) {
                    undef %services;
                    my $logwh = $service->{pipe}->[1];
                    close $service->{pipe}->[0];
                    open STDOUT, '>&', $logwh
                        or die "Died: failed to redirect STDOUT";
                    open STDERR, '>&', $logwh
                        or die "Died: failed to redirect STDERR";
                    $service->{code}->();
                }
                else {
                    # logworker
                    $service->{code}->(\%services);
                }
            }
            else {
                local $Log::Minimal::AUTODUMP = 1;
                debugf "[Proclet] child (pid=>%s) start but next is undefined",$$;
            }
        });
    }
    $wait_all_children = 1;
    $pm->wait_all_children();
}

sub create_pipe {
    my $self = shift;
    pipe my $logrh, my $logwh
        or die "Died: failed to create pipe:$!";
    return [$logrh, $logwh];
}

sub log_worker {
    my $self = shift;
    sub {
        local $Log::Minimal::AUTODUMP = 1;
        my $services = shift;
        my %fileno2sid;
        my $s = IO::Select->new();
        debugf "[Proclet] start log worker";
        my $maxlen = 0;
        for my $sid ( keys %$services ) {
            close $services->{$sid}->{pipe}->[1];
            my $rh = $services->{$sid}->{pipe}->[0];
            $fileno2sid{fileno($rh)} = $sid;
            $s->add($rh);
            $maxlen = length($sid) if length($sid) > $maxlen;
        }
        $maxlen = 10 if $maxlen < 10;
        my $loop = 0;
        local $SIG{TERM} = $SIG{INT} = sub {
            $loop++;
        };
        while ( $loop < 2 ) {
            my @ready = $s->can_read(1);
            foreach my $fh ( @ready ) {
                my $sid = $fileno2sid{fileno($fh)};
                my @lt = localtime;
                sysread($fh, my $buf, 65536);
                for my $log ( split /\r?\n/, $buf ) {
                    my $prefix = sprintf('%02d:%02d:%02d %-'.$maxlen.'s |',$lt[2],$lt[1],$lt[0], $sid);
                    $prefix = colored( $prefix, $services->{$sid}->{color} ) if $self->color;
                    chomp $log;
                    chomp $log;
                    if ( $self->logger ) {
                        $self->logger->($prefix . ' ' . $log . "\n");
                    } else {
                        warn  $prefix . ' ' . $log . "\n";
                    }
                }
            }
        }
        debugf "[Proclet] finished log worker";
    };
}

sub current_min {
    my $time = time;
    $time = $time - ($time % 60);
    $time;
}

sub cron_worker {
    my ($self,$code,$cron) = @_;
    sub {
        debugf "[Proclet] start cron worker";
        my $live = 1;
        local $SIG{TERM} = sub { $live = 0 };
        local $SIG{CHLD} = 'IGNORE';
        my $prev = current_min();
        select undef, undef, undef, 1; ## no critic;
        while ( $live ) {
            my $now;
            while ( $live ) {
                $now = current_min();
                last if $now != $prev;
                select undef, undef, undef, 1; ## no critic;
            }
            last unless $live;
            $prev = $now;
            debugf "[Proclet] check cron";
            next unless $cron->($now);
            debugf "[Proclet] cron match and start child worker!";
            my $pid = fork;
            if ( ! defined $pid ) {
                die "Died: fork failed: $!";
            }
            elsif ( $pid == 0 ) {
                #child
                local $SIG{TERM} = 'DEFAULT';
                local $SIG{CHLD} = 'DEFAULT';
                $code->();
                exit 0;
            }
            #parent
        }
    };
}

__PACKAGE__->meta->make_immutable();
1;
__END__

=head1 NAME

Proclet - minimalistic Supervisor

=head1 SYNOPSIS

  use Proclet;

  my $proclet = Proclet->new(
      color => 1
  );

  # add service
  $proclet->service(
      code => sub {
          my $job = $jobqueue->grab;
          work($job);
      },
      worker => 2,
      tag => 'worker'
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
      tag => 'web'
  );

  $proclet->service(
      code => sub {
          exec('/usr/bin/memcached','-p','11211');
      },
  );

  $proclet->service(
      code => sub {
          scheduled_work();
      },
      tag => 'cron',
      every => '0 12 * * *', #everyday at 12:00am
  );


  $proclet->run;

=head1 DESCRIPTION

Proclet is minimalistic Supervisor, fork and manage many services from one perl script.

=head1 LOG

Logs from services are Displayed with timestamp and tag.

  12:23:16 memcached.1 | <6 server listening (udp)
  12:23:16 memcached.1 | <7 send buffer was 9216, now 3728270
  12:23:16 memcached.1 | <7 server listening (udp)
  12:23:16 web.1       | 2012/08/31-12:23:16 Starman::Server (type Net::Server::PreFork) starting! pid(51516)
  12:23:16 web.1       | Resolved [*]:5432 to [0.0.0.0]:5432, IPv4
  12:23:16 web.1       | Binding to TCP port 5432 on host 0.0.0.0 with IPv4 
  12:23:16 web.1       | Setting gid to "20 20 20 401 204 100 98 81 80 79 61 12 402"

=head1 METHOD

=over 4

=item new

Create instance of Proclet.

Attributes are as follows:

=over 4

=item spawn_interval: Int

interval in seconds between spawning services unless a service exits abnormally (default: 0)

=item err_respawn_interval: Int

number of seconds to deter spawning of services after a service exits abnormally (default: 1)

=item color: Bool

colored log (default: 0)

=item logger: CodeRef

  my $logger = File::RotateLogs->new(...)
  my $proclet = Proclet->new(
      logger => sub { $logger->print(@_) }
  );
  
Sets a callback to print stdout/stderr. uses warn by default.

=item enable_log_worker: Bool

enable worker for format logs. (default: 1)
If disabled this option, cannot use logger opt too.

=back

=item service

Add services to Proclet.

Attributes are as follows:

=over 4

=item code: CodeRef|ArrayRef|Str

Code reference or commands of services.

CodeRef

  $proclet->service(
    code => sub {
        MyWorker->run();
    }
  );

ArrayRef

  $proclet->service(
    code => ['plackup','-a','app.psgi'],
  );

Str

  $proclet->service(
    code => '/usr/bin/memcached'
  );

=item worker: Int

Number of children to fork, default is "1"

=item tag: Str

Keyword for log. optional

=item every: Str

Crontab like format. optional

If every option exists, Proclet execute the job as cron(8)

  $proclet->service(
      code => sub {
          scheduled_work();
      },
      tag => 'cron',
      every => '0 12 * * *', #everyday at 12:00am
  );

=back

=item run

run services. Proclet does start services by defined order

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
