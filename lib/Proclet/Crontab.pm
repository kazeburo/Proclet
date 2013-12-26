package Proclet::Crontab;

use strict;
use warnings;
use Carp qw/croak/;
use List::MoreUtils qw/all any uniq/;
use Set::Crontab;

my @keys = qw/minute hour day month day_of_week/;
my @ranges = (
    [0..59], #minute
    [0..23], #hour
    [1..31], #day
    [1..12], #month
    [0..7], #day of week
);

sub includes {
    my ($list,$include) = @_;
    my %include = map {
        $_ => 1
    } @$include;
    all { exists $include{$_} } @$list;
}

sub new {
    my ($class,$str) = @_;
    my $self = bless {}, $class;
    $self->_compile($str);
    $self;
}

sub _compile {
    my ($self, $str) = @_;

    $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;
    my @rules = split /\s+/, $str;
    croak 'incorrect cron field:'.$str if @rules != 5;
    my %rules;
    my $i=0;
    for my $rule ( @rules ) {
        my $key = $keys[$i];
        my $range = $ranges[$i];
        my $set_crontab = Set::Crontab->new($rule, $range);
        my @expand = $set_crontab->list();
        croak "bad format $key: $rule" unless @expand;
        croak "bad range $key: $rule" unless includes(\@expand, $range);
        if ( $i == 4 ) {
            #day of week
            if ( any { $_ == 7 } @expand ) {
                unshift @expand, 0;
            }
            @expand = uniq @expand;
        }
        $rules{$key} = \@expand;
        $i++;
    }

    $self->{rules} = \%rules;
}

sub _contains {
    my ($self, $key, $num) = @_;
    any { $_ == $num  } @{$self->{rules}->{$key}};
}

sub match {
    my ($self, $unixtime) = @_;
    my @lt = localtime($unixtime);
    if ( $self->_contains('minute', $lt[1]) 
      && $self->_contains('hour', $lt[2])
      && ( $self->_contains('day', $lt[3]) || $self->_contains('day_of_week', $lt[6]) )
      && $self->_contains('month', $lt[4]+1) ) {
        return 1;
    }
    return;
}

1;


