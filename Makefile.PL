use inc::Module::Install;
name 'Proclet';
all_from 'lib/Proclet.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
#auto_include;
WriteAll;
