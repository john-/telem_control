package TelemControl::Model::Sensors::Weather;
use parent TelemControl::Model::Sensors::Base;

use strict;
use warnings;

use DarkSky::API;

use Mojo::JSON qw(decode_json);

use Data::Dumper;

sub init {
    my $self = shift;

    $self->log->debug( sprintf( 'initialize %s', $self->node->{name} ) );

    # items spoken but not stored
    $self->node->{summary} = '';
    $self->node->{wind_speed} = -10;

    $self->pg->pubsub->listen(location_msg => sub {
	my ($pubsub, $payload) = @_;
	my $loc = decode_json($payload);
	$self->node->{device}{lat} = $loc->{lat} || $self->node->{device}{lat};
	$self->node->{device}{lon} = $loc->{lon} || $self->node->{device}{lon};
	$self->log->debug(sprintf('lat: %f lon: %f', $self->node->{device}{lat}, $self->node->{device}{lon}));
    });
    
    $self->SUPER::init();

    return $self;
}

sub _read {
    my $self = shift;

    my $forecast = DarkSky::API->new(
	key       => $self->node->{device}{key},
	longitude => $self->node->{device}{lon},
	latitude  => $self->node->{device}{lat},
    );

    # look for interesting things to report on
    if (exists $forecast->{alerts}) {
	#$self->log->debug('got an alert' . Dumper($forecast->{alerts}));
	foreach my $alert (@{$forecast->{alerts}}) {
	    $self->log->debug(sprintf('alert: %s', $alert->{title}));
	}
    }

    if ($self->node->{summary} ne $forecast->{minutely}->{summary}) {
	$self->node->{summary} = $forecast->{minutely}->{summary};
	$self->speak( sprintf('Weather is %s', $self->node->{summary}) );
        $self->log->debug(sprintf('weather summary: %s', $self->node->{summary}));
    }

    if ( abs($self->node->{wind_speed} - $forecast->{currently}->{windSpeed}) > 3 ) {
	$self->node->{wind_speed} = $forecast->{currently}->{windSpeed};
	$self->speak( sprintf('Wind speed is %.1f miles per hour', $self->node->{wind_speed}) );
    }

    
    $self->node->{raw} = $forecast->{currently}->{temperature};
    return $self->node->{raw};
}

1;
