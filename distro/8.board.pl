#!/usr/bin/perl

use strict; # https://perlmonks.org/?node_id=11108138
use warnings;
use feature 'say';
use Path::Tiny;
use List::Util qw( shuffle uniq first sum );


my $n = 10;            # configuration  board will be  $n by $n
my $maxtiles = 7;
my $dictionaryfile = path ( "my_data", 'enable1.txt');
my $cachefilename = "words.11108138.$n"; # for caching subsets of dictionary
my $n1 = $n + 1;
my $board = ('.' x $n . "\n") x $n;
my $heights = $board =~ tr/./0/r;
my @dictwords;
if( -f $cachefilename )
  {
  @dictwords = split /\n/, path($cachefilename)->slurp;
  }
else
  {
  print "caching words of max length $n\n";
  @dictwords = sort { length $b <=> length $a }
    grep /^[a-z]{2,$n}$/,
    split /\n/, path($dictionaryfile)->slurp;
	#say "dict words are @dictwords";
	
  path($cachefilename)->spew(join "\n", @dictwords, '');
  }
my %isword = map +($_, 1), @dictwords;

my @drawpile = shuffle + #  thanks to GrandFather 11108145
  ('a') x 9, ('b') x 2, ('c') x 2, ('d') x 4, ('e') x 12, ('f') x 2,
  ('g') x 4, ('h') x 2, ('i') x 9, ('j') x 1, ('k') x 1, ('l') x 4, ('m') x 2,
  ('n') x 6, ('o') x 8, ('p') x 2, ('q') x 1, ('r') x 6, ('s') x 4, ('t') x 6,
  ('u') x 4, ('v') x 2, ('w') x 2, ('x') x 1, ('y') x 2, ('z') x 1 ;
  
  sub flip # transpose one of more grids
  {
  map
    {
    (local $_, my $flipped) = ($_, '');
    $flipped .= "\n" while s/^./ $flipped .= $& ; '' /gem;
    $flipped
    } @_;
  }
  
 
my @tiles = sort splice @drawpile, 0, $maxtiles;
print "moves: 1  tiles: @tiles\n";
my $pat = join '', map "$_?", @tiles;

