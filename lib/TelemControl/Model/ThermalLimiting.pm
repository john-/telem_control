package TelemControl::Model::ThermalLimiting;

use strict;
use warnings;

use Mojo::Pg;

use Data::Dumper;

sub new {
    my ($class, $log, $config, $sensors) = @_;

    my $pg = Mojo::Pg->new('postgresql://script@/cart')
	or $log->error('Could not connect to database');

    my $self = {
	log     => $log,
	config  => $config,
	sensors => $sensors,
	pg      => $pg,
    };

    bless $self, $class;

    $self->_initialize;
    
    return $self;
}

sub _initialize {
    my $self = shift;

    my $fc = $self->{config}{fan_control};   # TODO:  maybe TL should only get config it needs

    Mojo::IOLoop->recurring(
	$fc->{rate} => sub {
	    # get most recent cpu temp
	    my $results = $self->{pg}->db->query(
		            'select value from sensor_history where input = \'cpu_temp\' order by reading_key desc limit 1' ) or $self->{log}->error("could not retrieve cpu temperature");
	    my $cpu_temp = $results->hash->{value};

	    # map it to percent
	    # If your number X falls between A and B, and you would like Y to fall between C and D, you can apply the following linear transform:

	    # Y = (X-A)/(B-A) * (D-C) + C
	    my $percent = sprintf( '%d', ($cpu_temp - $fc->{temp}{min}) /
	         ($fc->{temp}{max} - $fc->{temp}{min}) * ($fc->{speed}{max} - $fc->{speed}{min}) +
		  $fc->{speed}{min} );

	    if ($percent > $fc->{speed}{max}) { $percent = $fc->{speed}{max} }
	    if ($percent < $fc->{speed}{min}) { $percent = $fc->{speed}{min} }

	    $self->{log}->info(sprintf(
	      'fan control: cpu_temp is %.1fF, changing fan speed to %d%%', $cpu_temp, $percent));

	    # change fan speed to the percent
	    $self->{sensors}->set_fan_speed($percent);
        }
    );
}

1;
