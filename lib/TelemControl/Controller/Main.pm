package TelemControl::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';

use FindBin qw($Bin);
use Data::Dumper;

use Mojo::JSON qw(decode_json);

sub script {
    my $self = shift;

    $self->render();
}

sub self {
    my $self = shift;

    $self->render( json => { function => 'Misc' } );
}

sub output {
    my $c = shift;

    $c->inactivity_timeout(60);

    my $cb = $c->pg->pubsub->listen(
        sensor_msg => sub {
            my ( $pubsub, $payload ) = @_;
            my $msg = decode_json($payload);
            $c->log->debug(
                "item to let client know about (pubsub): $msg->{type}");
            $c = $c->send( { json => $msg } );
        }
    );

    $c->on(
        json => sub {
            my ( $ws, $hash ) = @_;

            $c->log->debug( "Message: " . Dumper($hash) );
        }
    );

    $c->on(
        finish => sub {
            my ( $c, $code, $reason ) = @_;

            # $c->pg->pubsub->unlisten( sensor_msg => $cb ) or
            # 	$c->app->log->error('could not unlisten');
            $c->app->log->debug(
                "WebSocket for details closed in output handler($code)");
        }
    );

}

sub output_detail {
    my $c = shift;

    $c->inactivity_timeout(60);

    $c->send( { json => $c->minmax_msg } );

    my $cb = $c->pg->pubsub->listen(
        sensor_detail_msg => sub {
            my ( $pubsub, $payload ) = @_;
            my $msg = decode_json($payload);
            $c = $c->send( { json => $msg } );

 #$c->app->log->debug("item to let client know about (pubsub/detail)".Dumper($msg));
        }
    );

    $c->on(
        json => sub {
            my ( $ws, $hash ) = @_;

            if ( $hash->{type} eq 'close' ) {
                $ws->finish;
            }
        }
    );

    $c->on(
        finish => sub {
            my ( $c, $code, $reason ) = @_;

            # $c->pg->pubsub->unlisten( sensor_detail_msg => $cb )
            #   or $c->app->log->error('could not unlisten');
            $c->app->log->debug(
                "WebSocket for details closed in output_detail handler ($code)"
            );
        }
    );
}

sub audio {
    my $c    = shift;
    my $file = $c->param('file');

    # Open file in browser(do not show save dialog)
    $c->render_file(
        'filepath'            => "$Bin/../archive/audio/$file",
        'content_disposition' => 'inline'
    );
}

1;
