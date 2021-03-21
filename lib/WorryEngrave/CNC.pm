package WorryEngrave::CNC;

my $CNC_FH;
my $dryrun;

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

sub get_coords {
    return (undef,undef,undef) if $dryrun;

    print $CNC_FH "?\n";

    while (1) {
        while (<$CNC_FH>) {
            if (/WCO:\s*([-.0-9]+),([-.0-9]+),([-.0-9]+)/) {
                return ($1,$2,$3);
            }
       }
    }
}

sub send {
    my ($pkg, $gcode) = @_;

    return if $dryrun;

    print $CNC_FH "$gcode\n";

    my $gotline = 0;
    while (!$gotline) {
        while (<$CNC_FH>) {
            $gotline = 1;
       }
    }
}

1;
