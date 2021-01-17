#!/usr/bin/env perl
#
# Reboot Netgear S8000 device via web interface
#
# Usage: s8000-web-reboot.pl <device ip or name>
#

use strict;
use LWP::UserAgent;
use Net::Netrc;
use Digest::MD5 qw(md5_hex);

sub valid_fqdn($);
sub enc_pass($$);

if ( @ARGV != 1 || not valid_fqdn($ARGV[0]) ) {
    print "Usage: s8000-web-reboot.pl <device ip or name>\n";
    exit 1;
}

#
# Get session parameters:
#
my ($device_addr,$device_mach,$device_pass);
$device_addr = $ARGV[0];
$device_mach = Net::Netrc->lookup($device_addr);

die "ERROR: can't obtain netrc credentials for $device_addr."
    if $device_mach eq '';

$device_pass = $device_mach->password;

#
# Initialize global variables:
#

# LWP agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->cookie_jar( {} );

# URI strings
my ($uri_login,$uri_switch,$uri_reboot);
$uri_login = "http://$device_addr/login.cgi";
$uri_switch = "http://$device_addr/rebootSwitch.cgi";
$uri_reboot = "http://$device_addr/device_reboot.cgi";

# Forms data
my %form_login = (
    'password' => ''
    );
my %form_reboot = (
    'hash' => ''
    );

#
# Connect to device
#
my $res;
$res = $ua->get($uri_login);

die "ERROR: open failed to $device_addr. Got answer: ".$res->status_line
    unless $res->is_success;

#
# Parse rand value
#
my $rand = '';
$rand = $1 if ( $res->content =~ /id='rand' value='(\w+)' disabled/ );

die "ERROR: can't parse rand value for $device_addr."
    if $rand eq '';

#
# Authorize on device
#
$form_login{'password'} = enc_pass($device_pass,$rand);
$res = $ua->post($uri_login,\%form_login);

die "ERROR: auth failed on $device_addr. Got answer: ".$res->status_line
    unless $res->is_success;

#
# Open reboot page
#
$res = $ua->get($uri_switch);

die "ERROR: open failed to $device_addr. Got answer: ".$res->status_line
    unless $res->is_success;

#
# Parse hash value
#
my $hash = '';
$hash = $1 if ( $res->content =~ /id='hash' value="(\w+)"/ );

die "ERROR: can't parse hash value for $device_addr."
    if $hash eq '';

#
# Send reboot command
#
$form_reboot{'hash'} = $hash;
$res = $ua->post($uri_reboot,\%form_reboot);

exit 0;

#
# Check if valid hostname or ip address
#
sub valid_fqdn($) {
    my $testval = shift(@_);
    ( $testval =~ m/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]+)\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/ ) ? return 1 : return 0;
}

#
# Calculate md5 hash of password
#
sub enc_pass($$) {
    my ($data,$key) = (shift,shift);
    my @arr1 = split(//,$data);
    my @arr2 = split(//,$key);
    my $result = '';
    my ($index1,$index2) = (0);
    while ( $index1 < @arr1 || $index2 < @arr2 ) {
        if ( $index1 < @arr1 ) {
            $result .= $arr1[$index1];
            $index1++;
        }
        if ( $index2 < @arr2 ) {
            $result .= $arr2[$index2];
            $index2++;
        }
    }
    return md5_hex($result);
}
