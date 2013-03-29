use strict;
use CGI;
use CGI::Header::Props;
use Test::Exception;
use Test::More tests => 65;

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
can_ok $props,
    qw( p3p nph expires attachment cookie type status location target );

# operators
can_ok $props, qw( get set delete exists push_cookie push_p3p );

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

is $props->set( foo => 'bar' ), 'bar';
is $props->get('foo'), 'bar';
ok $props->exists('foo');
is $props->delete('foo'), 'bar';

$props->clear->set( uri => 'http://www.example.com/' );
is $props->handler('redirect'), $props;
is $props->handler, 'redirect';
is_deeply $props->header,
    { -location => 'http://www.example.com/' }, 'should be rehashed';

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

is $props->clear->handler('header')->as_string,
    "Content-Type: text/html; charset=ISO-8859-1$CGI::CRLF$CGI::CRLF";

is $props->clear->handler('redirect')->as_string,
    "Status: 302 Found$CGI::CRLF" .
    "Location: http://localhost$CGI::CRLF$CGI::CRLF";


# nph

is $props->nph(1), $props;
ok $props->nph;

{
    local $CGI::NPH = 1;
    $props->delete('nph');
    ok $props->nph;
    throws_ok { $props->nph(0) } qr{'-nph' pragma is enabled};
}


# attachment

$props->set( content_disposition => 'inline' );
is $props->attachment('genome.jpg'), $props;
is $props->attachment, 'genome.jpg';
ok !$props->exists('content_disposition'),
    '-content_disposition should be deleted';


# expires

$props->set( date => 'Thu, 25 Apr 1999 00:40:33 GMT' );
is $props->expires('+3d'), $props;
is $props->expires, '+3d';
ok !$props->exists('date'), '-date should be deleted';


# p3p

is $props->p3p(qw/CAO DSP LAW CURa/), $props;
is_deeply [ $props->p3p ], [qw/CAO DSP LAW CURa/];

is $props->p3p('CAO DSP LAW CURa'), $props;
is_deeply [ $props->p3p ], [qw/CAO DSP LAW CURa/];


# cookie

$props->set( date => 'Thu, 25 Apr 1999 00:40:33 GMT' );
is $props->cookie('foo'), $props;
is $props->cookie, 'foo';
ok !$props->exists('date'), '-date should be deleted';

is $props->cookie(qw/foo bar baz/), $props;
is_deeply [ $props->cookie ], [qw/foo bar baz/];

$props->delete('cookie');
is $props->push_cookie('foo'), 1;
is $props->cookie, 'foo';
is $props->push_cookie(qw/bar baz/), 3;
is_deeply [ $props->cookie ], [qw/foo bar baz/];


# charset

is $props->charset(undef), $props;
is $props->charset, 'ISO-8859-1';

is $props->charset('utf-8'), $props;
is $props->charset, 'utf-8';

is $props->charset(q{}), $props;
is $props->charset, q{};


# type

is $props->type('text/plain'), $props;
is $props->type, 'text/plain';


# location

is $props->location('http://www.example.com/'), $props;
is $props->location, 'http://www.example.com/';


# target

is $props->target('ResultsWindow'), $props;
is $props->target, 'ResultsWindow';


# status

is $props->status('304 Not Modified'), $props;
is $props->status, '304 Not Modified';

