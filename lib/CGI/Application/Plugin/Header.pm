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

    $self->{__HEADER_PROPS} = do {
        my $props = $header->header;

        if ( my $PROPS = $self->{__HEADER_PROPS} ) {
            if ( $PROPS != $props ) { # numeric compare of references
                $header->clear;
                while ( my ($key, $value) = each %{$PROPS} ) {
                    $header->set( $key => $value );
                }
            }
        }

        $props;
    };

    if ( @props ) {
        if ( @props % 2 == 0 ) {
            while ( my ($key, $value) = splice @props, 0, 2 ) {
                $header->set( $key => $value );
            }
        }
        elsif ( @props == 1 ) {
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
      my $type = $self->header('type'); # => "text/html"

      # set header props.
      $self->header(
          charset => 'utf-8',
          type => 'text/plain'
      );

      # using CGI::Header::Props object
      my $header = $self->header;
      $header->get( $key );
      if ( $header->exists($key) ) { ... }
      $header->set( $key => $value );
      $header->delete( $key );
      $header->push_cookie( @cookies );

      # compatible with the core methods of CGI::Applications
      $self->header_props( $key => $value, ... );
      $self->header_add( $key => $value );
      $self->header_type( 'redirect' );
  }

  ...

=head1 DESCRIPTION

This plugin provides a way to handle CGI.pm-compatible HTTP header
properties.

=head2 FEATURES

=over

=item * Normalizes property names automatically
(e.g. C<Content_Type> -> C<type>),
and so you can specify them consistently.

=item * Compatible with the existing handlers such as
C<CGI::Application#header_props>, C<header_add> or C<header_type>.

=back

=head2 METHODS

This plugin exports the C<header()> method to your application on demand.

  use CGI::Application::Plugin::Header 'header';

C<header()> can be used as follows (C<$cgiapp> denotes the instance
of your application):

=over 4

=item $header = $cgiapp->header

Returns a L<CGI::Header::Props> object associated with C<$cgiapp>.

NOTE: This method updates C<CGI::Header::Props#handler> automatically,
and so you shouldn't set the attribute manually.

  # doesn't work as you expect
  $cgiapp->header->handler('redirect');

Use C<CGI::Application#header_type> instead:

  $cgiapp->header_type('redirect');
  $cgiapp->header->handler; # => "redirect"

=item $value = $cgiapp->header( $prop )

Returns the value of the specified property. It's identical to:

  $value = $cgiapp->header->get( $prop );

=item $cgiapp->header( $p1 => $v1, $p2 => $v2, ... )

Given key-value pairs of header props., merges them into the existing
properties.

=back

=head1 SEE ALSO

L<CGI::Application>, L<CGI::Header::Props>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
