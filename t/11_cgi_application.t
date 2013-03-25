use strict;
use Test::More tests => 5;

package MyApp;
use base 'CGI::Application';
use CGI::Application::Plugin::Header 'header';

sub setup {
    my $self = shift;
    $self->run_modes( start => 'do_start' );
}

sub do_start {
    my $self = shift;
    'hello, world';
}

package main;

my $app = MyApp->new;

isa_ok $app->header, 'CGI::Header::Props';

$app->header(
    -charset => 'utf-8',
    -type => 'text/plain',
);

is_deeply +{ $app->header_props }, {
    -charset => 'utf-8',
    -type => 'text/plain',
}, '__HEADER_PROPS should be updated';

is $app->header('-type'), 'text/plain',
    "should return the value of '-type'"; 

$app->header_props(
    -charset => 'utf-8',
    -type => 'text/plain',
);

is_deeply $app->header->header, {
    -charset => 'utf-8',
    -type => 'text/plain',
}, 'CGI::Header::Props#header should return __HEADER_PROPS';

$app->header_type('redirect');
is $app->header->handler, $app->header_type,
    'handler() should be updated';
