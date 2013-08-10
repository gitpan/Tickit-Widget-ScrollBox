#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2013 -- leonerd@leonerd.org.uk

package Tickit::Widget::ScrollBox;

use strict;
use warnings;
use base qw( Tickit::SingleChildWidget );
use Tickit::Style;

our $VERSION = '0.01';

use List::Util qw( max );

use Tickit::Widget::ScrollBox::Extent;

=head1 NAME

C<Tickit::Widget::ScrollBox> - allow a single child widget to be scrolled

=head1 SYNOPSIS

 use Tickit;
 use Tickit::Widget::ScrollBox;
 use Tickit::Widget::Static;

 my $scrollbox = Tickit::Widget::ScrollBox->new(
    child => Tickit::Widget::Static->new(
       text => join( "\n", map { "The content for line $_" } 1 .. 100 ),
    ),
 );

 Tickit->new( root => $scrollbox )->run;

=head1 DESCRIPTION

This container widget draws a scrollbar beside a single child widget and
allows a portion of it to be displayed by scrolling.

=head1 STYLE

Th following style pen prefixes are used:

=over 4

=item scrollbar => PEN

The pen used to render the background of the scroll bar

=item scrollmark => PEN

The pen used to render the active scroll position in the scroll bar

=item arrow => PEN

The pen used to render the scrolling arrow buttons

=back

The following style keys are used:

=over 4

=item arrow_up => STRING

=item arrow_down => STRING

Each should be a single character to use for the upward or downward scroll
arrow button.

=back

The following style actions are used:

=over 4

=item up_1 (<Up>)

=item down_1 (<Down>)

Scroll up or down 1 line

=item up_half (<PageUp>)

=item down_half (<PageDown>)

Scroll up or down half of the viewport

=item to_top (<C-Home>)

=item to_bottom (<C-End>)

Scroll to the top or bottom of the area

=back

=cut

style_definition base =>
   scrollbar_bg  => "blue",
   scrollmark_bg => "green",
   arrow_rv      => 1,
   arrow_up      => chr 0x25B4, # U+25B4 == Black up-pointing small triangle
   arrow_down    => chr 0x25BE, # U+25BE == Black down-pointing small triangle
   '<Up>'        => "up_1",
   '<Down>'      => "down_1",
   '<PageUp>'    => "up_half",
   '<PageDown>'  => "down_half",
   '<C-Home>'    => "to_top",
   '<C-End>'     => "to_bottom",
   ;

use constant KEYPRESSES_FROM_STYLE => 1;

=head1 CONSTRUCTOR

=cut

=head2 $scrollbox = Tickit::Widget::ScrollBox->new( %args )

Constructs a new C<Tickit::Widget::ScrollBox> object.

Takes the same arguments as taken by the base L<Tickit::SingleChildWidget>
constructor.

=cut

sub new
{
   my $class = shift;
   my %args = @_;

   my $self = $class->SUPER::new( %args );

   $self->{vextent} = Tickit::Widget::ScrollBox::Extent->new( $self );

   return $self;
}

=head1 ACCESSORS

=cut

sub lines
{
   my $self = shift;
   return $self->child->lines;
}

sub cols
{
   my $self = shift;
   return 1 + $self->child->cols;
}

=head2 $vextent = $scrollbox->vextent

Returns the L<Tickit::Widget::ScrollBox::Extent> object representing the box's
vertical scrolling extent.

=cut

sub vextent
{
   my $self = shift;
   return $self->{vextent};
}

=head1 METHODS

=cut

sub reshape
{
   my $self = shift;

   my $window = $self->window or return;

   my @viewportgeom = ( 0, 0, $window->lines, $window->cols - 1 );

   my $viewport;
   if( $viewport = $self->{viewport} ) {
      $viewport->change_geometry( @viewportgeom );
   }
   else {
      $viewport = $window->make_sub( @viewportgeom );
      $self->{viewport} = $viewport;
   }

   my $child = $self->child or return;

   my $vextent = $self->{vextent};

   $vextent->set_viewport( $viewport->lines, $child->lines );

   my @childgeom = (
      -$vextent->start, 0,
      $vextent->total, max( $child->cols, $viewport->cols ),
   );

   if( my $childwin = $child->window ) {
      $childwin->change_geometry( @childgeom );
   }
   else {
      $childwin = $viewport->make_sub( @childgeom );
      $child->set_window( $childwin );
   }
}

sub window_lost
{
   my $self = shift;
   $self->SUPER::window_lost( @_ );

   $self->{viewport}->close if $self->{viewport};

   undef $self->{viewport};
}

=head2 $scrollbox->scroll( $downward )

Requests the content be scrolled downward a number of lines (which may be
negative to scroll upwards).

=cut

sub scroll
{
   my $self = shift;
   my ( $downward ) = @_;
   $self->{vextent}->scroll( $downward );
}

=head2 $scrollbox->scroll_to( $top )

Requests the content be scrolled such that the given line number of the
child's content is the topmost visible in the container.

=cut

sub scroll_to
{
   my $self = shift;
   my ( $top ) = @_;
   $self->{vextent}->scroll_to( $top );
}

