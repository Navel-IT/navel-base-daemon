# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Mojolicious::Application::Controller::OpenAPI::Configuration 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Promises 'collect';

#-> methods

sub save {
    my $controller = shift->openapi->valid_input || return;

    $controller->render_later;

    my (@ok, @ko);

    collect(@_)->then(
        sub {
            push @ok, map {
                $_->[0] . ': runtime configuration successfully saved.';
            } @_;
        }
    )->catch(
        sub {
            push @ko, @_;
        }
    )->finally(
        sub {
            $controller->render(
                openapi => $controller->ok_ko(\@ok, \@ko),
                status => @ko ? 500 : 200
            );
        }
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

Navel::Base::Daemon::Mojolicious::Application::Controller::OpenAPI::Configuration

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-base-daemon is licensed under the Apache License, Version 2.0

=cut
