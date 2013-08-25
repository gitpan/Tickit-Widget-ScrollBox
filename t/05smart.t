#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Tickit::Test;

use Tickit::Widget::ScrollBox;

my $win = mk_window;

my ( $vextent, $hextent );
my ( $downward, $rightward ) = (0) x 2;
{
   package ScrollableWidget;
   use base qw( Tickit::Widget );

   use constant CAN_SCROLL => 1;

   sub lines { 100 }
   sub cols  { 50 }

   sub set_scrolling_extents
   {
      shift;
      ( $vextent, $hextent ) = @_;
   }

   sub scrolled
   {
      shift;
      $downward  += $_[0];
      $rightward += $_[1];
   }

   sub render_to_rb {}
}

my $child = ScrollableWidget->new;

my $widget = Tickit::Widget::ScrollBox->new(
   child => $child,
   horizontal => 1, vertical => 1,
);

$widget->set_window( $win );
flush_tickit;

ok( defined $vextent, '$vextent set' );
ok( defined $hextent, '$hextent set' );

ok( defined $child->window, '$child has window after $widget->set_window' );

is( $child->window->top,    0, '$child window starts on line 0' );
is( $child->window->left,   0, '$child window starts on column 0' );
is( $child->window->lines, 25, '$child given 25 line window' );
is( $child->window->cols,  79, '$child given 79 column window' );

$widget->scroll( +10 );
flush_tickit;

is( $downward, 10, '$child informed of scroll +10' );
$downward = 0;

is( $child->window->top, 0, '$child window still starts on line 0 after scroll +10' );

$widget->scroll_to( 25 );
flush_tickit;

is( $downward, 15, '$child informed of scroll_to 25' );

is( $child->window->top, 0, '$child window still starts on line 0 after scroll_to 25' );

done_testing;
