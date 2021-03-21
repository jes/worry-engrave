package WorryEngrave::GCode;

use strict;
use warnings;

use List::Util qw(min max);

sub process {
    my ($pkg, $gcode, $cb) = @_;

    my @lines = split /\n/, $gcode;

    for my $l (@lines) {
        $cb->($l);
    }
}

sub bounds {
    my ($pkg, $gcode) = @_;

    my %min;
    my %max;

    $pkg->process($gcode, sub {
        my ($l) = @_;

        while ($l =~ /([XYZ])\s*([-.0-9]+)/g) {
            my ($letter, $value) = ($1, $2);
            $min{$letter} //= $value;
            $max{$letter} //= $value;
            $min{$letter} = min($min{$letter}, $value);
            $max{$letter} = max($max{$letter}, $value);
        };
    });

    return ($min{X}, $min{Y}, $min{Z}, $max{X}, $max{Y}, $max{Z});
}

sub offset {
    my ($pkg, $gcode, $offx, $offy) = @_;

    my $newgcode = '';

    $pkg->process($gcode, sub {
        my ($l) = @_;

        my $newl = $l;

        while ($l =~ /([XY])\s*([-.0-9]+)/g) {
            my ($letter, $value) = ($1, $2);
            my $newvalue = $value;
            $newvalue += $offx if $letter eq 'X';
            $newvalue += $offy if $letter eq 'Y';
            $newl =~ s/$letter\s*$value/$letter$newvalue/;
        };

        $newgcode .= "$newl\n";
    });

    return $newgcode;
}

sub scale {
    my ($pkg, $gcode, $scale, $px, $py) = @_;

    my $newgcode = '';

    $pkg->process($gcode, sub {
        my ($l) = @_;

        my $newl = $l;

        while ($l =~ /([XY])\s*([-.0-9]+)/g) {
            my ($letter, $value) = ($1, $2);
            my $newvalue = $value;
            $newvalue = sprintf("%.3f", $px + ($newvalue - $px) * $scale) if $letter eq 'X';
            $newvalue = sprintf("%.3f", $py + ($newvalue - $py) * $scale) if $letter eq 'Y';
            $newl =~ s/$letter\s*$value/$letter$newvalue/;
        };

        $newgcode .= "$newl\n";
    });

    return $newgcode;
}

1;
