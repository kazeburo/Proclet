use inc::Module::Install;
name 'Proclet';
all_from 'lib/Proclet.pm';

requires 'Parallel::Prefork', 0.13;
requires 'Data::Validator';
requires 'Mouse';
requires 'Log::Minimal';
requires 'Term::ANSIColor';
requires 'Getopt::Compact::WithCmd', 0.20;
requires 'YAML::XS', 0.38;
requires 'parent';

tests 't/*.t t/*/*.t';
author_tests 'xt';

test_requires 'Test::More';
test_requires 'Parallel::Scoreboard';

install_script 'bin/proclet';
auto_set_repository;
WriteAll;
