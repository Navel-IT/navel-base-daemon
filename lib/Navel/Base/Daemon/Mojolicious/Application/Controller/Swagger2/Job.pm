# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Mojolicious::Application::Controller::Swagger2::Job 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

my $action_on_job_by_type_and_name = sub {
    my ($controller, $arguments, $callback, $jobAction) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback
        }
    ) unless $controller->daemon->{core}->job_type_exists($arguments->{jobType});

    my $job = $controller->daemon->{core}->job_by_type_and_name($arguments->{jobType}, $arguments->{jobName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{jobName}
        }
    ) unless defined $job;

    my (@ok, @ko);

    $job->$jobAction;

    push @ok, $job->full_name . ': ' . $jobAction . '.';

    $controller->$callback(
        $controller->ok_ko(\@ok, \@ko),
        200
    );
};

sub list_job_types {
    my ($controller, $arguments, $callback) = @_;

    $controller->$callback(
        [
            keys %{$controller->daemon->{core}->{job_types}}
        ],
        200
    );
}

sub list_jobs_by_type {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback
        }
    ) unless $controller->daemon->{core}->job_type_exists($arguments->{jobType});

    $controller->$callback(
        [
            map {
                $_->{name}
            } @{$controller->daemon->{core}->jobs_by_type($arguments->{jobType})}
        ],
        200
    );
}

sub show_job_by_type_and_name {
    my ($controller, $arguments, $callback) = @_;

    return $controller->resource_not_found(
        {
            callback => $callback
        }
    ) unless $controller->daemon->{core}->job_type_exists($arguments->{jobType});

    my $job = $controller->daemon->{core}->job_by_type_and_name($arguments->{jobType}, $arguments->{jobName});

    return $controller->resource_not_found(
        {
            callback => $callback,
            resource_name => $arguments->{jobName}
        }
    ) unless defined $job;

    my %job_properties;

    $job_properties{name} = $arguments->{jobName};
    $job_properties{type} = $arguments->{jobType};
    $job_properties{backend} = ref $job;

    $job_properties{$_} = $job->{$_} for qw/
        enabled
        singleton
        running
    /;

    $controller->$callback(
        \%job_properties,
        200
    );
}

sub enable_job_by_type_and_name {
    $action_on_job_by_type_and_name->(
        @_,
        'enable'
    );
}

sub disable_job_by_type_and_name {
    $action_on_job_by_type_and_name->(
        @_,
        'disable'
    );
}

sub execute_job_by_type_and_name {
    $action_on_job_by_type_and_name->(
        @_,
        'exec'
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Base::Daemon::Mojolicious::Application::Controller::Swagger2::Job

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
