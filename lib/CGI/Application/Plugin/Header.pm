package CGI::Application::Plugin::Header;
use strict;
use warnings;
use CGI::Header::Props;
use Carp qw/croak/;
use Exporter 'import';

our @EXPORT_OK = qw( header );

sub header {
    my ( $self, @props ) = @_;

    my $header
        = $self->{+__PACKAGE__}
            ||= CGI::Header::Props->new( query => $self->query );

    $header->handler( $self->header_type );

    if ( !$self->{__HEADER_PROPS} ) {
        $self->{__HEADER_PROPS} = $header->header; # initialize
    }
    elsif ( $self->{__HEADER_PROPS} != $header->header ) {
        $header->clear->set( $self->header_props );
        $self->{__HEADER_PROPS} = $header->header; # overwrite
    }

    if ( @props ) {
        if ( @props % 2 == 0 ) { # setter
            $header->set( @props );
        }
        elsif ( @props == 1 ) { # getter
            return $header->get( $props[0] );
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

CGI::Application::Plugin::Header - Plugin for handling header props.

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

      # compatible with the core methods of CGI::Applications
      $self->header_props( $key => $value, ... );
      $self->header_add( $key => $value );
      $self->header_type( 'redirect' );
  }

  ...

=head1 DESCRIPTION

This plugin provides a way to handle CGI.pm-compatible HTTP header
properties.

=head2 METHODS

=over 4

=item $cgiapp->header

Returns a L<CGI::Header::Props> object.

=item $value = $cgiapp->header( $prop )

A shortcut for:

  $value = $cgiapp->header->get( $prop );

=item $cgiapp->header( $p1 => $v1, $p2 => $v2, ... )

A shortcut for:

  $cgiapp->header->set(
      $p1 => $v1,
      $p2 => $v2,
      ...
  );

=back

=head1 SEE ALSO

L<CGI::Application>, L<CGI::Header::Props>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
