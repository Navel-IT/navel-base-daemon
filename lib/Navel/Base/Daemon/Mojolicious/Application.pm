# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
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

    $self->log->level('debug')->unsubscribe('message')->on(
        message => sub {
            my ($log, $level, @lines) = @_;

            state $log_level_mapping = {
                debug => 'debug',
                info => 'info',
                warn => 'warning',
                error => 'err',
                fatal => 'emerg'
            };

            $level = $log_level_mapping->{$level} // 'info';

            $self->daemon->{core}->{logger}->$level(
                Navel::Logger::Message->stepped_message('Mojolicious:', \@lines)
            );
        }
    );

    my $routes = $self->routes;

    $self->hook(
        before_render => sub {
            my ($controller, $arguments) = @_;

            my (@ok, @ko);

            my $template = $arguments->{template} // '';

            if ($template eq 'exception') {
                push @ko, $controller->stash('exception')->message;

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
        OpenAPI => {
            url => $options{openapi_url},
            route => $routes,
            coerce => {} # empty hashtable is for 'coerce nothing'
        }
    );

    $self->plugin('Navel::Mojolicious::Plugin::API::StdResponses');

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

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
