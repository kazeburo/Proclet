requires 'Data::Validator';
requires 'File::Which', '1.09';
requires 'Getopt::Compact::WithCmd', '0.20';
requires 'Log::Minimal', '0.14';
requires 'Mouse';
requires 'Parallel::Prefork', '0.13';
requires 'Term::ANSIColor';
requires 'YAML::XS', '0.38';
requires 'parent';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.36';
    requires 'List::MoreUtils';
    requires 'Parallel::Scoreboard';
    requires 'Test::More';
};
