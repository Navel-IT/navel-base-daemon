# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-base-daemon is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Base::Daemon::Mojolicious::Application::Controller::Swagger2::Backup 0.1;

use Navel::Base;

use Mojo::Base 'Mojolicious::Controller';

use Promises 'collect';

#-> methods

sub save_all_configuration {
    my ($controller, $arguments, $callback) = @_;

    $controller->render_later();

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
            $controller->$callback(
                $controller->ok_ko(\@ok, \@ko),
                @ko ? 500 : 200
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

Navel::Base::Daemon::Mojolicious::Application::Controller::Swagger2::Backup

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-scheduler is licensed under the Apache License, Version 2.0

=cut
