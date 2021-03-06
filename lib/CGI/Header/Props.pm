package CGI::Header::Props;
use 5.008_009;
use strict;
use warnings;
use Carp qw/croak/;

our $VERSION = '0.01';

my %Alias = (
    'content-type'  => 'type',
    'cookies'       => 'cookie',
    'set-cookie'    => 'cookie',
    'uri'           => 'location',
    'url'           => 'location',
    'window-target' => 'target',
);

sub new {
    my $class = shift;

    bless {
        handler => 'header',
        header => {},
        @_
    }, $class;
}

sub handler {
    my $self = shift;
    return $self->{handler} unless @_;
    $self->{handler} = shift;
    $self;
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

sub rehash {
    my $self   = shift;
    my $header = $self->{header};

    for my $key ( keys %{$header} ) {
        my $prop = lc $key;
           $prop =~ s/^-//;
           $prop =~ tr/_/-/;
           $prop = $Alias{$prop} || $prop;

        next if $key eq $prop; # $key is normalized
        croak "Property '$prop' already exists" if exists $header->{$prop};
        $header->{$prop} = delete $header->{$key}; # rename $key to $prop
    }

    $self;
}

sub get {
    my $self = shift;
    my $field = lc shift;
    $self->{header}->{$field};
}

sub set {
    my $self = shift;
    my $field = lc shift;
    $self->{header}->{$field} = shift;
}

sub exists {
    my $self = shift;
    my $field = lc shift;
    exists $self->{header}->{$field};
}

sub delete {
    my $self = shift;
    my $field = lc shift;
    delete $self->{header}->{$field};
}

sub push_cookie {
    my $self = shift;
    $self->_push( 'cookie', @_ );
}

sub push_p3p {
    my $self = shift;
    $self->_push( 'p3p', @_ );
}

sub _push {
    my ( $self, $prop, @values ) = @_;

    if ( my $value = $self->{header}->{$prop} ) {
        return push @{$value}, @values if ref $value eq 'ARRAY';
        unshift @values, $value;
    }

    $self->{header}->{$prop} = @values > 1 ? \@values : $values[0];

    scalar @values;
}

sub clear {
    my $self = shift;
    %{ $self->{header} } = ();
    $self;
}

BEGIN {
    my @props = qw(
        attachment
        charset
        expires
        location
        nph
        status
        target
        type
    );

    for my $prop ( @props ) {
        my $code = sub {
            my $self = shift;
            return $self->{header}->{$prop} unless @_;
            $self->{header}->{$prop} = shift;
            $self;
        };

        no strict 'refs';
        *{$prop} = $code;
    }
}

sub cookie {
    my $self = shift;

    if ( @_ ) {
        $self->{header}->{cookie} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $cookie = $self->{header}->{cookie} ) {
        return ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
    }
    else {
        return;
    }

    $self;
}

sub p3p {
    my $self = shift;

    if ( @_ ) {
        $self->{header}->{p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $self->{header}->{p3p} ) {
        my @tags = ref $tags eq 'ARRAY' ? @{$tags} : $tags;
        return map { split ' ', $_ } @tags;
    }
    else {
        return;
    }

    $self;
}

sub to_hash {
    my $self  = shift;
    my $query = $self->query;
    my %hash  = %{ $self->{header} };

    require CGI::Util;

    if ( $self->{handler} eq 'redirect' ) {
        $hash{location} = $query->self_url if !$hash{location};
        $hash{status}   = '302 Found' if !defined $hash{status};
        $hash{type}     = q{} if !exists $hash{type};
    }

    my ( $attachment, $charset, $cookie, $expires, $nph, $p3p, $status, $target, $type )
        = delete @hash{qw/attachment charset cookie expires nph p3p status target type/};

    # "foo-bar" -> "Foo-bar"
    %hash = map { ucfirst $_, delete $hash{$_} } keys %hash;

    $hash{'Server'}        = $query->server_software if $nph or $query->nph;
    $hash{'Status'}        = $status if $status;
    $hash{'Window-Target'} = $target if $target;

    if ( $p3p ) {
        my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{$p3p} : $p3p;
        $hash{'P3P'} = qq{policyref="/w3c/p3p.xml", CP="$tags"};
    }

    if ( $cookie ) {
        my @cookies = ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
        $hash{'Set-Cookie'} = join ', ', @cookies;
    }

    $hash{'Expires'} = CGI::Util::expires($expires) if $expires;
    $hash{'Date'}    = CGI::Util::expires() if $expires or $cookie or $nph;
    $hash{'Pragma'}  = 'no-cache' if $query->cache;

    if ( $attachment ) {
        $hash{'Content-Disposition'} = qq{attachment; filename="$attachment"};
    }

    if ( !defined $type or $type ne q{} ) {
        $charset = $query->charset unless defined $charset;
        my $ct = $type || 'text/html';
        $ct .= "; charset=$charset" if $charset && $ct !~ /\bcharset\b/;
        $hash{'Content-Type'} = $ct;
    }

    \%hash;
}

sub to_string {
    my $self    = shift;
    my $handler = $self->{handler};
    my $query   = $self->query;

    if ( $handler eq 'header' or $handler eq 'redirect' ) {
        if ( my $method = $query->can($handler) ) {
            return $query->$method( $self->{header} );
        }
        else {
            croak ref($query) . " is missing '$handler' method";
        }
    }
    elsif ( $handler eq 'none' ) {
        return q{};
    }
    else {
        croak "Invalid handler '$handler'";
    }

    return;
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
      type    => 'text/html',
      charset => 'utf-8'
  };

  my $props = CGI::Header::Props->new(
      query   => $query,
      handler => 'header', # or 'redirect'
      header  => $header
  );

  # inspect $header
  $props->get('Content-Length'); # => 3002
  $props->exists('Content-Length'); # => true

  # update $header 
  $props->set( 'Content-Length' => 3002 ); # overwrite
  $props->delete('Content-Length'); # => 3002
  $props->clear; # => $self

  # convenience methods
  $props->attachment('genome.jpg');
  $props->charset('utf-8'); 
  $props->cookie( @cookies ); # @cookies are CGI::Cookie objects
  $props->expires('+3d');
  $props->location('http://somewhere.else/in/movie/land');
  $props->nph(1);
  $props->p3p(qw/CAO DSP LAW CURa/);
  $props->status('301 Moved Permanently');
  $props->type('image/gif');

  $props->header; # same reference as $header

  # stringify $header
  $props->handler('redirect');
  $props->as_string; # invokes $query->redirect

=head1 VERSION

This document refers to CGI::Header::Props version 0.01.

=head1 DESCRIPTION

This module helps you handle CGI.pm-compatible HTTP header properties.
Instances of CGI.pm-based application often hold those properties.
CGI.pm's C<header> or C<redirect> method is used to convert the header
property into CGI response headers.

This module is inspired by how L<CGI::Application> handles the header
property. The framework has C<header_props> attribute. C<header_add>
method can be used to update C<header_props>. C<header_type> represents
which method of CGI.pm (C<header> or C<redirect>) stringifies C<header_props>
when C<run> is invoked.

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

=item $self = $props->handler('redirect')

Works like L<CGI::Application>'s C<header_type()> method.
This method can be used to declare that you are setting a redirection
header. This attribute defaults to C<header>.

  $props->hadnler('redirect')->as_string; # invokes $props->query->redirect

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

  'Content_Type' -> 'content_type'

=item 2. use dashes instead of underscores except for the first character

  'content_type' -> 'content-type'

=back

CGI.pm's C<header()> method also accepts aliases of property names.
This module converts them as follows:

  'content-type'  -> 'type'
  'cookies'       -> 'cookie'
  'set-cookie'    -> 'cookie'
  'uri'           -> 'location'
  'url'           -> 'location'
  'window-target' -> 'target'

If a property name is duplicated, throws an exception:

  $props->header;
  # => {
  #     -Type        => 'text/plain',
  #     Content_Type => 'text/html',
  # }

  $props->rehash; # die "Property "type' already exists"

=item $value = $props->get( $field )

=item $value = $props->set( $field => $value )

Get or set the value of the header field.
The field name (C<$field>) is not case sensitive.

  $props->get('content-length');
  $props->get('Content-Length');

The C<$value> argument must be a plain string:

  $props->set( 'Content-Length' => 3002 );
  my $length = $props->get('Content-Length'); # => 3002

=item $value = $props->delete( $field )

Deletes the specified field. Returns the value of the deleted field.

  my $value = $props->delete('Content-Disposition'); # => "inline"

=item $bool = $props->exists( $field )

Returns a Boolean value telling whether the specified property exists.

  if ( $props->exists('ETag') ) {
      ...
  }

=item $self = $props->clear

This will remove all header properties. Returns this object itself.

=item $props->as_string

Stringifies the header props. associated with this object.
The header props. will be passed to CGI.pm's C<header()> or C<redirect()>
method (It depends on the return value of C<< $props->handler >>).
It's identical to:

  my $handler = $props->handler; # => "header" or "redirect"
  $props->query->$handler( $props->header );

=back

=head4 PROPERTIES

The following methods were named after property names recognized by
CGI.pm's C<header> method.
Most of these methods can both be used to read and to set the value of
a property.

If you pass an argument to the method, the property value will be set,
and also the current object itself will be returned ; therefore you
can chain methods as follows:

  $props->type('text/html')->charset('utf-8');

If no argument is supplied, the property value will be returned.
If the given property doesn't exist, C<undef> will be returned.

=over 4

=item $self = $props->attachment( $filename )

=item $filename = $props->attachment

Get or set the C<attachment> property.
Can be used to turn the page into an attachment.
Represents suggested name for the saved file.

  $props->attachment('genome.jpg');
  my $filename = $props->attachment; # => "genome.jpg"

In this case, the outgoing header will be formatted as:

  Content-Disposition: attachment; filename="genome.jpg"

=item $self = $props->charset( $character_set )

=item $character_set = $props->charset

Get or set the C<charset> property. Represents the character set sent to
the browser.

=item $self = $props->cookie( @cookies )

=item @cookies = $props->cookie

Get or set the C<cookie> property.
The parameter can be a list of L<CGI::Cookie> objects.

=item $props->push_cookie( @cookies )

Given a list of L<CGI::Cookie> objects, appends them to the
C<cookie> property.

=item $self = $props->expires( $format )

=item $format = $props->expires

Get or set the C<expires> property.
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

If set to a true value, the C<date> property will be removed automatically.

=item $self = $props->location( $url )

=item $url = $props->location

Get or set the Location header.

  $props->location('http://somewhere.else/in/movie/land');

=item $self = $props->nph( $bool )

=item $bool = $props->nph

Get or set the C<nph> property.
If set to a true value, will issue the correct headers to work with
a NPH (no-parse-header) script.

  $props->nph(1);

=item $self = $props->p3p( @tags )

=item @tags = $props->p3p

Get or set the C<p3p> property. The parameter can be an array or a
space-delimited string.
Returns a list of P3P tags. (In scalar context, returns the number
of P3P tags.)

  $props->p3p(qw/CAO DSP LAW CURa/);
  # or
  $props->p3p('CAO DSP LAW CURa');

  my @tags = $props->p3p; # => ("CAO", "DSP", "LAW", "CURa")
  my $size = $props->p3p; # => 4

In this case, the outgoing header will be formatted as:

  P3P: policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"

=item $props->push_p3p( @tags )

Given a list of P3P tags, appends them to the C<p3p> property.

=item $self = $props->status( $status )

=item $status = $props->status

Get or set the Status header.

  $props->status('304 Not Modified');

=item $self = $props->target( $window_target )

=item $window_target = $props->target

Get or set the Window-Target header.

  $props->target('ResultsWindow');

=item $self = $props->type( $media_type )

=item $media_type = $props->type

Get or set the C<type> property. Represents the media type of the message
content.

  $props->type('text/html');


=back

=head1 SEE ALSO

L<CGI>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
