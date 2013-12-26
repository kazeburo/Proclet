# NAME

Proclet - minimalistic Supervisor

# SYNOPSIS

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

# DESCRIPTION

Proclet is minimalistic Supervisor, fork and manage many services from one perl script.

# LOG

Logs from services are Displayed with timestamp and tag.

    12:23:16 memcached.1 | <6 server listening (udp)
    12:23:16 memcached.1 | <7 send buffer was 9216, now 3728270
    12:23:16 memcached.1 | <7 server listening (udp)
    12:23:16 web.1       | 2012/08/31-12:23:16 Starman::Server (type Net::Server::PreFork) starting! pid(51516)
    12:23:16 web.1       | Resolved [*]:5432 to [0.0.0.0]:5432, IPv4
    12:23:16 web.1       | Binding to TCP port 5432 on host 0.0.0.0 with IPv4 
    12:23:16 web.1       | Setting gid to "20 20 20 401 204 100 98 81 80 79 61 12 402"

# METHOD

- new

    Create instance of Proclet.

    Attributes are as follows:

    - spawn\_interval: Int

        interval in seconds between spawning services unless a service exits abnormally (default: 0)

    - err\_respawn\_interval: Int

        number of seconds to deter spawning of services after a service exits abnormally (default: 1)

    - color: Bool

        colored log (default: 0)

    - logger: CodeRef

            my $logger = File::RotateLogs->new(...)
            my $proclet = Proclet->new(
                logger => sub { $logger->print(@_) }
            );
            

        Sets a callback to print stdout/stderr. uses warn by default.

    - enable\_log\_worker: Bool

        enable worker for format logs. (default: 1)
        If disabled this option, cannot use logger opt too.

- service

    Add services to Proclet.

    Attributes are as follows:

    - code: CodeRef|ArrayRef|Str

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

    - worker: Int

        Number of children to fork, default is "1"

    - tag: Str

        Keyword for log. optional

    - every: Str

        Crontab like format. optional

        If every option exists, Proclet execute the job as cron(8)

            $proclet->service(
                code => sub {
                    scheduled_work();
                },
                tag => 'cron',
                every => '0 12 * * *', #everyday at 12:00am
            );

- run

    run services. Proclet does start services by defined order

# AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

# SEE ALSO

[Proc::Launcher::Manager](http://search.cpan.org/perldoc?Proc::Launcher::Manager), related module
[Parallel::Prefork](http://search.cpan.org/perldoc?Parallel::Prefork), Proclet used internally

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
