package TelemControl;
use Mojo::Base 'Mojolicious';

use FindBin qw($Bin);
use TelemControl::Model::Sensors;
use TelemControl::Model::ThermalLimiting;

use Mojo::Pg;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Configuration
    my $config =
      $self->plugin( Config => { file => "$Bin/../conf/telem_control.conf" } );
    $self->helper( config => sub { return $config } );

    $self->secrets( $self->config('secrets') );

    # Logging
    $self->helper( log => sub { return $self->app->log } );

    $self->plugin('Mojolicious::Plugin::CORS');
    $self->plugin('RenderFile');

    # Model
    $self->helper( pg => sub { state $pg = Mojo::Pg->new( $config->{pg} ) } );

    my $sensors = TelemControl::Model::Sensors->new(
        log    => $self->log,
        config => $self->config,
        pg     => $self->pg,
    );
    $self->helper( sensors => sub { return $sensors } );

    $self->sensors->init;

    TelemControl::Model::ThermalLimiting->new( $self->{log}, $config,
        $self->sensors );

    $self->helper(
        minmax_msg =>
          sub {
            return { type => 'minmax', %{ $self->sensors->get_min_max } };
        }
    );

    # Controller
    my $r = $self->routes;
    $r->get('/script')->to( controller => 'main', action => 'script' );
    $r->get('/self')->to( controller => 'main', action => 'self' );
    $r->websocket('/output')->to( controller => 'main', action => 'output' );
    $r->websocket('/output_detail')
      ->to( controller => 'main', action => 'output_detail' );
    $r->get('/audio')->to( controller => 'main', action => 'audio' );
}

1;
