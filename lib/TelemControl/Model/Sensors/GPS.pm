package TelemControl::Model::Sensors::GPS;
use parent TelemControl::Model::Sensors::Base;

use strict;
use warnings;

use Mojo::JSON qw(decode_json);

sub init {
    my $self = shift;

    $self->log->debug( sprintf( 'initialize %s', $self->node->{name} ) );

    $self->node->{raw} = 0;   # assume stationary to start

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

			    print $gps_fh $line;

			    # publish lat/long for Weather.pm
			    $self->pg->pubsub->notify(
				location_msg => encode_json( { lat => $sentence->{lat},
                                                               lon => $sentence->{lon} } ) );
			}
		    }

		}
            );

	    # Write request
	    $stream->write('?WATCH={"enable":true,"json":true}');

	}
    );
    
    $self->SUPER::init();

    return $self;
}

sub _read {
    my $self = shift;

#    return int(rand(15));
    return $self->node->{raw};
}

1;
