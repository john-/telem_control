package TelemControl;
use Mojo::Base 'Mojolicious';

use FindBin qw($Bin);
use TelemControl::Model::Sensors;
use TelemControl::Model::ThermalLimiting;

use Mojo::Pg;
#use Mojo::Pg::Database;

use Data::Dumper;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Configuration
  #$self->plugin(Config => {file => "$Bin/../conf/telem_control.conf"});
  my $config = $self->plugin(Config => {file => "$Bin/../conf/telem_control.conf"});
  $self->helper(config => sub { return $config } );

  $self->secrets($self->config('secrets'));

  # Logging
  $self->{log} = Mojo::Log->new( path => "$Bin/../log/telem_control.log" );
  $self->helper(log => sub { return $self->{log} } );
#  $self->helper(log =>
#       sub { state $log = Mojo::Log->new(path => "$Bin/../log/telem_control.log") } );

  $self->plugin('Mojolicious::Plugin::CORS');
  $self->plugin('RenderFile');

  # Model
  $self->helper(pg => sub { state $pg = Mojo::Pg->new($config->{pg}) });

  my $sensors = TelemControl::Model::Sensors->new( log => $self->log,
                                                   config => $self->config,
						   pg => $self->pg,
	  );
  $self->helper( sensors => sub { return $sensors } );

  $self->sensors->initialize;
  #$self->sensors->report_min_max;
  #$self->sensors->set_fan_speed(20);

  TelemControl::Model::ThermalLimiting->new($self->{log}, $config, $self->sensors);

  #TelemControl::Model::GPS->new($log, $config);

  $self->helper(config_msg => sub {   # TODO:  not really a config...it is the min/max values
      return { type => 'config', %{$self->sensors->get_min_max} }
  });

  # Documentation browser under "/perldoc"
  #$self->plugin('PODRenderer');

  # Controller
  my $r = $self->routes;
  $r->get('/script')->to(controller => 'main', action => 'script');
  $r->get('/self')->to(controller => 'main', action => 'self');
  $r->websocket('/output')->to(controller => 'main', action => 'output');
  $r->websocket('/output_detail')->to(controller => 'main', action => 'output_detail');
  $r->get('/audio')->to(controller => 'main', action => 'audio');
}

1;
