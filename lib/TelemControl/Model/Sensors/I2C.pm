package TelemControl::Model::Sensors::I2C;
use parent TelemControl::Model::Sensors::Base;

use strict;
use warnings;

use Device::Chip::Adapter;
use Device::Chip::INA219;
use Device::Chip::TMP102;
use Device::Chip::ADT7470;

sub initialize {
    my $self = shift;

    $self->log->debug(sprintf('initialize %s', $self->node->{name}));

    my $ADAPTER = "LinuxKernel";

    my $adapter = Device::Chip::Adapter->new_from_description( $ADAPTER )
	or $self->log->error('Could not create adapter');

    $self->node->{device}{chip} = $self->node->{device}{class}->new;

    $self->node->{device}{chip}->mount_from_paramstr(
	$adapter,
	$self->node->{device}{params},
	)->get;
    my $result = eval {
	#my $voltage = $chip->read_bus_voltage->get;
	my $ret = $self->node->{device}{reader}->($self->node->{device}{chip});
	$self->log->debug(sprintf('chip info %d', $ret));

    };
    unless($result) {
	#delete $self->{device}{chip};
	$self->log->error(sprintf('could not access chip for %s: %s', $self->node->{name}, $@));
	return 0;
    }

    $self->SUPER::initialize();

    return 1;
}

sub _read {
    my $self = shift;

    my $result = $self->node->{device}{reader}->($self->node->{device}{chip});

    return $result;
}

1;
