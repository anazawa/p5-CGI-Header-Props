package CGI::Application::Plugin::Header;
use strict;
use warnings;
use CGI::Header::Props;
use Carp qw/croak/;
use Exporter 'import';

our @EXPORT_OK = qw( header );

sub header {
    my ( $self, @args ) = @_;

    my $header
        = $self->{+__PACKAGE__}
            ||= CGI::Header::Props->new( query => $self->query );

    $header->handler( $self->header_type );

    if ( !exists $self->{__HEADER_PROPS} ) {
        $self->{__HEADER_PROPS} = $header->header; # initialize
    }
    elsif ( $self->{__HEADER_PROPS} ne $header->header ) {
        $header->clear->set( $self->header_props );
        $self->{__HEADER_PROPS} = $header->header; # overwrite
    }

    if ( @args ) {
        if ( @args % 2 == 0 ) { # setter
            $header->set( @args );
        }
        elsif ( @args == 1 ) { # getter
            return $header->get( $args[0] );
        }
        else {
            croak "Odd number of elements passed to header()";
        }
    }

    $header;
}

1;

__END__

=head1 NAME

CGI::Application::Plugin::Header -

=head1 SYNOPSIS

  package MyApp;
  use parent 'CGI::Application';
  use CGI::Application::Plugin::Header 'header';

  ...

  sub do_something {
      my $self = shift;

      # get header props.
      my $type = $self->header('-type'); # => "text/html"

      # set header props.
      $self->header(
          -charset => 'utf-8',
          -type => 'text/plain'
      );

      # using CGI::Header::Props object
      my $header = $self->header;
      $header->get( $key );
      if ( $header->exists($key) ) { ... }
      $header->set( $key => $value );
      $header->delete( $key );

      # compatible with CGI::Application's core methods
      $self->header_props( $key => $value, ... );
      $self->header_add( $key => $value );
  }

  ...

=cut
