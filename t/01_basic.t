use strict;
use CGI;
use CGI::Header::Props;
use Test::Exception;
use Test::More tests => 33;

my $h = CGI::Header::Props->new(
    query => CGI->new,
    handler => 'header',
    header => {
        -type => 'text/plain',
        -charset => 'utf-8',
    },
);

isa_ok $h, 'CGI::Header::Props';

# class methods
can_ok $h, qw( new normalize_property_name );

# attributes
can_ok $h, qw( header query _build_query handler );

# properties
can_ok $h, qw( p3p nph expires attachment );

# operators
can_ok $h, qw( header_get header_set header_delete header_exists );

# etc.
can_ok $h, qw( flatten as_string header_rehash );

isa_ok $h->query, 'CGI';
isa_ok $h->header, 'HASH';
is $h->handler, 'header';

my @data = (
    '-foo'           => '-foo',
    'Foo'            => '-foo',
    '-foo_bar'       => '-foo_bar',
    'Foo-Bar'        => '-foo_bar',
    '-cookies'       => '-cookie',
    '-set_cookie'    => '-cookie',
    '-window_target' => '-target',
    '-content_type'  => '-type',
);

while ( my ($input, $expected) = splice @data, 0, 2 ) {
    is $h->normalize_property_name($input), $expected;
}

$h->handler('redirect');
is $h->handler, 'redirect';

throws_ok { $h->handler('param') } qr{Invalid handler};

%{ $h->header } = (
    '-Charset'      => 'utf-8',
    '-content_type' => 'text/plain',
    'Set-Cookie'    => 'ID=123456; path=/',
    '-expires'      => '+3d',
    'foo'           => 'bar',
    'foo-bar'       => 'baz',
    'window_target' => 'ResultsWindow',
);

is_deeply $h->header_rehash->header, {
    -type    => 'text/plain',
    -charset => 'utf-8',
    -cookie  => 'ID=123456; path=/',
    -expires => '+3d',
    -foo     => 'bar',
    -foo_bar => 'baz',
    -target  => 'ResultsWindow',
};

is $h->header_set( -foo => 'bar' ), 'bar';
is $h->header_get('-foo'), 'bar';
ok $h->header_exists('-foo');
is $h->header_delete('-foo'), 'bar';

$h->header_props( -type => 'text/plain', -charset => 'utf-8' );
is_deeply +{$h->header_props}, { -type => 'text/plain', -charset => 'utf-8' };

$h->header_props({});
is_deeply $h->header, {};

throws_ok { $h->header_props('-type') } qr{Odd number of elements};

$h->header_clear->handler('header');

is $h->as_string,
    "Content-Type: text/html; charset=ISO-8859-1$CGI::CRLF$CGI::CRLF";

is_deeply [ $h->flatten ],
    [ 'Content-Type', 'text/html; charset=ISO-8859-1' ];

$h->p3p(qw/CAO DSP LAW CURa/);
is_deeply [$h->p3p], [qw/CAO DSP LAW CURa/];

$h->nph(1);
ok $h->nph;

$h->expires('+3d');
is $h->expires, '+3d';

$h->attachment('genome.jpg');
is $h->attachment, 'genome.jpg';
