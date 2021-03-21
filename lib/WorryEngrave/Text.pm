package WorryEngrave::Text;

use strict;
use warnings;

use WorryEngrave::GCode;

# this function is based on "draw_svg_text" from hershey.py
sub char {
    my ($pkg, $charint, $xoffset, %opts) = @_;

    my $hspeed = $opts{hspeed} // 40;
    my $vspeed = $opts{vspeed} // 40;
    my $rapidspeed = $opts{rapidspeed} // 1000;
    my $cutheight = $opts{cutheight} // -0.2;
    my $rapidheight = $opts{rapidheight} // 1;

    my $f = $pkg->fontdata();
    my $pathstring = $f->[$charint];
    my @splitstring = split / /, $pathstring;

    my $xmid = $splitstring[0];
    my $xwidth = $splitstring[1];
    $xoffset -= $xmid;

    my $gcode = '';

    while ($pathstring =~ /(M|L) ([-0-9]+) ([-0-9]+)/g) {
        my ($cmd, $x, $y) = ($1, $2, $3);

        $x += $xoffset;
        $y = -$y;

        if ($cmd eq 'M') {
            $gcode .= "G1 Z$rapidheight F$rapidspeed\n";
            $gcode .= "G0 X$x Y$y F$rapidspeed\n";
        } else {
            $gcode .= "G1 Z$cutheight F$vspeed\n";
            $gcode .= "G1 X$x Y$y F$hspeed\n";
        }
    }

    return ($gcode, $xoffset+$xwidth);
}

# this function is based on "Hershey.effect()" from hershey.py
sub mkgcode {
    my ($pkg, $text, %opts) = @_;

    my $nconstr = 0;
    for (qw(width height diameter)) {
        $nconstr++ if defined $opts{$_};
    }
    die "can only choose width, height, *or* diameter" if $nconstr > 1;

    my $rpm = $opts{rpm} // 24000;

    my $gcode = "G21 G90\n";
    $gcode .= "M3 S$rpm\n";

    my $x = 0;

    for my $c (split //, $text) {
        my $charint = ord($c) - 32;
        if ($charint < 0 || $charint > 95) {
            $x += 6; # ???
        } else {
            my ($newgcode, $newx) = $pkg->char($charint, $x, %opts);
            $gcode .= $newgcode;
            $x = $newx;
        }
    }

    $gcode .= "M5\n";
    $gcode .= "M2\n";

    # scaling
    if (defined $opts{width} || defined $opts{height} || defined $opts{diameter}) {
        my ($minx,$miny,$minz,$maxx,$maxy,$maxz) = WorryEngrave::GCode->bounds($gcode);

        my $width = $maxx-$minx;
        my $height = $maxy-$miny;

        my $scale = 1.0;
        if (defined $opts{width}) {
            $scale = $opts{width} / $width;
        } elsif (defined $opts{height}) {
            $scale = $opts{height} / $height;
        } elsif (defined $opts{diameter}) {
            # scale the text so that it fits in a rectangle that
            # touches a circle of the given diameter at all 4 corners

            # start out by working out what size circle it currently fits in
            my $halfw = $width/2;
            my $halfh = $height/2;
            my $cur_diameter = 2*sqrt($halfw*$halfw + $halfh*$halfh);

            # and scale down to match the desired circle
            $scale = $opts{diameter} / $cur_diameter;
        }
        $gcode = WorryEngrave::GCode->scale($gcode, $scale, $minx, $miny);
    }

    # centering
    if (defined $opts{centrex} || defined $opts{centrey}) {
        my ($minx,$miny,$minz,$maxx,$maxy,$maxz) = WorryEngrave::GCode->bounds($gcode);

        # centering
        my $midx = ($minx+$maxx)/2;
        my $midy = ($miny+$maxy)/2;
        $opts{centrex} //= $midx;
        $opts{centrey} //= $midy;
        $gcode = WorryEngrave::GCode->offset($gcode, $opts{centrex}-$midx, $opts{centrey}-$midy);
    }

    my ($minx,$miny,$minz,$maxx,$maxy,$maxz) = WorryEngrave::GCode->bounds($gcode);

        my $width = $maxx-$minx;
        my $height = $maxy-$miny;

    return $gcode;
}

