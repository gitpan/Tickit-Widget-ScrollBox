#!/usr/bin/perl

use strict;
use warnings;

use Tickit;
use Tickit::Widget::ScrollBox;
use Tickit::Widget::Static;

my $scrollbox = Tickit::Widget::ScrollBox->new(
   child => Tickit::Widget::Static->new(
      text => join( "\n", map { "The content for line $_" } 1 .. 100 ),
   ),
);

Tickit->new( root => $scrollbox )->run;
