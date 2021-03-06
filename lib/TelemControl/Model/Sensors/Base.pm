package TelemControl::Model::Sensors::Base;
use Mojo::Base -base;

has 'log';       # also need the node...maybe still have some kind of new still?
has 'node';
has 'pg';
has 'config';    # for volume

use Mojo::IOLoop;
use Mojo::IOLoop::Subprocess;
use File::Temp;    # names for tts files
use File::Basename;
use FindBin qw($Bin);
use Mojo::JSON qw(encode_json);

use Data::Dumper;

sub init {
    my $self = shift;

    $self->{last_report} = 0;

    $self->_load_min_max;

    Mojo::IOLoop->recurring(
        $self->node->{rate} => sub {
            my $loop = shift;

            $self->read->record->publish->announce;
        }
    );

    return $self;
}

sub _load_min_max {
    my $self = shift;

    $self->pg->db->query_p(
'select min(value), max(value) from sensor_history where input = ? and recorded_at > now() - interval \'3 days\''
          => $self->node->{name} )->then(
        sub {
            my $results = shift;
            my $minmax  = $results->hash;
            $self->node->{min} = $minmax->{min};
            $self->node->{max} = $minmax->{max};

#$self->log->debug(sprintf('input %s min %s max %s', $self->node->{name},$minmax->{min}, $minmax->{max}));
        }
          )->catch(
        sub {
            my $err = shift;
            $self->log->debug( sprintf( 'minmax error %s', $err ) );
        }
          )->wait;

}

sub read {
    my $self = shift;

    my $raw = $self->_read;
    if ($raw ne 'NO_VALUE') {
        $self->node->{val} = $self->node->{device}{calc}->( $raw );
        $self->log->debug(
            sprintf( 'read: %s (%s)', $self->node->{name}, $self->node->{val} ) );
    } else {
        delete($self->node->{val});
        $self->log->debug(
            sprintf( 'no data for: %s', $self->node->{name} ) );
    }

    return $self;
}

sub record {
    my $self = shift;

    $self->update_db($self->node->{name}, $self->node->{val});

    return $self;
}

sub update_db {
    my ($self, $input, $val) = @_;

    $self->log->debug(
        sprintf( 'record: %s (%s)', $input, $val ) )
      if defined( $val );

    $self->pg->db->query(
        'insert into sensor_history (input, value) values (?, ?)',
        $input,
        $val
      )
      or $self->log->error("could not update the database: $input $val");

}

sub publish {
    my $self = shift;

    if ( !exists( $self->node->{val} ) ) { return $self }

    my $val = $self->node->{val};

    $self->notify( $self->node->{name} . '_val', $val );

    if ( ( !defined $self->node->{min} ) || ( $val < $self->node->{min} ) ) {
        $self->node->{min} = $val;
        $self->notify( $self->node->{name} . '_min', $val );
    }
    if ( ( !defined $self->node->{max} ) || ( $val > $self->node->{max} ) ) {
        $self->node->{max} = $val;
        $self->notify( $self->node->{name} . '_max', $val );
	$self->{new_max} = 1;  # used for GPS.pm speed announcing.  maybe add to that class?
    } else {
	$self->{new_max} = 0;
    }

    return $self;
}

sub announce {
    my $self = shift;

    if ( !exists( $self->node->{val} ) ) { return $self }

    if ( $self->outside_threshold ) {
        $self->log->debug(
            sprintf(
                'announce: %s (%s)',
                $self->node->{name},
                $self->node->{val}
            )
        );
        $self->speak(
            sprintf( $self->node->{notify}{phrase}, $self->node->{val} ) );
        $self->{last_report} = $self->node->{val};
    }

    return $self;
}

sub outside_threshold {
    my $self = shift;

    my $notify = $self->node->{notify};

    if ($notify->{threshold} !~ /\d+/) { return 0 };

    if ( abs( $self->{last_report} - $self->node->{val} ) >
        $notify->{threshold} )
    {
        return 1;
    }
    return 0;
}

sub set_fan_speed {
    my ( $self, $percent ) = @_;

    my $writer = $self->node->{device}{writer};
    if ($writer) {
        $writer->( $self->node->{device}{chip}, $percent );
    }
    else {
        $self->log->error(
            sprintf( 'can\'t set device speed: %s', $self->node->{name} ) );
    }
}

sub notify {
    my ( $self, $input, $val ) = @_;

    $self->pg->pubsub->notify(
        sensor_detail_msg => encode_json( { $input => $val } ) );
    #$self->log->debug( sprintf( 'notify: %s (%s)', $input, $val ) );

}

sub speak {
    my ( $self, $words ) = @_;

    $self->log->debug( sprintf( 'told to speak: %s', $words ) );

    #    if ( app->defaults->{tts_count} ge 4 ) {
    #	app->log->info('tts has been throttled!');
    #	return;
    #    }

    #    app->defaults->{tts_count}++;

    my $tmp = File::Temp->new(
        TEMPLATE => 'temp-XXXXX',
        DIR      => "$Bin/../archive/audio",
        SUFFIX   => '.audio'
    );
    my $filename = $tmp->filename;

    my ( $file, $dirs, $suffix ) = fileparse($filename);

    my @args =
      ( sprintf( 'echo "%s" | /usr/bin/text2wave -o %s', $words, $filename ) );
    my $subprocess = Mojo::IOLoop::Subprocess->new;

    $subprocess->run(
        sub {
            my $subprocess = shift;

            my $detail = {
                type   => 'audio',
                volume => $self->config->{volume},
                file   => $file . $suffix,
                label  => $words,
            };

            system(@args);
            return $detail;
        },
        sub {
            my ( $subprocess, $err, @results ) = @_;

            $self->log->error( sprintf( 'could not do tts: %s', $err ) )
              if $err;

            $self->pg->pubsub->notify(
                sensor_msg => encode_json( $results[0] ) );
        }
    );
}

1;
