use strict;
use warnings;
use Benchmark 'cmpthese';
use CGI::Header::Props;

# Purpose: To prove CGI::Header::Props#normalize costs expensive

cmpthese(-1, {
    set => sub {
        my $props = CGI::Header::Props->new;
        $props->set( type => 'text/plain' );
        $props->set( charset => 'utf-8' );
    },
    chained => sub {
        my $props = CGI::Header::Props->new;
        $props->type('text/plain')->charset('utf-8');
    },
});

