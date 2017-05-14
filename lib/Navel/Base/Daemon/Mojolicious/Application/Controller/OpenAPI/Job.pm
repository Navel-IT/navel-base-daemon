# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Mojolicious::Application::Controller::OpenAPI::Job 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

#-> methods

my $action_by_type_and_name = sub {
    my ($controller, $action) = (
        shift->openapi->valid_input || return,
        shift
    );

    my ($type, $name) = (
        $controller->validation->param('type'),
        $controller->validation->param('name')
    );

    return $controller->navel->stdresponses->resource_not_found unless $controller->daemon->{core}->job_type_exists($type);

    my $job = $controller->daemon->{core}->job_by_type_and_name($type, $name);

    return $controller->navel->stdresponses->resource_not_found($name) unless defined $job;

    my (@ok, @ko);

    $job->$action;

    push @ok, $job->full_name . ': ' . $action . '.';

    $controller->render(
        openapi => $controller->navel->logger->ok(\@ok, \@ko),
        status => 200
    );
};

sub list_types {
    my $controller = shift->openapi->valid_input || return;

    $controller->render(
        openapi => [
            keys %{$controller->daemon->{core}->{job_types}}
        ],
        status => 200
    );
}

sub list_by_type {
    my $controller = shift->openapi->valid_input || return;

    my $type = $controller->validation->param('type');

    return $controller->navel->stdresponses->resource_not_found unless $controller->daemon->{core}->job_type_exists($type);

    $controller->render(
        openapi => [
            map {
                $_->{name}
            } @{$controller->daemon->{core}->jobs_by_type($type)}
        ],
        status => 200
    );
}

sub show_by_type_and_name {
    my $controller = shift->openapi->valid_input || return;

    my %job_properties = (
        name => $controller->validation->param('name'),
        type => $controller->validation->param('type')
    );

    return $controller->navel->stdresponses->resource_not_found unless $controller->daemon->{core}->job_type_exists($job_properties{type});

    my $job = $controller->daemon->{core}->job_by_type_and_name($job_properties{type}, $job_properties{name});

    return $controller->navel->stdresponses->resource_not_found($job_properties{name}) unless defined $job;

    $job_properties{backend} = ref $job;

    $job_properties{$_} = $job->{$_} for qw/
        enabled
        singleton
        running
    /;

    $controller->render(
        openapi => \%job_properties,
        status => 200
    );
}

sub enable_by_type_and_name {
    shift->$action_by_type_and_name('enable');
}

sub disable_by_type_and_name {
    shift->$action_by_type_and_name('disable');
}

sub execute_by_type_and_name {
    shift->$action_by_type_and_name('exec');
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Base::Daemon::Mojolicious::Application::Controller::OpenAPI::Job

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
