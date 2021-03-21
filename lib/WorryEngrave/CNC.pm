package WorryEngrave::CNC;

my $CNC_FH;
my $dryrun;

# Grbl normally only reports Machine Position (MPos), but we need to know Work
# Position (WPos). There is an option ($10) to enable reporting of WPos instead
# of MPos but only intended for human use; MPos is recommended for software.
#
# Grbl also reports Work Coordinate Offset (WCO) whenever it changes. To get from
# MPos to WPos, we just need to keep track of WCO, and then:
#   WPos = MPos - WCO
my @wco = (0,0,0);

my $buf = '';

sub dryrun {
    $dryrun = 1;
}

sub connect {
    my ($pkg, $dev) = @_;

    return undef if $dryrun;

    # configure serial port
    # no idea what the hex numbers mean, I got them from "stty -g" after getting the port into a workable state using Arduino serial monitor
    system("stty -F \Q$dev\E 0:0:18b2:0:3:1c:7f:15:4:0:0:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0");

    return open($CNC_FH, '+<', $dev)
}

# line-buffer input
sub read_line {
    my ($pkg) = @_;

    while (<$CNC_FH>) {
        $buf .= $_;
        return $1 if $buf =~ s/^.*\n//;
    }

    return undef;
}

# return current work coordinates
sub get_coords {
    my ($pkg) = @_;

    return (undef,undef,undef) if $dryrun;

    print $CNC_FH "?\n";

    while (1) {
        while ($_ = $pkg->read_line) {
            if (/WCO:\s*([-.0-9]+),([-.0-9]+),([-.0-9]+)/) {
                @wco = ($1,$2,$3);
            }
            if (/MPos:\s*([-.0-9]+),([-.0-9]+),([-.0-9]+)/) {
                return ($1-$wco[0],$2-$wco[1],$3-$wco[2]);
            }
       }
    }
}

# send a message to the controller and wait for it to respond (preferably with "ok" but we don't check for that)
sub send {
    my ($pkg, $gcode) = @_;

    return if $dryrun;

    print $CNC_FH "$gcode\n";

    my $gotline = 0;
    while (!$gotline) {
        while ($_ = $pkg->read_line) {
            $gotline = 1;
       }
    }
}

1;
