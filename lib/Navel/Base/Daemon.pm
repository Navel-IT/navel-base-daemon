# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon 0.1;

use Navel::Base;

use Getopt::Long::Descriptive;

use Sys::Hostname;

use IO::AIO;

use Navel::Logger;
use Navel::Logger::Message;
use Navel::Utils qw/
    croak
    blessed
    daemonize
    try_require_namespace
/;

#-> methods

#->

sub Getopt::Long::Descriptive::Usage::exit {
    print shift->text;

    exit shift;
}

#->

sub run {
    my ($class, %options) = @_;

    croak('program_name must be defined') unless defined $options{program_name};

    my @describe_options = (
        [
            'validate-configuration',
            'validate the configuration and exit with the proper code'
        ],
        [
            'log-datetime-format=s',
            'set datetime format (default: %b %d %H:%M:%S)',
            {
                default => '%b %d %H:%M:%S'
            }
        ],
        [
            'log-facility=s',
            'set facility (syslog format (only local[0-7])) (default: local0)',
            {
                default => 'local0'
            }
        ],
        [
            'log-severity=s',
            'set severity (syslog format) (default: notice)',
            {
                default => 'notice'
            }
        ],
        [
            'log-no-color',
            'disable colored output'
        ],
        [
            'log-to-syslog',
            'log to syslog'
        ],
        [
            'log-file-path=s',
            'log output to a file'
        ],
        [],
        [
            'daemonize',
            'run as a standalone daemon'
        ],
        [
            'daemonize-pid-file=s',
            'write the PID to a file'
        ],
        [
            'daemonize-chdir=s',
            'change the current working directory to another'
        ],
        [],
        [
            'webservice-listeners=s@',
            'one or more locations to listen on',
            {
                default => []
            }
        ],
        [],
        [
            'version',
            'print version'
        ],
        [
            'help',
            'print help'
        ]
    );

    unshift @describe_options, @{$options{options}} if ref $options{options} eq 'ARRAY';

    my ($options, $usage) = describe_options(
        $options{program_name} . ' %o <meta-configuration-file-path>',
        @describe_options
    );

    $usage->exit(0) if $options->help;

    if ($options->version) {
        say $class->VERSION;

        exit 0;
    }

    my $meta_configuration_file_path = shift @ARGV;

    unless (defined $meta_configuration_file_path) {
        say 'Missing argument: meta-configuration-file-path must be defined';

        $usage->exit(1);
    }

    my $logger = eval {
        Navel::Logger->new(
            datetime_format => $options->log_datetime_format,
            hostname => eval {
                hostname;
            },
            service => $options{program_name},
            facility => $options->log_facility,
            severity => $options->log_severity,
            colored => ! $options->log_no_color,
            syslog => $options->log_to_syslog,
            file_path => $options->log_file_path
        );
    };

    if ($@) {
        chomp $@;

        say 'Logger error: ' . $@;

        $usage->exit(1);
    }

    if ($options->daemonize && ! $options->validate_configuration) {
        $logger->info('daemonizing.')->flush_messages;

        eval {
            daemonize(
                work_dir => $options->daemonize_chdir,
                pid_file => $options->daemonize_pid_file
            );

            IO::AIO::reinit;
        };

        unless ($@) {
            $logger->{service_pid} = $$;

            $logger->info('daemon successfully started.')->flush_messages;
        } else {
            $logger->emerg(
                Navel::Logger::Message->stepped_message('error while daemonizing.',
                    [
                        $@
                    ]
                )
            )->flush_messages;

            exit 1;
        }
    }

    my $daemon = eval {
        $class->new(
            logger => $logger,
            meta_configuration_file_path => $meta_configuration_file_path,
            webservice_listeners => $options->webservice_listeners
        );
    };

    if ($@) {
        $logger->emerg(Navel::Logger::Message->stepped_message($@))->flush_messages;

        exit 1;
    }

    if ($options->validate_configuration) {
        $logger->notice('configuration is valid.')->flush_messages;

        exit 0;
    }

    $options{before_starting}->($daemon) if ref $options{before_starting} eq 'CODE';

    $logger->notice('initialization done.')->flush_messages;

    eval {
        $daemon->start;
    };

    if ($@) {
        $logger->emerg(Navel::Logger::Message->stepped_message($@))->flush_messages;

        exit 1;
    }

    exit;
}

sub new {
    my ($class, %options) = @_;

    croak('meta must be of the Navel::Base::Daemon::Parser class') unless blessed($options{meta}) && $options{meta}->isa('Navel::Base::Daemon::Parser');

    die "meta_configuration_file_path is missing\n" unless defined $options{meta_configuration_file_path};

    my $self = bless {
        meta_configuration_file_path => $options{meta_configuration_file_path},
        webserver => undef
    }, ref $class || $class;

    $options{meta}->read(
        file_path => $self->{meta_configuration_file_path}
    );

    my $load_class_error = try_require_namespace($options{core_class});

    croak($load_class_error) if $load_class_error;

    $self->{core} = $options{core_class}->new(%options);

    croak('core_class must create an object of the Navel::Base::Daemon::Core class') unless blessed($self->{core}) && $self->{core}->isa('Navel::Base::Daemon::Core');

    if (defined $options{mojolicious_application_class} && ref $options{webservice_listeners} eq 'ARRAY' && @{$options{webservice_listeners}}) {
        $load_class_error = try_require_namespace($options{mojolicious_application_class});

        croak($load_class_error) if $load_class_error;

        $options{mojolicious_application_class}->import;

        require Mojo::Server::Daemon;
        Mojo::Server::Daemon->import;

        $self->{webserver} = Mojo::Server::Daemon->new(
            app => $options{mojolicious_application_class}->new(
                %options,
                daemon => $self,
            ),
            listen => $options{webservice_listeners}
        );

        if (defined $options{mojolicious_application_home_directory}) {
            @{$self->{webserver}->app->renderer->paths} = ($options{mojolicious_application_home_directory} . '/templates');
            @{$self->{webserver}->app->static->paths} = ($options{mojolicious_application_home_directory} . '/public');
        }
    }

    $self;
}

sub webserver {
    my ($self, $action) = @_;

    return blessed($self->{webserver}) && $self->{webserver}->isa('Mojo::Server::Daemon') unless defined $action;

    eval {
        if ($action) {
            $self->{core}->{logger}->notice('starting the webservice.');

            $self->{webserver}->silent(1)->start;
        } else {
            $self->{core}->{logger}->notice('stopping the webservice.');

            $self->{webserver}->stop;
        }
    };

    $self->{core}->{logger}->crit(Navel::Logger::Message->stepped_message($@)) if $@;

    $self->{core}->{logger}->flush_messages;

    $self;
}

sub start {
    my $self = shift;

    $self->webserver(1) if $self->webserver;

    $self->{core}->register_core_logger;

    $self;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Base::Daemon

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
