package TelemControl::Model::Sensors;
use Mojo::Base -base;

use Mojo::Collection;

# work with collections of nodes

has 'log';
has 'config';
has 'notifier';
has 'pg';
has 'config'; # for updating min/max values

use TelemControl::Model::Sensors::I2C;
use TelemControl::Model::Sensors::Sys;
#use TelemControl::Model::Sensors::GPS;

use Data::Dumper;

sub initialize {
    my $self = shift;

    $self->{sensors} = Mojo::Collection->new;

    foreach my $node (@{$self->config->{nodes}}) {
	#$self->log->debug(sprintf('sensor "%s" to be created', $node->{name}));
	my $class = 'TelemControl::Model::Sensors::' . $node->{device}{type};
	my $sensor = $class->new(log => $self->log,
				 node => $node,
				 notifier => $self->notifier,
	                         pg => $self->pg,
	                         config => $self->config);

	push @{$self->{sensors}}, $sensor;
        if ($sensor->initialize) {
	    # TODO:  this can probably be done with a grep through $self->sensors
	    if ($node->{name} =~ /fan[\d]/) { push @{$self->{fans}}, $sensor }
	}
    }
}

# sub: report min/max

sub get_min_max {
    my $self = shift;

    my %min_max;
    $self->{sensors}->each(sub {
	my $n = $_->node;
#        $min_max{$n->{name}}{val} = $n->{val};
	$min_max{$n->{name}}{min} = $n->{min};
	$min_max{$n->{name}}{max} = $n->{max};
    });
    return \%min_max;
}

sub set_fan_speed {
    my ($self, $speed) = @_;

    #$self->sensors->each(sub { $self->log->debug( sprintf('name of sensor: %s', $_->node->{name}))});
    if (!exists $self->{fans}) {
	$self->log->error('No fans enabled. Can\'t change fan speed!');
	return;
    }

    foreach my $fan (@{$self->{fans}}) {
	$self->log->debug(sprintf('about to set fan speed: %s', $fan->node->{name}));
	$fan->set_fan_speed($speed);
    }
}

1;
