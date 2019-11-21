package multi1;
require Exporter;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
  flip
  crosswords
  score
  printboard
  matchrule
  expand
  place
);

sub flip    # transpose
{
  map {
    ( local $_, my $flipped ) = ( $_, '' );
    $flipped .= "\n" while s/^./ $flipped .= $& ; '' /gem;
    $flipped
  } @_;
}

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

  use List::Util qw(  sum );
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
  my ( $board, $heights ) = @_;
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
  my @ans;
  my ( $pos, $pat ) = @{ shift() };
  push @ans, [ $pos, $` =~ tr//./cr . $& . $' =~ tr//./cr ] while $pat =~ /\w/g;
  return @ans;
}


sub place
  {

  my ( $input, $board, $heights ) = @_;
  my ($row, $column, $direction, $word) = $input =~ /^(\d)(\d)(v|h)(.*)/;
  my $position = 11 * $row + $column;
  for ( split //, $word )
    {
    substr $board, $position, 1, $_;
    if( $direction eq 'h' ) 
      {
      $position++;
      }
    else
      {
      $position += 11;
      }
    }
  }


1;
