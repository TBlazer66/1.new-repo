#!/usr/bin/perl

use strict;    # multiplayer upwords
use warnings;
use Path::Tiny;
use List::Util qw( shuffle uniq first sum );
$SIG{__WARN__} = sub { die @_ };
use Data::Dump;
use 5.016;
use POSIX qw(strftime);

@ARGV or @ARGV = qw( one two three four );    # for testing

## paths and constraints

my $abs   = path(__FILE__)->absolute;
my $path1 = Path::Tiny->cwd;
my $games = "games";
my $path2 = path( $path1, $games );
say "abs is $abs";
say "path1 is $path1";
say "path2 is $path2";
print "This script will build the above path2. Proceed? (y|n)";

my $prompt = <STDIN>;
chomp $prompt;
die unless ( $prompt eq "y" );

my $n        = 10;    # configuration  board will be  $n by $n
my $maxtiles = 7;
my $dictionaryfile = path( "my_data", 'enable1.txt' );
my $cachefilename = path( "my_data", "words.11108138.$n" );

my $munge = strftime( "%d-%m-%Y-%H-%M-%S", localtime );
$munge .= ".txt";

my $save_file = path( $path2, $munge )->touchpath;
#my $fh = $save_file->openw_utf8;
#say $fh, $munge;
#say "------------";
my $return1=$save_file->spew_utf8( $munge);
say "return1 is $return1";

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
  ('a') x 7, ('b') x 3, ('c') x 4, ('d') x 5, ('e') x 8, ('f') x 3,
  ('g') x 3, ('h') x 3, ('i') x 7, ('j') x 1, ('k') x 2, ('l') x 5, ('m') x 5,
  ('n') x 5, ('o') x 7, ('p') x 3, ('q') x 1, ('r') x 5, ('s') x 6, ('t') x 5,
  ('u') x 5, ('v') x 2, ('w') x 2, ('x') x 1, ('y') x 2, ('z') x 1;

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
printboard();
$players[$current]{tiles} = [@tiles];
$players[$current]{score} = $score;

my $return2=$save_file->spew_utf8(@players);
say "return2 is $return2";

sub flip              # transpose one of more grids
{
  map {
    ( local $_, my $flipped ) = ( $_, '' );
    $flipped .= "\n" while s/^./ $flipped .= $& ; '' /gem;
    $flipped
  } @_;
}


while (1) {
  $current = ( $current + 1 ) % @players;
  $who     = $players[$current]{name};
  @tiles   = sort @{ $players[$current]{tiles} };
  @tiles or last;

  $heights =~ tr/5// == $n**2
    and last;    # all 5, no more play possible 
  my @best;      # [ flip, pos, pat, old, highs, word ]
  my @all = ( @tiles, ' ', sort +uniq $board =~ /\w/g );
  $moves++;
  print "$who moves: $moves  tiles: @tiles\n";
  my @subdict = grep /^[@all]+$/, @dictwords;
  for my $flip ( 0, 1 ) {
    my @pat;

say "flip is $flip";

    $board =~ /(?<!\w).{2,}(?!\w)(?{ push @pat, [ $-[0], $& ] })(*FAIL)/;
say "board:";
say "$board";
say "patterns before expansion: ";
    dd @pat;
    @pat = map expand($_), @pat;
    @pat = sort { length $b->[1] <=> length $a->[1] } @pat;
    say "patterns----------------";

    dd @pat;

    for (@pat) {
      my ( $pos, $pat ) = @$_;
      my $old   = substr $board,   $pos, length $pat;
      my $highs = substr $heights, $pos, length $pat;
      my @under = $old =~ /\w/g;
      my $underpat = qr/[^@under@tiles]/;
      #say "underpat is $underpat";
      my @words = grep {
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
    say "changed is $changed";
    my ( $flip, $pos, $pat, $old, $highs, $word ) = @{ $best[-1] };
    my $newmask = ( $old ^ $word ) =~ tr/\0/\xff/cr;
    $flip and ( $board, $heights ) = flip $board, $heights;
    substr $board, $pos, length $word, $word;
    #say "new mask is $newmask";
    substr $heights, $pos, length $highs,
      ( $highs & $newmask ) =~ tr/0-4/1-5/r | ( $highs & ~$newmask );
    $flip and ( $board, $heights ) = flip $board, $heights;
    my $tiles = join '', @tiles;
    say "word is $word";
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
  $changed and printboard();
  $players[$current]{tiles} = [@tiles];
  @tiles or @drawpile or last;

$save_file->spew_utf8( "move is $current",);  
say  "move is $current" ;

say "end of move, continue?";

$prompt = <STDIN>;
chomp $prompt;
die unless ( $prompt eq "y" );

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

sub crosswords {
  my ( $pos, $word ) = @_;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
  my $revboard = '';
  local $_ = $board;
  substr( $_, $pos, length $word ) =~ tr//-/c;
  $revboard .= "\n" while s/^./ $revboard .= $& ; '' /gem;
  my @ch = split //, $word;
  while ( $revboard =~ /(\w*)-(\w*)/g ) {
    my $check = $1 . shift(@ch) . $2;
    length $check > 1 && !$isword{$check} and return 0;
  }
  return 1;
}

sub score {
  my ( $bd, $hi, $pos, $old, $word ) = @_;
  my $len  = length $word;
  my $mask = ( $old ^ $word ) =~ tr/\0/\xff/cr;
  substr $bd, $pos, $len, ( $old & ~$mask ) =~ tr/\0/-/r;
  my $highs = substr $hi, $pos, $len;
  substr $hi, $pos, $len,
    $highs = ( $highs & $mask ) =~ tr/0-4/1-5/r | ( $highs & ~$mask );
  my $score =
    ( $mask =~ tr/\xff// == $maxtiles ) * 20 + ( $highs =~ /^1+$/ + 1 ) * sum
    split //, $highs;
  my ( $rbd, $rhi ) = flip $bd, $hi;
  my @ch = ( $mask & $word ) =~ /\w/g;

  while ( $rbd =~ /(\w*)-(\w*)/g )    # find each cross word of new tile
  {
    my $rpos  = $-[0];
    my $rword = $1 . shift(@ch) . $2;
    length $rword > 1 or next;
    $highs = substr $rhi, $rpos, length $rword;
    $score += ( $highs =~ /^1+$/ + 1 ) * sum split //, $highs;
  }
  return $score;
}

sub printboard {
  my $bd = $board =~ tr/\n/-/r;
  $bd =~ s/-/   $_/ for $heights =~ /.*\n/g;
  print $bd;
}

sub matchrule {
  my ( $old, $highs, $word ) = @_;
  $old eq $word and return 0;
  my $newmask = ( $old ^ $word ) =~ tr/\0/\xff/cr;
  ( $newmask & $highs ) =~ tr/5// and return 0;
  my $tiles = "@tiles";
  $tiles =~ s/$_// or return 0 for ( $newmask & $word ) =~ /\w/g;
  return 1;
}

sub expand  # change patterns with several letters to several single letter pats
{
  use Data::Dump;
  my @ans;
  my ( $pos, $pat ) = @{ shift() };

  say "values arrive in expand: $pos $pat";

  push @ans, [ $pos, $` =~ tr//./cr . $& . $' =~ tr//./cr ] while $pat =~ /\w/g;
  dd \@ans;
  return @ans;
}



