use strict;
use warnings;
use Test::More tests => 1;

sub run_blosxom {
    package blosxom;
    require CGI;

    our $static_entries = 0;
    our $header = { -type => 'text/html' };
    our $output = "hello, world";

    my $plugin = 'my_plugin';
    $plugin->last if $plugin->start;

    return CGI::header( $header );
}

package my_plugin;
use CGI::Header::Props;

sub start {
    !$blosxom::static_entries;
}

sub last {
    my $props = CGI::Header::Props->new( header => $blosxom::header )->rehash;
    $props->set( 'Content-Length' => length $blosxom::output );
}

package main;

my $got = run_blosxom();

my $expected
    = "Content-length: 12$CGI::CRLF"
    . "Content-Type: text/html; charset=ISO-8859-1$CGI::CRLF"
    . $CGI::CRLF;

is $got, $expected, 'Blosxom should send the Content-Length header';

