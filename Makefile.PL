use inc::Module::Install;

all_from 'lib/CGI/Header/Props.pm';
readme_from 'lib/CGI/Header/Props.pm';

repository 'https://github.com/anazawa/p5-CGI-Header-Props';

requires 'Carp' => '1.10';

test_requires 'CGI::Application';
test_requires 'Test::Exception' => '0.31';
test_requires 'Test::More' => '0.98';

tests 't/*.t xt/*.t';

WriteAll;