# this is the "futural" aka "Sans 1-stroke" font from the "Hershey Text" Inkscape
# plugin, which came with the following notice:
#
## This file prepared in 2011 by Windell H. Oskay, www.evilmadscientist.com
##
##
## Contents adapted from emergent.unpythonic.net/software/hershey
##  by way of http://www.thingiverse.com/thing:6168 
##
##The Hershey Fonts are a set of vector fonts with a liberal license. 
##
##USE RESTRICTION:
##	This distribution of the Hershey Fonts may be used by anyone for
##	any purpose, commercial or otherwise, providing that:
##		1. The following acknowledgements must be distributed with
##			the font data:
##			- The Hershey Fonts were originally created by Dr.
##				A. V. Hershey while working at the U. S.
##				National Bureau of Standards.
##			- The format of the Font data in this distribution
##				was originally created by
##					James Hurt
##					Cognition, Inc.
##					900 Technology Park Drive
##					Billerica, MA 01821
##					(mit-eddie!ci-dandelion!hurt)
##		2. The font data in this distribution may be converted into
##			any other format *EXCEPT* the format distributed by
##			the U.S. NTIS (which organization holds the rights
##			to the distribution and use of the font data in that
##			particular format). Not that anybody would really
##			*want* to use their format... each point is described
##			in eight bytes as "xxx yyy:", where xxx and yyy are
##			the coordinate values as ASCII numbers.
#
# It is a list of SVG paths, one for each ASCII code from 32 to 127; the first
# 2 numbers specify the X midpoint and width, I think? the rest is an SVG path;
# "M x y" means to pick the tool up and move to (x,y); "L x y" means to put the
# tool down and draw a line from the current position to (x,y)
sub fontdata {
    return [
        "-8 8",
        "-5 5 M 0 -12 L 0 2 M 0 7 L -1 8 L 0 9 L 1 8 L 0 7",
        "-8 8 M -4 -12 L -4 -5 M 4 -12 L 4 -5",
        "-10 11 M 1 -16 L -6 16 M 7 -16 L 0 16 M -6 -3 L 8 -3 M -7 3 L 7 3",
        "-10 10 M -2 -16 L -2 13 M 2 -16 L 2 13 M 7 -9 L 5 -11 L 2 -12 L -2 -12 L -5 -11 L -7 -9 L -7 -7 L -6 -5 L -5 -4 L -3 -3 L 3 -1 L 5 0 L 6 1 L 7 3 L 7 6 L 5 8 L 2 9 L -2 9 L -5 8 L -7 6",
        "-12 12 M 9 -12 L -9 9 M -4 -12 L -2 -10 L -2 -8 L -3 -6 L -5 -5 L -7 -5 L -9 -7 L -9 -9 L -8 -11 L -6 -12 L -4 -12 L -2 -11 L 1 -10 L 4 -10 L 7 -11 L 9 -12 M 5 2 L 3 3 L 2 5 L 2 7 L 4 9 L 6 9 L 8 8 L 9 6 L 9 4 L 7 2 L 5 2",
        "-13 13 M 10 -3 L 10 -4 L 9 -5 L 8 -5 L 7 -4 L 6 -2 L 4 3 L 2 6 L 0 8 L -2 9 L -6 9 L -8 8 L -9 7 L -10 5 L -10 3 L -9 1 L -8 0 L -1 -4 L 0 -5 L 1 -7 L 1 -9 L 0 -11 L -2 -12 L -4 -11 L -5 -9 L -5 -7 L -4 -4 L -2 -1 L 3 6 L 5 8 L 7 9 L 9 9 L 10 8 L 10 7",
        "-5 5 M 0 -10 L -1 -11 L 0 -12 L 1 -11 L 1 -9 L 0 -7 L -1 -6",
        "-7 7 M 4 -16 L 2 -14 L 0 -11 L -2 -7 L -3 -2 L -3 2 L -2 7 L 0 11 L 2 14 L 4 16",
        "-7 7 M -4 -16 L -2 -14 L 0 -11 L 2 -7 L 3 -2 L 3 2 L 2 7 L 0 11 L -2 14 L -4 16",
        "-8 8 M 0 -6 L 0 6 M -5 -3 L 5 3 M 5 -3 L -5 3",
        "-13 13 M 0 -9 L 0 9 M -9 0 L 9 0",
        "-4 4 M 1 5 L 0 6 L -1 5 L 0 4 L 1 5 L 1 7 L -1 9",
        "-13 13 M -9 0 L 9 0",
        "-4 4 M 0 4 L -1 5 L 0 6 L 1 5 L 0 4",
        "-11 11 M 9 -16 L -9 16",
        "-10 10 M -1 -12 L -4 -11 L -6 -8 L -7 -3 L -7 0 L -6 5 L -4 8 L -1 9 L 1 9 L 4 8 L 6 5 L 7 0 L 7 -3 L 6 -8 L 4 -11 L 1 -12 L -1 -12",
        "-10 10 M -4 -8 L -2 -9 L 1 -12 L 1 9",
        "-10 10 M -6 -7 L -6 -8 L -5 -10 L -4 -11 L -2 -12 L 2 -12 L 4 -11 L 5 -10 L 6 -8 L 6 -6 L 5 -4 L 3 -1 L -7 9 L 7 9",
        "-10 10 M -5 -12 L 6 -12 L 0 -4 L 3 -4 L 5 -3 L 6 -2 L 7 1 L 7 3 L 6 6 L 4 8 L 1 9 L -2 9 L -5 8 L -6 7 L -7 5",
        "-10 10 M 3 -12 L -7 2 L 8 2 M 3 -12 L 3 9",
        "-10 10 M 5 -12 L -5 -12 L -6 -3 L -5 -4 L -2 -5 L 1 -5 L 4 -4 L 6 -2 L 7 1 L 7 3 L 6 6 L 4 8 L 1 9 L -2 9 L -5 8 L -6 7 L -7 5",
        "-10 10 M 6 -9 L 5 -11 L 2 -12 L 0 -12 L -3 -11 L -5 -8 L -6 -3 L -6 2 L -5 6 L -3 8 L 0 9 L 1 9 L 4 8 L 6 6 L 7 3 L 7 2 L 6 -1 L 4 -3 L 1 -4 L 0 -4 L -3 -3 L -5 -1 L -6 2",
        "-10 10 M 7 -12 L -3 9 M -7 -12 L 7 -12",
        "-10 10 M -2 -12 L -5 -11 L -6 -9 L -6 -7 L -5 -5 L -3 -4 L 1 -3 L 4 -2 L 6 0 L 7 2 L 7 5 L 6 7 L 5 8 L 2 9 L -2 9 L -5 8 L -6 7 L -7 5 L -7 2 L -6 0 L -4 -2 L -1 -3 L 3 -4 L 5 -5 L 6 -7 L 6 -9 L 5 -11 L 2 -12 L -2 -12",
        "-10 10 M 6 -5 L 5 -2 L 3 0 L 0 1 L -1 1 L -4 0 L -6 -2 L -7 -5 L -7 -6 L -6 -9 L -4 -11 L -1 -12 L 0 -12 L 3 -11 L 5 -9 L 6 -5 L 6 0 L 5 5 L 3 8 L 0 9 L -2 9 L -5 8 L -6 6",
        "-4 4 M 0 -3 L -1 -2 L 0 -1 L 1 -2 L 0 -3 M 0 4 L -1 5 L 0 6 L 1 5 L 0 4",
        "-4 4 M 0 -3 L -1 -2 L 0 -1 L 1 -2 L 0 -3 M 1 5 L 0 6 L -1 5 L 0 4 L 1 5 L 1 7 L -1 9",
        "-12 12 M 8 -9 L -8 0 L 8 9",
        "-13 13 M -9 -3 L 9 -3 M -9 3 L 9 3",
        "-12 12 M -8 -9 L 8 0 L -8 9",
        "-9 9 M -6 -7 L -6 -8 L -5 -10 L -4 -11 L -2 -12 L 2 -12 L 4 -11 L 5 -10 L 6 -8 L 6 -6 L 5 -4 L 4 -3 L 0 -1 L 0 2 M 0 7 L -1 8 L 0 9 L 1 8 L 0 7",
        "-13 14 M 5 -4 L 4 -6 L 2 -7 L -1 -7 L -3 -6 L -4 -5 L -5 -2 L -5 1 L -4 3 L -2 4 L 1 4 L 3 3 L 4 1 M -1 -7 L -3 -5 L -4 -2 L -4 1 L -3 3 L -2 4 M 5 -7 L 4 1 L 4 3 L 6 4 L 8 4 L 10 2 L 11 -1 L 11 -3 L 10 -6 L 9 -8 L 7 -10 L 5 -11 L 2 -12 L -1 -12 L -4 -11 L -6 -10 L -8 -8 L -9 -6 L -10 -3 L -10 0 L -9 3 L -8 5 L -6 7 L -4 8 L -1 9 L 2 9 L 5 8 L 7 7 L 8 6 M 6 -7 L 5 1 L 5 3 L 6 4",
        "-9 9 M 0 -12 L -8 9 M 0 -12 L 8 9 M -5 2 L 5 2",
        "-11 10 M -7 -12 L -7 9 M -7 -12 L 2 -12 L 5 -11 L 6 -10 L 7 -8 L 7 -6 L 6 -4 L 5 -3 L 2 -2 M -7 -2 L 2 -2 L 5 -1 L 6 0 L 7 2 L 7 5 L 6 7 L 5 8 L 2 9 L -7 9",
        "-10 11 M 8 -7 L 7 -9 L 5 -11 L 3 -12 L -1 -12 L -3 -11 L -5 -9 L -6 -7 L -7 -4 L -7 1 L -6 4 L -5 6 L -3 8 L -1 9 L 3 9 L 5 8 L 7 6 L 8 4",
        "-11 10 M -7 -12 L -7 9 M -7 -12 L 0 -12 L 3 -11 L 5 -9 L 6 -7 L 7 -4 L 7 1 L 6 4 L 5 6 L 3 8 L 0 9 L -7 9",
        "-10 9 M -6 -12 L -6 9 M -6 -12 L 7 -12 M -6 -2 L 2 -2 M -6 9 L 7 9",
        "-10 8 M -6 -12 L -6 9 M -6 -12 L 7 -12 M -6 -2 L 2 -2",
        "-10 11 M 8 -7 L 7 -9 L 5 -11 L 3 -12 L -1 -12 L -3 -11 L -5 -9 L -6 -7 L -7 -4 L -7 1 L -6 4 L -5 6 L -3 8 L -1 9 L 3 9 L 5 8 L 7 6 L 8 4 L 8 1 M 3 1 L 8 1",
        "-11 11 M -7 -12 L -7 9 M 7 -12 L 7 9 M -7 -2 L 7 -2",
        "-4 4 M 0 -12 L 0 9",
        "-8 8 M 4 -12 L 4 4 L 3 7 L 2 8 L 0 9 L -2 9 L -4 8 L -5 7 L -6 4 L -6 2",
        "-11 10 M -7 -12 L -7 9 M 7 -12 L -7 2 M -2 -3 L 7 9",
        "-10 7 M -6 -12 L -6 9 M -6 9 L 6 9",
        "-12 12 M -8 -12 L -8 9 M -8 -12 L 0 9 M 8 -12 L 0 9 M 8 -12 L 8 9",
        "-11 11 M -7 -12 L -7 9 M -7 -12 L 7 9 M 7 -12 L 7 9",
        "-11 11 M -2 -12 L -4 -11 L -6 -9 L -7 -7 L -8 -4 L -8 1 L -7 4 L -6 6 L -4 8 L -2 9 L 2 9 L 4 8 L 6 6 L 7 4 L 8 1 L 8 -4 L 7 -7 L 6 -9 L 4 -11 L 2 -12 L -2 -12",
        "-11 10 M -7 -12 L -7 9 M -7 -12 L 2 -12 L 5 -11 L 6 -10 L 7 -8 L 7 -5 L 6 -3 L 5 -2 L 2 -1 L -7 -1",
        "-11 11 M -2 -12 L -4 -11 L -6 -9 L -7 -7 L -8 -4 L -8 1 L -7 4 L -6 6 L -4 8 L -2 9 L 2 9 L 4 8 L 6 6 L 7 4 L 8 1 L 8 -4 L 7 -7 L 6 -9 L 4 -11 L 2 -12 L -2 -12 M 1 5 L 7 11",
        "-11 10 M -7 -12 L -7 9 M -7 -12 L 2 -12 L 5 -11 L 6 -10 L 7 -8 L 7 -6 L 6 -4 L 5 -3 L 2 -2 L -7 -2 M 0 -2 L 7 9",
        "-10 10 M 7 -9 L 5 -11 L 2 -12 L -2 -12 L -5 -11 L -7 -9 L -7 -7 L -6 -5 L -5 -4 L -3 -3 L 3 -1 L 5 0 L 6 1 L 7 3 L 7 6 L 5 8 L 2 9 L -2 9 L -5 8 L -7 6",
        "-8 8 M 0 -12 L 0 9 M -7 -12 L 7 -12",
        "-11 11 M -7 -12 L -7 3 L -6 6 L -4 8 L -1 9 L 1 9 L 4 8 L 6 6 L 7 3 L 7 -12",
        "-9 9 M -8 -12 L 0 9 M 8 -12 L 0 9",
        "-12 12 M -10 -12 L -5 9 M 0 -12 L -5 9 M 0 -12 L 5 9 M 10 -12 L 5 9",
        "-10 10 M -7 -12 L 7 9 M 7 -12 L -7 9",
        "-9 9 M -8 -12 L 0 -2 L 0 9 M 8 -12 L 0 -2",
        "-10 10 M 7 -12 L -7 9 M -7 -12 L 7 -12 M -7 9 L 7 9",
        "-7 7 M -3 -16 L -3 16 M -2 -16 L -2 16 M -3 -16 L 4 -16 M -3 16 L 4 16",
        "-7 7 M -7 -12 L 7 12",
        "-7 7 M 2 -16 L 2 16 M 3 -16 L 3 16 M -4 -16 L 3 -16 M -4 16 L 3 16",
        "-8 8 M 0 -14 L -8 0 M 0 -14 L 8 0",
        "-9 9 M -9 16 L 9 16",
        "-4 4 M 1 -7 L -1 -5 L -1 -3 L 0 -2 L 1 -3 L 0 -4 L -1 -3",
        "-9 10 M 6 -5 L 6 9 M 6 -2 L 4 -4 L 2 -5 L -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6",
        "-10 9 M -6 -12 L -6 9 M -6 -2 L -4 -4 L -2 -5 L 1 -5 L 3 -4 L 5 -2 L 6 1 L 6 3 L 5 6 L 3 8 L 1 9 L -2 9 L -4 8 L -6 6",
        "-9 9 M 6 -2 L 4 -4 L 2 -5 L -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6",
        "-9 10 M 6 -12 L 6 9 M 6 -2 L 4 -4 L 2 -5 L -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6",
        "-9 9 M -6 1 L 6 1 L 6 -1 L 5 -3 L 4 -4 L 2 -5 L -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6",
        "-5 7 M 5 -12 L 3 -12 L 1 -11 L 0 -8 L 0 9 M -3 -5 L 4 -5",
        "-9 10 M 6 -5 L 6 11 L 5 14 L 4 15 L 2 16 L -1 16 L -3 15 M 6 -2 L 4 -4 L 2 -5 L -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6",
        "-9 10 M -5 -12 L -5 9 M -5 -1 L -2 -4 L 0 -5 L 3 -5 L 5 -4 L 6 -1 L 6 9",
        "-4 4 M -1 -12 L 0 -11 L 1 -12 L 0 -13 L -1 -12 M 0 -5 L 0 9",
        "-5 5 M 0 -12 L 1 -11 L 2 -12 L 1 -13 L 0 -12 M 1 -5 L 1 12 L 0 15 L -2 16 L -4 16",
        "-9 8 M -5 -12 L -5 9 M 5 -5 L -5 5 M -1 1 L 6 9",
        "-4 4 M 0 -12 L 0 9",
        "-15 15 M -11 -5 L -11 9 M -11 -1 L -8 -4 L -6 -5 L -3 -5 L -1 -4 L 0 -1 L 0 9 M 0 -1 L 3 -4 L 5 -5 L 8 -5 L 10 -4 L 11 -1 L 11 9",
        "-9 10 M -5 -5 L -5 9 M -5 -1 L -2 -4 L 0 -5 L 3 -5 L 5 -4 L 6 -1 L 6 9",
        "-9 10 M -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6 L 7 3 L 7 1 L 6 -2 L 4 -4 L 2 -5 L -1 -5",
        "-10 9 M -6 -5 L -6 16 M -6 -2 L -4 -4 L -2 -5 L 1 -5 L 3 -4 L 5 -2 L 6 1 L 6 3 L 5 6 L 3 8 L 1 9 L -2 9 L -4 8 L -6 6",
        "-9 10 M 6 -5 L 6 16 M 6 -2 L 4 -4 L 2 -5 L -1 -5 L -3 -4 L -5 -2 L -6 1 L -6 3 L -5 6 L -3 8 L -1 9 L 2 9 L 4 8 L 6 6",
        "-7 6 M -3 -5 L -3 9 M -3 1 L -2 -2 L 0 -4 L 2 -5 L 5 -5",
        "-8 9 M 6 -2 L 5 -4 L 2 -5 L -1 -5 L -4 -4 L -5 -2 L -4 0 L -2 1 L 3 2 L 5 3 L 6 5 L 6 6 L 5 8 L 2 9 L -1 9 L -4 8 L -5 6",
        "-5 7 M 0 -12 L 0 5 L 1 8 L 3 9 L 5 9 M -3 -5 L 4 -5",
        "-9 10 M -5 -5 L -5 5 L -4 8 L -2 9 L 1 9 L 3 8 L 6 5 M 6 -5 L 6 9",
        "-8 8 M -6 -5 L 0 9 M 6 -5 L 0 9",
        "-11 11 M -8 -5 L -4 9 M 0 -5 L -4 9 M 0 -5 L 4 9 M 8 -5 L 4 9",
        "-8 9 M -5 -5 L 6 9 M 6 -5 L -5 9",
        "-8 8 M -6 -5 L 0 9 M 6 -5 L 0 9 L -2 13 L -4 15 L -6 16 L -7 16",
        "-8 9 M 6 -5 L -5 9 M -5 -5 L 6 -5 M -5 9 L 6 9",
        "-7 7 M 2 -16 L 0 -15 L -1 -14 L -2 -12 L -2 -10 L -1 -8 L 0 -7 L 1 -5 L 1 -3 L -1 -1 M 0 -15 L -1 -13 L -1 -11 L 0 -9 L 1 -8 L 2 -6 L 2 -4 L 1 -2 L -3 0 L 1 2 L 2 4 L 2 6 L 1 8 L 0 9 L -1 11 L -1 13 L 0 15 M -1 1 L 1 3 L 1 5 L 0 7 L -1 8 L -2 10 L -2 12 L -1 14 L 0 15 L 2 16",
        "-4 4 M 0 -16 L 0 16",
        "-7 7 M -2 -16 L 0 -15 L 1 -14 L 2 -12 L 2 -10 L 1 -8 L 0 -7 L -1 -5 L -1 -3 L 1 -1 M 0 -15 L 1 -13 L 1 -11 L 0 -9 L -1 -8 L -2 -6 L -2 -4 L -1 -2 L 3 0 L -1 2 L -2 4 L -2 6 L -1 8 L 0 9 L 1 11 L 1 13 L 0 15 M 1 1 L -1 3 L -1 5 L 0 7 L 1 8 L 2 10 L 2 12 L 1 14 L 0 15 L -2 16",
        "-12 12 M -9 3 L -9 1 L -8 -2 L -6 -3 L -4 -3 L -2 -2 L 2 1 L 4 2 L 6 2 L 8 1 L 9 -1 M -9 1 L -8 -1 L -6 -2 L -4 -2 L -2 -1 L 2 2 L 4 3 L 6 3 L 8 2 L 9 -1 L 9 -3",
        "-8 8 M -8 -12 L -8 9 L -7 9 L -7 -12 L -6 -12 L -6 9 L -5 9 L -5 -12 L -4 -12 L -4 9 L -3 9 L -3 -12 L -2 -12 L -2 9 L -1 9 L -1 -12 L 0 -12 L 0 9 L 1 9 L 1 -12 L 2 -12 L 2 9 L 3 9 L 3 -12 L 4 -12 L 4 9 L 5 9 L 5 -12 L 6 -12 L 6 9 L 7 9 L 7 -12 L 8 -12 L 8 9"]
}

1;
