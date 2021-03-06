#!/usr/bin/perl 
#
# https://github.com/f3sty/hosts2rpz
#
use strict;
use warnings;
use Getopt::Long;
use List::Util qw[min max];
use LWP::UserAgent;
use HTTP::Request;

# set $bind_reload_cmd to whatever is appropriate
# for your system
my $bind_reload_cmd = '/usr/sbin/rndc reload';

# default file locations for input and output files
my $in  = '';
my $out = '/var/lib/bind/rpz.db';

# URLs for dns4me.net hosts files API
my $version_url = 'https://dns4me.net/api/v2/get_hosts_file_version';
my $hosts_url   = 'https://dns4me.net/api/v2/get_hosts/hosts';

my $uid;
my $verbose = 0;
my $help;
my $force;

# User-Agent string for http(s) requests
my $script_version = '0.2';
my $agent = "hosts2rpz/${script_version} (https://github.com/f3sty/hosts2rpz))";

# process any args the script was passed
GetOptions(
    'help'     => \$help,
    'verbose+' => \$verbose,
    'uid=s'    => \$uid,
    'in=s'     => \$in,
    'out=s'    => \$out,
    'force'    => \$force
);

if ($help) {
    &printhelp;
    exit(0);
}

my %rec;
my $hostname;
my $maxlen = 1;    # length of longest parsed hostname
my $rrformat;
my ( $h, $a );
my $serial = time;
my $hostsversion;
my $currentversion;
my $tmpfile       = "/tmp/hosts.tmp.$$";
my $clean_tmpfile = 0;

my $ua = LWP::UserAgent->new;
$ua->agent($agent);

# if a UUID was passed as a script arg, fetch the
# current hostsfile version to compare with the local file
if ($uid) {
    $version_url .= "/${uid}";
    $hosts_url   .= "/${uid}";
    my $req = HTTP::Request->new( GET => $version_url );
    my $response = $ua->request($req);
    if ( $response->is_success ) {
        $hostsversion = $response->decoded_content;
        $verbose && print "version available: $hostsversion\n";
    }
    else {
        die "Something failed fetching the current hosts version\n";
    }

    # If we're going to update an existing rpz zone file, check to
    # see if it matches the current hosts version
    if ( -f $out ) {
        open DB, $out;
        while (<DB>) {
            if ( $_ =~ m/version:(\w*)/ ) {
                $currentversion = $1;
                if ( $verbose >= 2 ) {
                    print "Current version in use: $currentversion\n";
                }
            }
        }
        close DB;
    }

    # If --force was specified, update the zone file
    # regardless of the local version
    if ($force) {
        $verbose && print "Forcing re-generation\n";
    }

    # otherwise only update it if the versions  don't match
    elsif ( $currentversion eq $hostsversion ) {
        $verbose && print "Already up to date, exiting.\n";
        exit;
    }
    $req = HTTP::Request->new( GET => $hosts_url );
    $response = $ua->request($req);
    if ( $response->is_success ) {
        open my $tmp, ">${tmpfile}";
        print $tmp $response->decoded_content;
        close $tmp;
    }

    # Use the feshly retrieved file as our --in,
    # and mark it for cleanup
    $in            = $tmpfile;
    $clean_tmpfile = 1;
}

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

if ($clean_tmpfile) {
    if ( $in =~ m/tmp/ ) { unlink($in); }
}

close $outfile;
select(STDOUT);

if ($bind_reload_cmd) {
    my $msg = '';
    my $exitstatus;
    $verbose && print "Reloading bind\n";
    open my $reload, "$bind_reload_cmd|"
      or die "Failed to execute $bind_reload_cmd - $@\n";
    while (<$reload>) {
        $msg .= $_;
    }
    close $reload;
    $exitstatus = $?;
    $verbose && print $msg;
    exit($?);
}

sub printhelp {
    print "\n\nhosts2rpz.pl - convert hosts files to rpz zone format\n";
    print "  Usage: hosts2rpz.pl [-iovuh]\n\n";
    print "   -u | --uid      dns4me user UUID\n";
    print "   -i | --in       input file\n";
    print "   -o | --out      output file (rpz db)\n";
    print "   -f | --force    force update\n";
    print "   -v | --verbose  increase script verbosity\n";
    print "   -h | --help     You are here\n\n";
}

sub write_rr($$) {
    $h = shift;
    $a = shift;
    select($outfile);
    $~ = 'RR';
    write $outfile;
}

# rpz db SOA template
format HEADER = 
$TTL 60
@            IN    SOA  localhost. root.localhost.  (
'@'
            @>>>>>>>>>>>>>>>  ; serial for version:@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$serial,$hostsversion
                          3H  ; refresh 
                          1H  ; retry 
                          1W  ; expiry 
                          1H) ; minimum 
                  IN    NS    localhost.

.
