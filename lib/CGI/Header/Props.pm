package CGI::Header::Props;
use 5.008_009;
use strict;
use warnings;
use Carp qw/croak/;

our $VERSION = '0.01';

our %PROPERTY_ALIAS = (
    header => {
        -content_type  => '-type',
        -cookies       => '-cookie',
        -set_cookie    => '-cookie',
        -window_target => '-target',
    },
    redirect => {
        -content_type  => '-type',
        -cookies       => '-cookie',
        -set_cookie    => '-cookie',
        -uri           => '-location',
        -url           => '-location',
        -window_target => '-target',
    },
);

sub new {
    my $class = shift;

    bless {
        handler => 'header',
        header => {},
        @_,
    }, $class;
}

sub handler {
    my $self = shift;

    if ( @_ ) {
        my $handler = shift;

        if ( $handler ne 'header' and $handler ne 'redirect' ) {
            croak "Invalid handler '$handler' passed to handler()";
        }
        elsif ( $handler ne $self->{handler} ) {
            $self->{handler} = $handler;
            $self->rehash if $handler eq 'redirect';
        }

        return $handler;
    }

    $self->{handler};
}

sub header {
    $_[0]->{header};
}

sub query {
    my $self = shift;
    $self->{query} ||= $self->_build_query;
}

sub _build_query {
    require CGI;
    CGI::self_or_default();
}

sub normalize {
    my $self = shift;
    my $prop = _lc( shift );
    my $handler = $self->{handler};
    $PROPERTY_ALIAS{$handler}{$prop} || $prop;
}

sub rehash {
    my $self   = shift;
    my $header = $self->{header};

    for my $key ( keys %{$header} ) {
        my $prop = $self->normalize( $key );
        next if $key eq $prop; # $key is normalized
        croak "Property '$prop' already exists" if exists $header->{$prop};
        $header->{$prop} = delete $header->{$key}; # rename $key to $prop
    }

    $self;
}

sub get {
    my ( $self, $key ) = @_;
    my $prop = $self->normalize( $key );
    $self->{header}->{$prop};
}

sub set {
    my ( $self, $key, $value ) = @_;
    my $prop = $self->normalize( $key );
    $self->{header}->{$prop} = $value;
}

sub exists {
    my ( $self, $key ) = @_;
    my $prop = $self->normalize( $key );
    exists $self->{header}->{$prop};
}

sub delete {
    my ( $self, $key ) = @_;
    my $prop = $self->normalize( $key );
    delete $self->{header}->{$prop};
}

sub push_cookie {
    my $self = shift;
    $self->_push( '-cookie', @_ );
}

sub push_p3p {
    my $self = shift;
    $self->_push( '-p3p', @_ );
}

sub _push {
    my $self   = shift;
    my $prop   = shift;
    my @values = ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
    my $header = $self->{header};

    if ( my $value = $header->{$prop} ) {
        return push @{$value}, @values if ref $value eq 'ARRAY';
        unshift @values, $value;
    }

    $header->{$prop} = @values > 1 ? \@values : $values[0];

    scalar @values;
}

sub flatten {
    %{ $_[0]->{header} };
}

sub clear {
    my $self = shift;
    %{ $self->{header} } = ();
    $self;
}

sub attachment {
    my $self   = shift;
    my $header = $self->{header};

    if ( @_ ) {
        my $attachment = shift;
        delete $header->{-content_disposition} if $attachment;
        return $header->{-attachment} = $attachment;
    }

    $header->{-attachment};
}

sub charset {
    my $self = shift;
    my $header = $self->{header};
    return $header->{-charset} = shift if @_;
    defined $header->{-charset} ? $header->{-charset} : $self->query->charset;
}

sub cookie {
    my $self = shift;
    my $header = $self->{header};

    if ( @_ ) {
        my $cookie = @_ > 1 ? [ @_ ] : shift;
        delete $header->{-date} if $cookie;
        return $header->{-cookie} = $cookie;
    }
    elsif ( my $cookie = $header->{-cookie} ) {
        return ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
    }

    return;
}