my $word = first
  { /^[@tiles]+$/ and (join '', sort split //) =~ /^$pat$/ } @dictwords;
$word or die "no starting word can be found\n";
my $pos = $n1 * ($n >> 1) + ($n - length($word) >> 1);
substr $board, $pos, length $word, $word;
substr $heights, $pos, length $word, 1 x length $word;
my $tiles = join '', @tiles;
$tiles =~ s/$_// for split //, $word;
@tiles = split //, $tiles;
push @tiles, splice @drawpile, 0, $maxtiles - @tiles;
my @chosen = $word;
my $changed = 1;
my $moves = 1;
my $totalscore = (length $word == $maxtiles) * 20 + 2 * length $word;
print '-' x 20, "chosen: 0 $pos $word   score: $totalscore\n";
printboard();

while( @tiles )
  {
  $heights =~ tr/5// == $n ** 2 and last; # all 5, no more play possible
  my @best; # [ flip, pos, pat, old, highs, word ]
  my @all = (@tiles, ' ', sort +uniq $board =~ /\w/g);
  $moves++;
  print "moves: $moves  tiles: @tiles\n";
  my @subdict = grep /^[@all]+$/, @dictwords;
  for my $flip ( 0, 1 )
    {
    my @pat;
    $board =~ /(?<!\w).{2,}(?!\w)(?{ push @pat, [ $-[0], $& ] })(*FAIL)/;
    @pat = map expand($_), @pat;
    @pat = sort { length $b->[1] <=> length $a->[1] } @pat;

    for ( @pat )
      {
      my ($pos, $pat) = @$_;
      my $old = substr $board, $pos, length $pat;
      my $highs = substr $heights, $pos, length $pat;
      my @under = $old =~ /\w/g;
      my $underpat = qr/[^@under@tiles]/;
      my @words = grep {
        length $pat == length $_
        && !/$underpat/
        && /^$pat$/
        && ( ($old ^ $_) !~ /^\0+\]$/ ) # adding just an 's' not allowed
        && matchrule( $old, $highs, $_ )
        && crosswords( $pos, $_ )
        } @subdict;
      for my $word ( @words )
        {
        my $score = score( $board, $heights, $pos, $old, $word );
        $score > $#best and $best[ $score ] //=
          [ $flip, $pos, $pat, $old, $highs, $word, $score ];
        }
      }
    ($board, $heights) = flip $board, $heights;
    }
  if( $changed = @best )
    {
    my ($flip, $pos, $pat, $old, $highs, $word, $score) = @{ $best[-1] };
    my $newmask = ($old ^ $word) =~ tr/\0/\xff/cr;
    $flip and ($board, $heights) = flip $board, $heights;
    substr $board, $pos, length $word, $word;
    substr $heights, $pos, length $highs,
      ($highs & $newmask) =~ tr/0-4/1-5/r | ($highs & ~$newmask);
    $totalscore += $score;
    $flip and ($board, $heights) = flip $board, $heights;
    my $tiles = join '', @tiles;
    $tiles =~ s/$_// for split //, $word & $newmask;
    @tiles = split //, $tiles;
    print '-' x 20, "chosen: $flip $pos $word   score: $score\n";
    push @chosen, $word;
    }
  else
    {
    my $tiles = join '', @tiles; # discard random tile
    $tiles =~ s/$_// and last for 'q', 'z', $tiles[rand @tiles];
    @tiles = split //, $tiles;
    }
  @tiles = sort @tiles, splice @drawpile, 0, $maxtiles - @tiles;
  $changed and printboard();
  }
print "\nchosen words: @chosen\ntotalscore: $totalscore\n";

say "finishing\n";

# validate all words are in the dictionary
$isword{ $& } or die "$& is not a word\n" while $board =~ /\w{2,}/g;
say "word is $&";
say "$board";
$board = flip $board;
$isword{ $& } or die "$& is not a word\n" while $board =~ /\w{2,}/g;
say "word is $&";
say "$board";




sub crosswords
  {
  my ($pos, $word) = @_;
  my $revboard = '';
  local $_ = $board;
  substr($_, $pos, length $word) =~ tr//-/c;
  $revboard .= "\n" while s/^./ $revboard .= $& ; '' /gem;
  my @ch = split //, $word;
  while( $revboard =~ /(\w*)-(\w*)/g )
    {
    my $check = $1 . shift(@ch) . $2;
    length $check > 1 && ! $isword{ $check } and return 0;
    }
  return 1;
  }

sub score
  {
  my ($bd, $hi, $pos, $old, $word) = @_;
  my $len = length $word;
  my $mask = ( $old ^ $word ) =~ tr/\0/\xff/cr;
  substr $bd, $pos, $len, ( $old & ~$mask ) =~ tr/\0/-/r;
  my $highs = substr $hi, $pos, $len;
  substr $hi, $pos, $len,
    $highs = ( $highs & $mask ) =~ tr/0-4/1-5/r | ( $highs & ~$mask );
  my $score = ($mask =~ tr/\xff// == $maxtiles) * 20 +
    ( $highs =~ /^1+$/ + 1 ) * sum split //, $highs;
  my ($rbd, $rhi) = flip $bd, $hi;
  my @ch = ($mask & $word) =~ /\w/g;
  while( $rbd =~ /(\w*)-(\w*)/g ) # find each cross word of new tile
    {
    my $rpos = $-[0];
    my $rword = $1 . shift(@ch) . $2;
    length $rword > 1 or next;
    $highs = substr $rhi, $rpos, length $rword;
    $score += ( $highs =~ /^1+$/ + 1 ) * sum split //, $highs;
    }
  return $score;
  }

sub printboard
  {
  my $bd = $board =~ tr/\n/-/r;
  $bd =~ s/-/   $_/ for $heights =~ /.*\n/g;
  print $bd;
  }

sub matchrule
  {
  my ($old, $highs, $word) = @_;
  $old eq $word and return 0;
  my $newmask = ($old ^ $word) =~ tr/\0/\xff/cr;
  ($newmask & $highs) =~ tr/5// and return 0;
  my $tiles = "@tiles";
  $tiles =~ s/$_// or return 0 for ($newmask & $word) =~ /\w/g;
  return 1;
  }

sub expand # change patterns with several letters to several single letter pats
  {
  my @ans;
  my ($pos, $pat) = @{ shift() };
  push @ans, [ $pos, $` =~ tr//./cr . $& . $' =~ tr//./cr ]
    while $pat =~ /\w/g;
  return @ans;
  }
