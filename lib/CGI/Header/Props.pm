package CGI::Header::Props;
use 5.008_009;
use strict;
use warnings;
use Carp qw/croak/;

our $VERSION = '0.01';

my %PROPERTY_ALIAS = (
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

sub time2str {
    require CGI::Util;
    CGI::Util::expires( $_[1], 'http' );
}

sub new {
    my $class = shift;
    bless { @_ }, $class;
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

sub handler {
    my $self = shift;

    if ( @_ ) {
        my $handler = lc shift;

        if ( $handler ne 'header' and $handler ne 'redirect' ) {
            croak "Invalid handler '$handler' passed to handler()";
        }
        elsif ( $handler ne $self->{handler} ) {
            $self->{handler} = $handler;
            $self->header_rehash if $handler eq 'redirect';
        }
        else {
            # do nothing
        }

        return $handler;
    }

    $self->{handler};
}

sub header_type {
    my $self = shift;
    $self->handler(@_);
}

sub normalize_property_name {
    my $self = shift;
    my $prop = _lc( shift );
    my $handler = $self->{handler};
    $PROPERTY_ALIAS{$handler}{$prop} || $prop;
}

sub header_rehash {
    my $self   = shift;
    my $header = $self->{header};

    for my $key ( keys %{$header} ) {
        my $prop = $self->normalize_property_name( $key );
        next if $key eq $prop; # $key is normalized
        croak "Property '$prop' already exists" if exists $header->{$prop};
        $header->{$prop} = delete $header->{$key}; # rename $key to $prop
    }

    $self;
}

sub header_props {
    my $self = shift;

    if ( @_ ) {
        if ( ref $_[0] eq 'HASH' ) {
            $self->header_clear;
            while ( my ($key, $value) = each %{$_[0]} ) {
                $self->header_set( $key => $value );
            }
        }
        elsif ( @_ % 2 == 0 ) {
            $self->header_clear;
            while ( my ($key, $value) = splice @_, 0, 2 ) {
                $self->header_set( $key => $value );
            }
        }
        else {
            croak 'Odd number of elements passed to header_props()';
        }
    }

    %{ $self->{header} };
}

sub header_get {
    my $self = shift;
    my $prop = $self->normalize_property_name( shift );
    $self->{header}->{$prop};
}

sub header_set {
    my $self = shift;
    my $prop = $self->normalize_property_name( shift );
    $self->{header}->{$prop} = shift;
}

sub header_exists {
    my $self = shift;
    my $prop = $self->normalize_property_name( shift );
    exists $self->{header}->{$prop};
}

sub header_delete {
    my $self = shift;
    my $prop = $self->normalize_property_name( shift );
    delete $self->{header}->{$prop};
}

sub header_clear {
    my $self = shift;
    %{ $self->{header} } = ();
    $self;
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

sub attachment {
    my $self   = shift;
    my $header = $self->{header};

    if ( @_ ) {
        my $value = shift;
        delete $header->{-content_disposition} if $value;
        return $header->{-attachment} = $value;
    }

    $header->{-attachment};
}

sub expires {
    my $self   = shift;
    my $header = $self->{header};

    if ( @_ ) {
        my $value = shift;
        delete $header->{-date} if $value;
        return $header->{-expires} = $value;
    }

    $header->{-expires};
}

sub p3p {
    my $self   = shift;
    my $header = $self->{header};

    if ( @_ ) {
        $header->{-p3p} = @_ > 1 ? [ @_ ] : shift;
    }
    elsif ( my $tags = $header->{-p3p} ) {
        return ref $tags eq 'ARRAY' ? @{$tags} : split ' ', $tags;
    }

    return;
}

sub push_cookie {
    my $self    = shift;
    my @cookies = ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;
    my $header  = $self->{header};

    if ( my $cookie = $header->{-cookie} ) {
        return push @{$cookie}, @cookies if ref $cookie eq 'ARRAY';
        unshift @cookies, $cookie;
    }

    $header->{-cookie} = @cookies > 1 ? \@cookies : $cookies[0];

    scalar @cookies;
}

sub flatten {
    my $self   = shift;
    my $query  = $self->query;
    my %header = %{ $self->{header} }; # copy
    my $nph    = delete $header{-nph} || $query->nph;

    if ( $self->{handler} eq 'redirect' ) {
        $header{-type} = q{} if !exists $header{-type};
        $header{-status} = '302 Found' if !defined $header{-status};
        $header{-location} ||= $query->self_url;
    }

    my @headers;

    my ( $charset, $cookie, $expires, $status, $target, $type )
        = delete @header{qw/-charset -cookie -expires -status -target -type/};

    push @headers, 'Server', $query->server_software if $nph;
    push @headers, 'Status', $status        if $status;
    push @headers, 'Window-Target', $target if $target;

    if ( my $tags = delete $header{-p3p} ) {
        $tags = join ' ', @{ $tags } if ref $tags eq 'ARRAY';
        push @headers, 'P3P', qq{policyref="/w3c/p3p.xml", CP="$tags"};
    }

    if ( $cookie ) {
        my @cookies = ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
        push @headers, map { ('Set-Cookie', "$_") } @cookies;
    }

    push @headers, 'Expires', $self->time2str($expires) if $expires;
    push @headers, 'Date', $self->time2str if $expires or $cookie or $nph;
    push @headers, 'Pragma', 'no-cache' if $query->cache;

    if ( my $fn = delete $header{-attachment} ) {
        push @headers, 'Content-Disposition', qq{attachment; filename="$fn"};
    }

    push @headers, map { _ucfirst($_), $header{$_} } keys %header;

    if ( !defined $type or $type ne q{} ) {
        $charset = $query->charset unless defined $charset;
        my $ct = $type || 'text/html';
        $ct .= "; charset=$charset" if $charset && $ct !~ /\bcharset\b/;
        push @headers, 'Content-Type', $ct;
    }

    @headers;
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

sub _ucfirst {
    my $str = shift;
    $str =~ s/^-(\w)/\u$1/;
    $str =~ tr/_/-/;
    $str;
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
  $props->header_get('-type'); # => "text/plain"
  $props->header_exists('-type'); # => true

  # update $header 
  $props->header_set( -type => 'text/plain' ); # overwrite
  $props->header_delete('-type'); # => "text/plain"
  $props->header_clear; # => $self

  $props->handler('redirect'); # or $props->header_type('redirect')
  $props->as_string; # invokes $query->redirect

  my @headers = $props->flatten; # => ( "Content-Type", "text/html", ... )

  # works like CGI::Application#header_props
  my @header_props = $props->header_props;
  $props->header_props( -type => 'text/plain', ... );

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

=head1 METHODS

=over 4

=item new

=item header 

=item handler

=item query

=item header_rehash

=item header_props

=item $value = $props->header_get( $prop )

=item $value = $props->header_set( $prop => $value )

Get or set the value of the header property.
The property name (C<$prop>) is not case sensitive.
You can use dashes as a replacement for underscores in property names.

  $props->header_get('-content_length');
  $props->header_get('Content-Length');

The C<$value> argument may be a plain string or a reference to an array
of L<CGI::Cookie> objects for the C<-cookie> property:

  $props->header_set( 'Content-Length' => 3002 );
  my $length = $props->header_get('Content-Length'); # => 3002

  # $cookie1 and $cookie2 are CGI::Cookie objects
  $props->header_set( -cookie => [$cookie1, $cookie2] );
  my $cookies = $props->header_get('-cookie'); # => [$cookie1, $cookie2]

=item $value = $props->header_delete( $prop )

Deletes the specified property. Returns the value of the deleted property.

  my $value = $props->header_delete('-content_disposition'); # => "inline"

=item $bool = $props->header_exists( $prop )

Returns a Boolean value telling whether the specified property exists.

  if ( $props->header_exists('-etag') ) {
      ...
  }

=item $self = $props->header_clear

This will remove all header properties. It's identical to:

  $props->header_props({});

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

=item nph

If set to a true value, will issue the correct headers to work with
a NPH (no-parse-header) script.

=item push_cookie

=item as_string

=item flatten

Returns pairs of fields and values.

=back

=head1 SEE ALSO

L<CGI::Application>, L<CGI>

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
