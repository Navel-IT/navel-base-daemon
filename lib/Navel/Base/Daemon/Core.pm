# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Core 0.1;

use AnyEvent;
use EV;

use Navel::Utils qw/
    croak
    blessed
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    croak('meta must be of the Navel::Base::Daemon::Parser class') unless blessed($options{meta}) && $options{meta}->isa('Navel::Base::Daemon::Parser');

    croak('logger must be of the Navel::Logger class') unless blessed($options{logger}) && $options{logger}->isa('Navel::Logger');

    my $self = {
        meta => $options{meta},
        logger => $options{logger},
        logger_callbacks => {},
        job_types => {
            logger => Navel::AnyEvent::Pool->new
        },
        ae_condvar => AnyEvent->condvar
    };

    bless $self, ref $class || $class;
}

sub register_core_logger {
    my ($self, $job_name) = (shift, 'core');

    $self->unregister_job_by_type_and_name('logger', $job_name);

    $self->pool_matching_job_type('logger')->attach_timer(
        name => $job_name,
        singleton => 1,
        interval => 0.5,
        on_disabled => sub {
            $self->{logger}->{queue}->dequeue;
        },
        callback => sub {
            my $timer = shift->begin;

            $_->($self->{logger}) for values %{$self->{logger_callbacks}};

            $self->{logger}->flush_messages(
                async => 1
            );

            $timer->end;
        }
    );

    $self;
}

sub job_type_exists {
    my ($self, $type) = @_;

    croak('type must be defined') unless defined $type;

    exists $self->{job_types}->{$type};
}

sub pool_matching_job_type {
    my ($self, $type) = @_;

    croak('incorrect type') unless $self->job_type_exists($type);

    $self->{job_types}->{$type};
}

sub jobs_by_type {
    my ($self, $type) = @_;

    croak('type must be defined') unless defined $type;

    $self->pool_matching_job_type($type)->timers;
}

sub job_by_type_and_name {
    my ($self, $type, $name) = @_;

    croak('type and name must be defined') unless defined $type && defined $name;

    for (@{$self->jobs_by_type($type)}) {
        return $_ if $_->{name} eq $name;
    }

    undef;
}

sub unregister_job_by_type_and_name {
    my $self = shift;

    my $job = $self->job_by_type_and_name(@_);

    $job->DESTROY if defined $job;

    $self;
}

sub recv {
    my $self = shift;

    $self->{ae_condvar}->recv;

    $self;
}

sub send {
    my $self = shift;

    $self->{ae_condvar}->send;

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

Navel::Base::Daemon::Core

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
