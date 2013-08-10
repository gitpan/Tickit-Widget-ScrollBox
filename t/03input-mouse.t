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
$widget->add( $static );
$widget->set_window( $win );

my $vextent = $widget->vextent;

# We won't use the is_display tests here because they're annoying to write.
# Having asserted that the Extent objects do the right thing in earlier tests,
# we'll just check the input events have the right effect on those.

is( $vextent->start, 0, 'start is 0 initially' );

# down arrow
pressmouse( press   => 1, 24, 79 );
pressmouse( release => 1, 24, 79 );
is( $vextent->start, 1, 'start moves down +1 after mouse click down arrow' );

# 'after' area
pressmouse( press   => 1, 22, 79 );
pressmouse( release => 1, 22, 79 );
is( $vextent->start, 13, 'start moves down +12 after mouse click after area' );

# up arrow
pressmouse( press   => 1, 0, 79 );
pressmouse( release => 1, 0, 79 );
is( $vextent->start, 12, 'start moves up -1 after mouse click up arrow' );

# 'before' area
pressmouse( press   => 1, 1, 79 );
pressmouse( release => 1, 1, 79 );
is( $vextent->start, 0, 'start moves up -12 after mouse click up arrow' );

# click-drag
pressmouse( press   => 1,  5, 79 );
pressmouse( drag    => 1, 10, 79 );
pressmouse( release => 1, 10, 79 );
is( $vextent->start, 22, 'start is 22 after mouse drag' );

# wheel - doesn't have to be in scrollbar
pressmouse( wheel => 'down', 13, 40 );
is( $vextent->start, 27, 'start moves down +5 after wheel down' );
pressmouse( wheel => 'up',   13, 40 );
is( $vextent->start, 22, 'start moves up -5 after wheel up' );

done_testing;
