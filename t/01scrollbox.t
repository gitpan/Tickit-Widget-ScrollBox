#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::ScrollBox;

my $win = mk_window;

my $static = Tickit::Widget::Static->new(
   text => join "\n", map { "Content on line $_" } 1 .. 100
);

my $widget = Tickit::Widget::ScrollBox->new;

ok( defined $widget, 'defined $widget' );

$widget->add( $static );

is( $widget->lines, 100, '$widget wants 100 lines' );
is( $widget->cols,   20, '$widget wants 20 cols' );

my $vextent = $widget->vextent;

ok( defined $vextent, '$widget has ->vextent' );

$widget->set_window( $win );

ok( defined $static->window, '$static has window after $widget->set_window' );

is( $static->window->lines, 100, '$static given 100 line window' );
is( $static->window->cols,   79, '$static given 79 column window' );

is( $vextent->total,   100, '$vextent->total is 100' );
is( $vextent->viewport, 25, '$vextent->viewport is 25' );
is( $vextent->start,     0, '$vextent->start is 0' );

flush_tickit;

is_display( [ [TEXT("Content on line 1"), BLANK(62), TEXT("\x{25B4}",rv=>1)],
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>2) ], 2 .. 7 ),
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>4) ], 8 .. 24 ),
              [TEXT("Content on line 25"), BLANK(61), TEXT("\x{25BE}",rv=>1)] ],
            'Display initially' );

$widget->scroll( +10 );
flush_tickit;

is_display( [ [TEXT("Content on line 11"), BLANK(61), TEXT("\x{25B4}",rv=>1)],
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>4) ], 12 .. 13 ),
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>2) ], 14 .. 19 ),
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>4) ], 20 .. 34 ),
              [TEXT("Content on line 35"), BLANK(61), TEXT("\x{25BE}",rv=>1)] ],
            'Display after scroll +10' );

is( $vextent->start, 10, '$vextent->start is now 10 after ->scroll' );

$vextent->scroll_to( 25 );
flush_tickit;

is_display( [ [TEXT("Content on line 26"), BLANK(61), TEXT("\x{25B4}",rv=>1)],
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>4) ], 27 .. 32 ),
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>2) ], 33 .. 38 ),
              ( map +[TEXT("Content on line $_"), BLANK(63-length$_), TEXT(" ",bg=>4) ], 39 .. 49 ),
              [TEXT("Content on line 50"), BLANK(61), TEXT("\x{25BE}",rv=>1)] ],
            'Display after $vextent->scroll_to 25' );

done_testing;
