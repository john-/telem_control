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

    #my $client =
	#$c->tx->remote_address . $c->tx->remote_port;    # unique identifier
    # TODO: delete this on connection close
    # this code (recently commented out) may be to handle closed connections

    $c->send( { json => $c->config_msg } );

    my $cb = $c->pg->pubsub->listen(
	sensor_msg => sub {
	    my ( $pubsub, $payload ) = @_;
	    my $msg = decode_json($payload);
	    $c = $c->send( { json => $msg } );
	    $c->log->debug(
		"item to let client know about (pubsub): $msg->{type}");
	}
    );

    $c->on(
	json => sub {
	    my ( $ws, $hash ) = @_;

	    $c->log->debug("Message: ".Dumper($hash));
	}
    );

    $c->on(
	finish => sub {
	    my ( $c, $code, $reason ) = @_;
	    # because of erroneous 1006 errors commenting out the unlisten
	    #$pubsub->unlisten( sensor_msg => $cb );
	    $c->log->debug("WebSocket closed ($code)");
	}
    );

}

sub output_detail {
    my $c = shift;

    $c->inactivity_timeout(60);

#    $c->sensors->get_min_max->each(sub {

	#$c->log->debug( sprintf('IN THE controller name of sensor: %s %s %s', $_->node->{name}, $_->node->{min}, $_->node->{max}));
#	$c->send(
#	    { json => {
#		 sprintf('%s_val', $_->node->{name}) => $_->node->{value},
#		 sprintf('%s_min', $_->node->{name}) => $_->node->{min}
#		 sprintf('%s_max', $_->node->{name}) => $_->node->{max},
#	              }
#	    }
#	);
#	$c->send(
#	    { json => { sprintf('%s_max', $_->node->{name}) => $_->node->{max} } } );

#	$c->send(
#	    { json => { sprintf('%s_min', $_->node->{name}) => $_->node->{min} } } );
#	$c->send(
#	    { json => { sprintf('%s_max', $_->node->{name}) => $_->node->{max} } } );
#    });

    # send initial values
    my $min_max = $c->sensors->get_min_max;  # TODO: should this return a collection and then map>
    foreach my $input ( keys %{$min_max} ) {
	$c->send(
	    { json => { "${input}_min" => $min_max->{$input}{min} } } );
	$c->send(
	    { json => { "${input}_max" => $min_max->{$input}{max} } } );
#	$c->send(   # TODO:  This might not actually populate current values into UI
#	    { json => { "${input}_val" => $min_max->{$input}{val} } } );
    }

    my $cb = $c->pg->pubsub->listen(
	sensor_detail_msg => sub {
            my ( $pubsub, $payload ) = @_;
	    my $msg = decode_json($payload);
	    $c = $c->send( { json => $msg } );

	    #app->log->debug("item to let client know about (pubsub/detail)".dumper($msg));
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
	    #$c->pubsub->unlisten( sensor_detail_msg => $cb ) or
		#$c->app->log->error('could not unlisten');
	    #$c->app->log->debug(
		#"WebSocket for details closed ($code) client $client");
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
