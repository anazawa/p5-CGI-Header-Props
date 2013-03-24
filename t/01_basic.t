use strict;
use CGI;
use CGI::Header::Props;
use Test::Exception;
use Test::More tests => 36;

my $props = CGI::Header::Props->new(
    query => CGI->new,
    handler => 'header',
    header => {
        -type => 'text/plain',
        -charset => 'utf-8',
    },
);

isa_ok $props, 'CGI::Header::Props';

# class methods
can_ok $props, qw( new normalize );

# attributes
can_ok $props, qw( header query _build_query handler );

# properties
can_ok $props, qw( p3p nph expires attachment );

# operators
can_ok $props, qw( get set delete exists );

# etc.
can_ok $props, qw( as_string rehash );

isa_ok $props->query, 'CGI';
isa_ok $props->header, 'HASH';
is $props->handler, 'header';

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
    is $props->normalize($input), $expected;
}

$props->handler('redirect');
is $props->handler, 'redirect';

throws_ok { $props->handler('param') } qr{Invalid handler};

%{ $props->header } = (
    '-Charset'      => 'utf-8',
    '-content_type' => 'text/plain',
    'Set-Cookie'    => 'ID=123456; path=/',
    '-expires'      => '+3d',
    'foo'           => 'bar',
    'foo-bar'       => 'baz',
    'window_target' => 'ResultsWindow',
);
is_deeply $props->rehash->header, {
    -type    => 'text/plain',
    -charset => 'utf-8',
    -cookie  => 'ID=123456; path=/',
    -expires => '+3d',
    -foo     => 'bar',
    -foo_bar => 'baz',
    -target  => 'ResultsWindow',
};

$props->set( -foo => 'bar' );
is $props->get('-foo'), 'bar';
ok $props->exists('-foo');
is $props->delete('-foo'), 'bar';

$props->p3p(qw/CAO DSP LAW CURa/);
is_deeply [$props->p3p], [qw/CAO DSP LAW CURa/];

$props->clear;

$props->handler('header');
is $props->as_string,
    "Content-Type: text/html; charset=ISO-8859-1$CGI::CRLF$CGI::CRLF";

$props->handler('redirect');
is $props->as_string,
    "Status: 302 Found$CGI::CRLF" .
    "Location: http://localhost$CGI::CRLF$CGI::CRLF";

$props->nph(1);
ok $props->nph;

$props->expires('+3d');
is $props->expires, '+3d';

$props->attachment('genome.jpg');
is $props->attachment, 'genome.jpg';

is $props->push_cookie(qw/foo/), 1;
is $props->header->{-cookie}, 'foo';
is $props->push_cookie(qw/bar baz/), 3;
is_deeply $props->header->{-cookie}, [qw/foo bar baz/];

$props->delete('-charset');
is $props->charset, 'ISO-8859-1';

$props->set( -charset => 'utf-8' );
is $props->charset, 'utf-8';

$props->set( -charset => q{} );
is $props->charset, q{};
