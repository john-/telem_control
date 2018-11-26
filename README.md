Telem Control
=============
This is a websocket interface to various implementation specific inputs.

Dependencies
------------

* Very dependent on my hardware/environment.
* Front end (cart_console).  This application has no user unterface on its own.
* Mojolicious
* PostgresSQL
* Modules/Plugins
  * Mojolicious::Plugin::RenderFile
  * Mojolicious::Plugin::CORS to address same origin policy in browsers
  * Other stuff

Note
----
This is not intended for general use and will never be used outside environment it was created for..

Running
-------
./telem_control daemon --listen "http://*:3002"

