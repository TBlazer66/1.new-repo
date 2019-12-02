#!/usr/bin/perl

use strict;    # wordscapes helper script
use warnings;
use Path::Tiny;
use Data::Dump;
use 5.016;
use POSIX qw(strftime);

my ($tiles) = @ARGV;

if ( not defined $tiles ) {
  die "Need tiles without spaces.\n";
}
## paths and constraints

my $abs   = path(__FILE__)->absolute;
my $path1 = Path::Tiny->cwd;
my $games = "wordscapes";
my $path2 = path( $path1, $games );
say "abs is $abs";
say "path1 is $path1";
say "path2 is $path2";
print "This script will build the above path2. Proceed? (y|n)";
my $prompt = <STDIN>;
chomp $prompt;
die unless ( $prompt eq "y" );

my $maxtiles       = 7;
my $dictionaryfile = path( "my_data", 'enable1.txt' );
my $cachefilename  = path( "my_data", "wordscapes.$maxtiles" );
my $munge          = strftime( "%d-%m-%Y-%H-%M-%S", localtime );
$munge .= ".txt";
my $save_file = path( $path2, $munge )->touchpath;

my @dictwords;

if ( -f $cachefilename ) {
  @dictwords = split /\n/, path($cachefilename)->slurp;
}
else {
  print "caching words of max length $maxtiles\n";
  @dictwords = sort { length $b <=> length $a }
    grep /^[a-z]{2,$maxtiles}$/,
    split /\n/, path($dictionaryfile)->slurp;
  path($cachefilename)->spew( join "\n", @dictwords, '' );
}

my @arr = split( '', $tiles );
say " tiles are @arr";
#my $pat = qr/$tiles/;
#my @subdict = grep {/$pat/} @dictwords;
my @subdict = grep /^[@arr]+$/, @dictwords;
@subdict = sort { $a cmp $b } @subdict;

say "subdict is";
dd \@subdict;

@subdict=join("\n", @subdict);

my $return1 = $save_file->append_utf8(@subdict);
say "return1 is $return1";



