package WorryEngrave::CNC;

my $CNC_FH;

sub connect {
    my ($pkg, $dev) = @_;

    # configure serial port
    # no idea what the hex numbers mean, I got them from "stty -g" after getting the port into a workable state using Arduino serial monitor
    system("stty -F \Q$dev\E 0:0:18b2:0:3:1c:7f:15:4:0:0:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0");

    return open($CNC_FH, '+<', $dev)
}

sub send {
    my ($pkg, $gcode) = @_;

    print $CNC_FH "$gcode\n";
}

1;
