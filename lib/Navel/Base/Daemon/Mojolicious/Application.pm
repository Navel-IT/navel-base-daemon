# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Mojolicious::Application 0.1;

use Navel::Base;

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

    croak('daemon option must be of Navel::Base::Daemon class') unless blessed($options{daemon}) && $options{daemon}->isa('Navel::Base::Daemon');

    croak('swagger option must be of Navel::Base::API::Swagger2 class') unless blessed($options{swagger}) && $options{swagger}->isa('Swagger2');

    my $self = $class->SUPER::new();

    $self->secrets(rand);

    $self->helper(
        daemon => sub {
            $options{daemon};
        }
    );

    $self->log()->level('debug')->unsubscribe('message')->on(
        message => sub {
            my ($log, $level, @lines) = @_;

            my $method = $level eq 'debug' ? $level : 'info';

            $self->daemon()->{core}->{logger}->$method(
                Navel::Logger::Message->stepped_message('Mojolicious:', \@lines)
            );
        }
    );

    my $authenticated = $self->routes()->under(
        sub {
            my $controller = shift;

            my $userinfo = $controller->req()->url()->to_abs()->userinfo();

            unless (secure_compare(defined $userinfo ? $userinfo : '', $self->daemon()->{core}->{meta}->{definition}->{webservice}->{credentials}->{login} . ':' . $self->daemon()->{core}->{meta}->{definition}->{webservice}->{credentials}->{password})) {
                $controller->res()->headers()->www_authenticate('Basic');

                $controller->render(
                    json => $controller->ok_ko(
                        [],
                        [
                            'unauthorized: access is denied due to invalid credentials.'
                        ]
                    ),
                    status => 401
                );

                return undef;
            }
        }
    );

    $authenticated->websocket('/api/logger/stream')->to('WebSocket::CoreLogger#stream');

    $self->hook(
        before_render => sub {
            my ($controller, $arguments) = @_;

            my (@ok, @ko);

            my $template = defined $arguments->{template} ? $arguments->{template} : '';

            if ($template eq 'exception') {
                my $exception_message = $controller->stash('exception')->message();

                push @ko, $exception_message;

                $controller->daemon()->{core}->{logger}->err(
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
        'Mojolicious::Plugin::Swagger2' => {
            swagger => $options{swagger},
            route => $authenticated
        }
    );

    $self->plugin('Navel::Mojolicious::Plugin::Swagger2::StdResponses');

    $self->plugin('Navel::Mojolicious::Plugin::JSON::XS');

    $self->plugin('Navel::Mojolicious::Plugin::Logger',
        {
            logger => $self->daemon()->{core}->{logger}
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

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
