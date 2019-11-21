#!/usr/bin/perl

use strict;    # multiplayer upwords
use warnings;
use Path::Tiny;
use List::Util qw( shuffle uniq first sum );
$SIG{__WARN__} = sub { die @_ };
use lib 'my_data';
use multi1;
use Data::Dumper;


my $n        = 10;    # configuration  board will be  $n by $n
my $maxtiles = 7;
my $dictionaryfile = path( "my_data", 'linux1.txt' );
my $cachefilename = path( "my_data", "words.11108138.$n" );

@ARGV or @ARGV = qw( one two three four );    # for testing


my $n1      = $n + 1;
my $board   = ( '.' x $n . "\n" ) x $n;
my $heights = $board =~ tr/./0/r;
my @dictwords;
if ( -f $cachefilename ) {
  @dictwords = split /\n/, path($cachefilename)->slurp;
}
else {
  print "caching words of max length $n\n";
  @dictwords = sort { length $b <=> length $a }
    grep /^[a-z]{2,$n}$/,
    split /\n/, path($dictionaryfile)->slurp;
  path($cachefilename)->spew( join "\n", @dictwords, '' );
}
my %isword = map +( $_, 1 ), @dictwords;

my @drawpile = shuffle +    #  thanks to GrandFather 11108145
  ('a') x 9, ('b') x 2, ('c') x 2, ('d') x 4, ('e') x 12, ('f') x 2,
  ('g') x 4, ('h') x 2, ('i') x 9, ('j') x 1, ('k') x 1,  ('l') x 4, ('m') x 2,
  ('n') x 6, ('o') x 8, ('p') x 2, ('q') x 1, ('r') x 6,  ('s') x 4, ('t') x 6,
  ('u') x 4, ('v') x 2, ('w') x 2, ('x') x 1, ('y') x 2,  ('z') x 1;

@ARGV * $maxtiles > @drawpile and die "too many players for tiles\n";

my @players;
my $maxname = '';
for (@ARGV) {
  $maxname |= $_;
  push @players,
    {
    name  => $_,
    score => 0,
    tiles => [ sort splice @drawpile, 0, $maxtiles ]
    };
}
my $printf  = '%' . length($maxname) . "s score: %3d  tiles: %s\n";
my $current = 0;
my $who     = $players[$current]{name};
my @tiles   = @{ $players[$current]{tiles} };
my $passes  = 0;

print "$who moves: 1  tiles: @tiles\n";
my $pat = join '', map "$_?", @tiles;

my $word = first { /^[@tiles]+$/ and ( join '', sort split // ) =~ /^$pat$/ }
@dictwords;
$word or die "no starting word can be found\n";
my $pos = $n1 * ( $n >> 1 ) + ( $n - length($word) >> 1 );
substr $board,   $pos, length $word, $word;
substr $heights, $pos, length $word, 1 x length $word;
my $tiles = join '', @tiles;
$tiles =~ s/$_// for split //, $word;
@tiles = split //, $tiles;
push @tiles, splice @drawpile, 0, $maxtiles - @tiles;
my @chosen  = $word;
my $changed = 1;
my $moves   = 1;
my $score   = ( length $word == $maxtiles ) * 20 + 2 * length $word;
print '-' x 20, "$who plays: 0 $pos $word   score: $score\n";
printboard($board, $heights);
$players[$current]{tiles} = [@tiles];
$players[$current]{score} = $score;

while (1) {
  $current = ( $current + 1 ) % @players;
  $who     = $players[$current]{name};
  @tiles   = sort @{ $players[$current]{tiles} };
  @tiles or last;

  $heights =~ tr/5// == $n**2 and last;    # all 5, no more play possible
  my @best;    # [ flip, pos, pat, old, highs, word ]
  my @all = ( @tiles, ' ', sort +uniq $board =~ /\w/g );
  $moves++;
  print "$who moves: $moves  tiles: @tiles\n";
  my @subdict = grep /^[@all]+$/, @dictwords;
  for my $flip ( 0, 1 ) {
    my @pat;
    $board =~ /(?<!\w).{2,}(?!\w)(?{ push @pat, [ $-[0], $& ] })(*FAIL)/;
    @pat = map expand($_), @pat;
    @pat = sort { length $b->[1] <=> length $a->[1] } @pat;

    for (@pat) {
      my ( $pos, $pat ) = @$_;
      my $old   = substr $board,   $pos, length $pat;
      my $highs = substr $heights, $pos, length $pat;
      my @under = $old =~ /\w/g;
      my $underpat = qr/[^@under@tiles]/;
      my @words    = grep {
             length $pat == length $_
          && !/$underpat/
          && /^$pat$/
          && ( ( $old ^ $_ ) !~ /^\0+\]$/ )    # adding just an 's' not allowed
          && matchrule( $old, $highs, $_ )
          && crosswords( $pos, $_ )
      } @subdict;
      for my $word (@words) {
        my $score = score( $board, $heights, $pos, $old, $word );
        $score > $#best
          and $best[$score] //= [ $flip, $pos, $pat, $old, $highs, $word ];
      }
    }
    ( $board, $heights ) = flip $board, $heights;
  }
  if ( $changed = @best ) {
    my ( $flip, $pos, $pat, $old, $highs, $word ) = @{ $best[-1] };
    my $newmask = ( $old ^ $word ) =~ tr/\0/\xff/cr;
    $flip and ( $board, $heights ) = flip $board, $heights;
    substr $board, $pos, length $word, $word;
    substr $heights, $pos, length $highs,
      ( $highs & $newmask ) =~ tr/0-4/1-5/r | ( $highs & ~$newmask );
    $flip and ( $board, $heights ) = flip $board, $heights;
    my $tiles = join '', @tiles;
    $tiles =~ s/$_// for split //, $word & $newmask;
    @tiles = split //, $tiles;
    my $total = $players[$current]{score} += $#best;
    print '-' x 20, "$who choses: $flip $pos $word   score: $#best  $total\n";
    push @chosen, $word;
    $passes = 0;
  }
  elsif (@drawpile) {
    my $tiles = join '', @tiles;    # discard random tile
    $tiles =~ s/$_// and last for 'q', 'z', $tiles[ rand @tiles ];
    @tiles = split //, $tiles;
    print "$who discards and draws a new tile\n";
  }
  else {
    print "$who passes\n";
    if ( ++$passes >= @players ) {
      print "All players pass so the game is ended.\n";
      last;
    }
  }
  @tiles = sort @tiles, splice @drawpile, 0, $maxtiles - @tiles;
  $changed and printboard($board,$heights);
  $players[$current]{tiles} = [@tiles];
  @tiles or @drawpile or last;
}
print "\n\nchosen words: @chosen\n\n";
for (@players) {
  $who   = $_->{name};
  $tiles = $_->{tiles};
  $score = $_->{score} - 5 * @$tiles;
  printf $printf, $who, $score, "@$tiles";
}

# validate all words are in the dictionary
$isword{$&} or die "$& is not a word\n" while $board =~ /\w{2,}/g;
$board = flip $board;
$isword{$&} or die "$& is not a word\n" while $board =~ /\w{2,}/g;




