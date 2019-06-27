package TelemControl::Model::Sensors::GPS;
use parent TelemControl::Model::Sensors::Base;

use strict;
use warnings;

use Mojo::JSON qw(decode_json encode_json);

sub record {
    my $self = shift;

    # skip saving speed to DB

    return $self;
}

sub announce {
    my $self = shift;

    if ( !exists( $self->node->{val} ) ) { return $self }

    if ( $self->{new_max} ) {
	# TODO:   Kill any old timer first to avoid rising speed spam?
	$self->log->debug( sprintf( 'max is greater than last report %s > %s',
				    $self->node->{max}, $self->{last_report}));
	if (exists $self->node->{speed_announce_delay}) {
	    Mojo::IOLoop->remove($self->node->{speed_announce_delay});
	    delete $self->node->{speed_announce_delay};
	    $self->log->debug('killed max speed announcment as there is new max speed');
	}
	$self->node->{speed_announce_delay} = Mojo::IOLoop->timer(
	    4 => sub {
		$self->log->info( sprintf( 'speed increased from %s to %s',
					    $self->{last_report}, $self->node->{max}));
                $self->update_db($self->node->{name}, $self->node->{max});
		$self->speak(
		    sprintf( $self->node->{notify}{phrase}, $self->node->{max} ) );

		$self->{last_report} = $self->node->{max};
	    }
        );

    }

    return $self;
}

sub init {
    my $self = shift;

    $self->log->debug( sprintf( 'initialize %s', $self->node->{name} ) );

    $self->node->{raw} = 0;   # assume stationary to start

    #$self->node->{speed_tester} = 0;   # debugging only

    my @time     = localtime;
    my $gps_file = sprintf(
	'%s/%04d%02d%02d-%d.gps',
        $self->node->{device}{dir},
	$time[5] + 1900,
	$time[4] + 1,
	$time[3], $$
	);
    open( my $gps_fh, '>', $gps_file )
	or die $self->log->error("cannot open $gps_file for output: $!");
    $gps_fh->autoflush;

    my $id = Mojo::IOLoop->client(
	{ port => 2947 } => sub {
	    my ( $loop, $err, $stream ) = @_;

	    $stream->on(
		read => sub {
		    my ( $stream, $bytes ) = @_;

		    # Process input
		    foreach my $line ( split /\n/, $bytes ) {
			my $sentence = decode_json($line);

			#$self->log->debug(dumper($sentence));
			if (   ( $sentence->{class} eq 'TPV' )
			       && ( $sentence->{mode} >= 2 ) )
			{
			    $self->node->{raw} = $sentence->{speed};

			    # store lat/long
			    $self->node->{lat} = $sentence->{lat};
			    $self->node->{lon} = $sentence->{lon};

			    print $gps_fh $line;
			}
		    }

		}
            );

	    $stream->on(
		error => sub {
		    my ($stream, $err) = @_;
                    $self->log->error(sprintf('GPS stream error: %s', $err));
                }
	    );

	    $stream->on(
		timeout => sub {
                    $self->log->error('GPS stream timed out');
                }
	    );

	    # Write request
	    $stream->write('?WATCH={"enable":true,"json":true}');

	}
    );

    Mojo::IOLoop->recurring(
	$self->node->{rate_coord} => sub {
	    my $loop = shift;

	    # send coord message for Weather.pm
	    $self->pg->pubsub->notify(
                location_msg => encode_json( { lat => $self->node->{lat},
                                               lon => $self->node->{lon} } )
            );

	    #$self->read->record->publish->announce;
	}
    );
    
    $self->SUPER::init();

    #$self->node->{min} = 0;    # speed min is always 0

    return $self;
}

sub _read {
    my $self = shift;

    #return int(rand(15));
    #if ($self->node->{speed_tester} < 10) {
    #   $self->node->{raw} = $self->node->{speed_tester}++;
    #}
    return $self->node->{raw};
}

1;
