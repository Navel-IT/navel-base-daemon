# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Mojolicious::Application 0.1;

use Navel::Base;

use Mojo::JSON::MaybeXS;

use Mojo::Base 'Mojolicious';

use Mojo::Util 'secure_compare';

use Navel::Logger::Message;
use Navel::Utils qw/
    croak
    blessed
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    croak('daemon must be of Navel::Base::Daemon class') unless blessed($options{daemon}) && $options{daemon}->isa('Navel::Base::Daemon');

    croak('openapi_url must be defined') unless defined $options{openapi_url};

    my $self = $class->SUPER::new;

    $self->secrets(rand);

    $self->helper(
        daemon => sub {
            $options{daemon};
        }
    );

    my %log_level_mapping = (
        debug => 'debug',
        info => 'info',
        warn => 'warning',
        error => 'err',
        fatal => 'emerg'
    );

    $self->log->level('debug')->unsubscribe('message')->on(
        message => sub {
            my ($log, $level, @lines) = @_;

            $level = $log_level_mapping{$level} // 'info';

            $self->daemon->{core}->{logger}->$level(
                Navel::Logger::Message->stepped_message('Mojolicious:', \@lines)
            );
        }
    );

    my $routes = $self->routes;

    $routes->websocket('/api/logger/stream')->to('WebSocket::CoreLogger#stream');

    $self->hook(
        before_render => sub {
            my ($controller, $arguments) = @_;

            my (@ok, @ko);

            my $template = $arguments->{template} // '';

            if ($template eq 'exception') {
                my $exception_message = $controller->stash('exception')->message;

                push @ko, $exception_message;

                $controller->daemon->{core}->{logger}->err(
                    Navel::Logger::Message->stepped_message(\@ko)
                );
            } elsif ($template eq 'not_found') {
                push @ko, "the page you were looking for doesn't exist."
            } else {
                return;
            }

            $arguments->{json} = {
                ok => \@ok,
                ko => \@ko
            };
        }
    );

    $self->plugin(
        'Mojolicious::Plugin::OpenAPI' => {
            url => $options{openapi_url},
            route => $routes,
            coerce => {} # empty hash is for "coerce nothing"
        }
    );

    $self->plugin('Navel::Mojolicious::Plugin::OpenAPI::StdResponses');

    $self->plugin('Navel::Mojolicious::Plugin::Logger',
        {
            logger => $self->daemon->{core}->{logger}
        }
    );

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

Navel::Base::Daemon::Mojolicious::Application

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