sub _extent_scrolled
{
   my $self = shift;

   my $vextent = $self->{vextent};

   my $child = $self->child or return;
   my $childwin = $child->window or return;

   $childwin->reposition( -$vextent->start, 0 );

   # TODO: scrolling might be possible with ->scrollrect

   $self->redraw;
}

sub render_to_rb
{
   my $self = shift;
   my ( $rb, $rect ) = @_;
   my $win = $self->window or return;

   my $lines = $win->lines;
   my $cols  = $win->cols;

   my $scrollbar_pen  = $self->get_style_pen( "scrollbar" );
   my $scrollmark_pen = $self->get_style_pen( "scrollmark" );
   my $arrow_pen      = $self->get_style_pen( "arrow" );

   if( $rect->right == $cols ) {
      my ( $bar_top, $bar_bottom ) = $self->{vextent}->scrollbar_geom( $lines - 2 );

      $rb->text_at (        0, $cols-1, $self->get_style_values( "arrow_up" ), $arrow_pen );
      $rb->erase_at(       $_, $cols-1, 1, $scrollbar_pen  ) for 1 .. $bar_top;
      $rb->erase_at(       $_, $cols-1, 1, $scrollmark_pen ) for $bar_top+1 .. $bar_bottom;
      $rb->erase_at(       $_, $cols-1, 1, $scrollbar_pen  ) for $bar_bottom+1 .. $lines-2;
      $rb->text_at ( $lines-1, $cols-1, $self->get_style_values( "arrow_down" ), $arrow_pen );
   }
}

sub key_up_1      { my $vextent = shift->vextent; $vextent->scroll( -1 ) }
sub key_down_1    { my $vextent = shift->vextent; $vextent->scroll( +1 ) }
sub key_up_half   { my $vextent = shift->vextent; $vextent->scroll( -int( $vextent->viewport / 2 ) ) }
sub key_down_half { my $vextent = shift->vextent; $vextent->scroll( +int( $vextent->viewport / 2 ) ) }

sub key_to_top    { my $vextent = shift->vextent; $vextent->scroll_to( 0 ) }
sub key_to_bottom { my $vextent = shift->vextent; $vextent->scroll_to( $vextent->limit ) }

sub on_mouse
{
   my $self = shift;
   my ( $args ) = @_;

   my $type   = $args->type;
   my $button = $args->button;

   my $lines = $self->window->lines;
   my $cols  = $self->window->cols;

   my $lines_2 = $lines - 2;

   if( $type eq "press" and $button == 1 ) {
      if( $args->col == $cols-1 ) {
         # Click in scrollbar
         my $vextent = $self->vextent;

         my ( $bar_top, $bar_bottom ) = $vextent->scrollbar_geom( $lines_2 );
         my $line = $args->line;

         if( $line == 0 ) { # up arrow
            $vextent->scroll( -1 );
         }
         elsif( $line < $bar_top+1 ) { # above area
            $vextent->scroll( -int( $vextent->viewport / 2 ) );
         }
         elsif( $line < $bar_bottom+1 ) {
            # press in bar - ignore for now - TODO: prelight?
         }
         elsif( $line < $lines-1 ) { # below area
            $vextent->scroll( +int( $vextent->viewport / 2 ) );
         }
         elsif( $line == $lines-1 ) { # down arrow
            $vextent->scroll( +1 );
         }
         return 1;
      }
   }
   elsif( $type eq "drag_start" and $button == 1 ) {
      if( $args->col == $cols-1 ) {
         # Drag in scrollbar
         my $vextent = $self->vextent;

         my ( $bar_top, $bar_bottom ) = $vextent->scrollbar_geom( $lines_2 );;
         my $line = $args->line;

         if( $line >= $bar_top+1 and $line < $bar_bottom+1 ) {
            $self->{drag_offset} = $line - $bar_top;
            return 1;
         }
      }
   }
   elsif( $type eq "drag" and $button == 1 and defined( $self->{drag_offset} ) ) {
      my $want_bar_top = $args->line - $self->{drag_offset};
      my $vextent = $self->vextent;

      my $want_top = int( $want_bar_top * $vextent->total / $lines_2 + 0.5 );

      $vextent->scroll_to( $want_top );
   }
   elsif( $type eq "drag_stop" ) {
      undef $self->{drag_offset};
   }
   elsif( $type eq "wheel" ) {
      my $vextent = $self->vextent;
      $vextent->scroll( -5 ) if $button eq "up";
      $vextent->scroll( +5 ) if $button eq "down";
      return 1;
   }
}

=head1 TODO

=over 4

=item *

Horizontal as well as vertical scrolling.

=item *

Allow either scrollbar to be always visible, visible only on demand (when
extent->limit > 0), or never.

=item *

Choice of left/right and top/bottom bar positions.

=item *

Hide/grey the up/down/left/right arrows when at endstop.

=item *

Allow smarter cooperation with a scrolling-aware child widget; likely by
setting extent objects on the child if it declares to be supported, and use
that instead of an offset child window.

=back

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
