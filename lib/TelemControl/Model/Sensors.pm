package TelemControl::Model::Sensors;
use Mojo::Base -base;

use Mojo::Collection;

has 'log';
has 'pg';
has 'config';    # for volume

use TelemControl::Model::Sensors::I2C;
use TelemControl::Model::Sensors::Sys;
use TelemControl::Model::Sensors::GPS;
use TelemControl::Model::Sensors::Weather;

use Data::Dumper;

sub init {
    my $self = shift;

    $self->{sensors} = Mojo::Collection->new;

    foreach my $node ( @{ $self->config->{nodes} } ) {

        #$self->log->debug(sprintf('sensor "%s" to be created', $node->{name}));
        my $class  = 'TelemControl::Model::Sensors::' . $node->{device}{type};
        my $sensor = $class->new(
            log    => $self->log,
            node   => $node,
            pg     => $self->pg,
            config => $self->config
        )->init;

        push @{ $self->{sensors} }, $sensor if $sensor;
    }
}

sub get_min_max {
    my $self = shift;

    my %min_max;
    $self->{sensors}->each(
        sub {
            my $n = $_->node;
            $min_max{ $n->{name} }{val} = $n->{val};
            $min_max{ $n->{name} }{min} = $n->{min};
            $min_max{ $n->{name} }{max} = $n->{max};
        }
    );
    return \%min_max;
}

sub set_fan_speed {
    my ( $self, $speed ) = @_;

    my $fans = $self->{sensors}->grep( sub { $_->node->{name} =~ /fan[\d]/ } );

    if ( !$fans->size ) {
        $self->log->error('No fans enabled. Can\'t change fan speed!');
        return;
    }

    $fans->each(
        sub {
            $self->log->debug(
                sprintf( 'about to set fan speed: %s', $_->node->{name} ) );
            $_->set_fan_speed($speed);
        }
    );
}

1;
