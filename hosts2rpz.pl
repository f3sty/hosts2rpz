#!/usr/bin/perl 
#
# See https://github.com/f3sty/hosts2rpz
#
use strict;
use warnings;
use Getopt::Long;
use List::Util qw[min max];

my $in  = '';
my $out = '/etc/bind/rpz.db';

GetOptions( 'in=s' => \$in, 'out=s' => \$out );

my %rec;
my $hostname;
my $maxlen = 1;    # length of longest parsed hostname
my $rrformat;
my ( $h, $a );
my $serial = time;

# read the input file
unless ( -f $in ) {
    die "Usage: $0 --in [infile]\n\n";
}

open my $infile, "<${in}"
  or die "Something went wrong trying to read $in\n";
while (<$infile>) {
    chomp;

    # strip comments
    $_ =~ s/(#|\/\/).*//;
    next unless ( $_ =~ m/\w/ );

    # handle multiple hostnames per line
    my @hostsentry = split /\s+/, $_;
    my $ip = shift(@hostsentry);
    foreach $hostname (@hostsentry) {
        $maxlen = max( $maxlen, length($hostname) );
        $rec{$hostname} = $ip;
    }
}

# dynamic template format based on the max hostname length
$rrformat =
    "format RR = \n" . '@'
  . '<' x $maxlen
  . '  IN   A    @<<<<<<<<<<<<<<' . "\n" . '$h,$a' . "\n" . ".\n";
eval $rrformat;

open my $outfile, ">${out}" or die "Error writing to $out\n\n";

# write out the rpz.db header,
# set the zone serial to POSIX timestamp
select($outfile);
$~ = 'HEADER';
write $outfile;

# write out each RR
foreach $hostname ( sort keys %rec ) {
    &write_rr( $hostname, $rec{$hostname} );
}

sub write_rr($$) {
    $h = shift;
    $a = shift;
    select($outfile);
    $~ = 'RR';
    write $outfile;
}

close $outfile;

# rpz db SOA template
format HEADER = 
    $TTL 60
    @            IN    SOA  localhost. root.localhost.  (
'@'
            @>>>>>>>>>>>>>>>  ; serial 
$serial
                          3H  ; refresh 
                          1H  ; retry 
                          1W  ; expiry 
                          1H) ; minimum 
                  IN    NS    localhost.

.
