package TelemControl::Model::Sensors::Sys;
use parent TelemControl::Model::Sensors::Base;

use strict;
use warnings;
use Data::Dumper;

sub initialize {
    my $self = shift;

    $self->log->debug(
        sprintf( 'nothing to initialize for %s', $self->node->{name} ) );

    $self->SUPER::initialize();
}

sub _read {
    my $self = shift;

    my $file = $self->node->{device}{file};
    open( my $fh, '<', $file ) or die "Can't open $file: $!";
    my $result = <$fh>;
    close $fh;

    return $result;
}

1;