sub expires {
    my $self   = shift;
    my $header = $self->{header};

    if ( @_ ) {
        my $expires = shift;
        delete $header->{-date} if $expires;
        return $header->{-expires} = $expires;
    }

    $header->{-expires};
}

sub nph {
    my $self   = shift;
    my $header = $self->{header};
    my $NPH    = $self->query->nph; # => $CGI::NPH

    if ( @_ ) {
        my $nph = shift;
        croak "The '-nph' pragma is enabled" if !$nph and $NPH;
        delete @{ $header }{qw/-date -server/} if $nph;
        return $header->{-nph} = $nph;
    }

    $NPH or $header->{-nph};
}

sub p3p {
    my $self   = shift;
    my $header = $self->{header};

    if ( @_ ) {
        return $header->{-p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $header->{-p3p} ) {
        return ref $tags eq 'ARRAY' ? @{$tags} : split ' ', $tags;
    }

    return;
}

sub as_string {
    my $self = shift;
    my $handler = $self->{handler};
    $self->query->$handler( $self->{header} );
}

sub _lc {
    my $str = lc shift;
    $str =~ s/^-//;
    $str =~ tr/-/_/;
    "-$str";
}

1;

__END__

=head1 NAME

CGI::Header::Props - handle CGI.pm-compatible HTTP header properties

=head1 SYNOPSIS

  use CGI;
  use CGI::Header::Props;

  my $query = CGI->new;

  # CGI.pm-compatibe HTTP header properties
  my $header = {
      -type    => 'text/html',
      -charset => 'utf-8'
  };

  my $props = CGI::Header::Props->new(
      query   => $query,
      handler => 'header', # or 'redirect'
      header  => $header
  );

  # inspect $header
  $props->get('type'); # => "text/plain"
  $props->exists('type'); # => true

  # update $header 
  $props->set( type => 'text/plain' ); # overwrite
  $props->delete('type'); # => "text/plain"
  $props->clear; # => $self

  $props->handler('redirect');
  $props->as_string; # invokes $query->redirect

  # convenience methods
  $props->p3p(qw/CAO DSP LAW CURa/);
  $props->expires('+3d');
  $props->nph(1);
  $props->push_cookie( @cookies ); # @cookies are CGI::Cookie objects

  $props->header; # same reference as $header

=head1 VERSION

This document refers to CGI::Header::Props version 0.01;

=head1 DESCRIPTION

This module helps you handle CGI.pm-compatible HTTP header properties.

Unlike L<CGI::Header>, this module focuses on manipulating
the header property itself. If you're familiar with L<CGI::Application>'s
C<header_add()>, C<header_props()> or C<header_type()> method, you can use
this module easily.

=head1 METHODS

=over 4

=item $props = CGI::Header::Props->new

Create a new C<CGI::Header::Props> object.

=item $props->header 

Returns the header hash associated with this C<CGI::Header::Props>
object. This attribute defaults to a reference to an empty hash.

=item $props->query

Returns the query object associated with this C<CGI::Header::Props> object.
This attribute defaults to the Singleton instance of CGI.pm (C<$CGI::Q>).

=item $props->handler

Works like L<CGI::Application>'s C<header_type()> method.
This method can be used to declare that you are setting a redirection
header. This attribute defaults to C<header>.

  $props->handler('redirect');
  $props->as_string; # invokes $props->query->redirect

=item $self = $props->rehash

Rebuilds the header hash to normalize property names without changing
the reference. Returns this object itself. If property names aren't
normalized, the methods listed below won't work as you expect.

  my $h1 = $props->header;
  # => {
  #      '-content_type'   => 'text/plain',
  #      'Set-Cookie'      => 'ID=123456; path=/',
  #      'expires'         => '+3d',
  #      '-target'         => 'ResultsWindow',
  #      '-content-length' => '3002',
  # }

  $props->rehash;

  my $h2 = $props->header; # same reference as $h1
  # => {
  #      '-type'           => 'text/plain',
  #      '-cookie'         => 'ID=123456; path=/',
  #      '-expires'        => '+3d',
  #      '-target'         => 'ResultsWindow',
  #      '-content-length' => '3002',
  # }

Normalized property names are:

=over 4

=item 1. lowercased

  'Content-Length' -> 'content-length'

=item 2. start with a dash

  'content-length' -> '-content-length'

=item 3. use underscores instead of dashes except for the first character

  'content-length' -> '-content_length'

=back

CGI.pm's C<header()> method also accepts aliases of property names.
This module converts them as follows:

  # for CGI#header
  '-content_type'  -> '-type'
  '-cookies'       -> '-cookie'
  '-set_cookie'    -> '-cookie'
  '-window_target' -> '-target'

  # for CGI#redirect
  '-content_type'  -> '-type'
  '-cookies'       -> '-cookie'
  '-set_cookie'    -> '-cookie'
  '-uri'           -> '-location'
  '-url'           -> '-location'
  '-window_target' -> '-target'

If a property name is duplicated, throws an exception:

  $props->header;
  # => {
  #     -Type        => 'text/plain',
  #     Content_Type => 'text/html',
  # }

  $props->rehash; # die "Property "-type' already exists"

=item $value = $props->get( $prop )

=item $props->set( $prop => $value )

Get or set the value of the header property.
The property name (C<$prop>) is not case sensitive.
You can use dashes as a replacement for underscores in property names.

  $props->get('content_length');
  $props->get('Content-Length');

The C<$value> argument may be a plain string or a reference to an array
of L<CGI::Cookie> objects for the C<-cookie> property:

  $props->set( 'content_length' => 3002 );
  my $length = $props->get('content_length'); # => 3002

  # $cookie1 and $cookie2 are CGI::Cookie objects
  $props->set( cookie => [$cookie1, $cookie2] );
  my $cookies = $props->get('cookie'); # => [$cookie1, $cookie2]

=item $value = $props->delete( $prop )

Deletes the specified property. Returns the value of the deleted property.

  my $value = $props->delete('content_disposition'); # => "inline"

=item $bool = $props->exists( $prop )

Returns a Boolean value telling whether the specified property exists.

  if ( $props->exists('etag') ) {
      ...
  }

=item $self = $props->clear

This will remove all header properties. Returns this object itself.

=item @tags = $props->p3p

=item $props->p3p( @tags )

Represents P3P tags. The parameter can be an array or a space-delimited
string. Returns a list of P3P tags. (In scalar context, returns the number
of P3P tags.)

  $props->p3p(qw/CAO DSP LAW CURa/);
  # or
  $props->p3p('CAO DSP LAW CURa');

  my @tags = $props->p3p; # => ("CAO", "DSP", "LAW", "CURa")
  my $size = $props->p3p; # => 4

In this case, the outgoing header will be formatted as:

  P3P: policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"

=item $props->expires

The Expires header gives the date and time after which the entity
should be considered stale. You can specify an absolute or relative
expiration interval. The following forms are all valid for this field:

  $props->expires('+30s'); # 30 seconds from now
  $props->expires('+10m'); # ten minutes from now
  $props->expires( '+1h'); # one hour from now
  $props->expires( 'now'); # immediately
  $props->expires( '+3M'); # in three months
  $props->expires('+10y'); # in ten years time

  # at the indicated time & date
  $props->expires('Thu, 25 Apr 1999 00:40:33 GMT');

=item $props->attachment

Can be used to turn the page into an attachment.
Represents suggested name for the saved file.

  $props->attachment('genome.jpg');
  my $filename = $props->attachment; # => "genome.jpg"

In this case, the outgoing header will be formatted as:

  Content-Disposition: attachment; filename="genome.jpg"

=item $props->nph

If set to a true value, will issue the correct headers to work with
a NPH (no-parse-header) script.

=item $props->push_cookie( @cookies )

Given a list of L<CGI::Cookie> objects, appends them to the existing
C<cookie> property.

=item $props->push_p3p( @tags )

Given a list of P3P tags, appends them to the existing C<p3p> property.

=item $props->charset

Returns the character set sent to the browser.

=item $props->cookie( @cookies )

=item @cookies = $props->cookie

Get or set the C<cookie> property.

=item $props->as_string

Stringifies the header props. associated with this object.
The header props. will be passed to CGI.pm's C<header()> or C<redirect()>
method.

=back

=head1 SEE ALSO

L<CGI>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
