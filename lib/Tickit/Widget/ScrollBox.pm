#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2013 -- leonerd@leonerd.org.uk

package Tickit::Widget::ScrollBox;

use strict;
use warnings;
use base qw( Tickit::SingleChildWidget );
use Tickit::Style;

our $VERSION = '0.02';

use List::Util qw( max );

use Tickit::Widget::ScrollBox::Extent;
use Tickit::RenderBuffer qw( LINE_DOUBLE CAP_BOTH );

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

=item arrow_left => STRING

=item arrow_right => STRING

Each should be a single character to use for the scroll arrow buttons.

=back

The following style actions are used:

=over 4

=item up_1 (<Up>)

=item down_1 (<Down>)

=item left_1 (<Left>)

=item right_1 (<Right>)

Scroll by 1 line

=item up_half (<PageUp>)

=item down_half (<PageDown>)

=item left_half (<C-Left>)

=item right_half (<C-Right>)

Scroll by half of the viewport

=item to_top (<C-Home>)

=item to_bottom (<C-End>)

=item to_leftmost (<Home>)

=item to_rightmost (<End>)

Scroll to the edge of the area

=back

=cut

style_definition base =>
   scrollbar_fg  => "blue",
   scrollmark_bg => "blue",
   arrow_rv      => 1,
   arrow_up      => chr 0x25B4, # U+25B4 == Black up-pointing small triangle
   arrow_down    => chr 0x25BE, # U+25BE == Black down-pointing small triangle
   arrow_left    => chr 0x25C2, # U+25C2 == Black left-pointing small triangle
   arrow_right   => chr 0x25B8, # U+25B8 == Black right-pointing small triangle
   '<Up>'        => "up_1",
   '<Down>'      => "down_1",
   '<Left>'      => "left_1",
   '<Right>'     => "right_1",
   '<PageUp>'    => "up_half",
   '<PageDown>'  => "down_half",
   '<C-Left>'    => "left_half",
   '<C-Right>'   => "right_half",
   '<C-Home>'    => "to_top",
   '<C-End>'     => "to_bottom",
   '<Home>'      => "to_leftmost",
   '<End>'       => "to_rightmost",
   ;

use constant KEYPRESSES_FROM_STYLE => 1;

=head1 CONSTRUCTOR

=cut

=head2 $scrollbox = Tickit::Widget::ScrollBox->new( %args )

Constructs a new C<Tickit::Widget::ScrollBox> object.

Takes the following named arguments in addition to those taken by the base
L<Tickit::SingleChildWidget> constructor:

=over 8

=item vertical => BOOL or "on_demand"

=item horizontal => BOOL or "on_demand"

Whether to apply a scrollbar in the vertical or horizontal directions. If not
given, these default to vertical only.

If given as the string C<on_demand> then the scrollbar will be optionally be
displayed only if needed; if the space given to the widget is smaller than the
child content necessary to display.

=back

=cut

sub new
{
   my $class = shift;
   my %args = @_;

   my $vertical   = delete $args{vertical} // 1;
   my $horizontal = delete $args{horizontal};

   my $self = $class->SUPER::new( %args );

   $self->{vextent} = Tickit::Widget::ScrollBox::Extent->new( $self ) if $vertical;
   $self->{hextent} = Tickit::Widget::ScrollBox::Extent->new( $self ) if $horizontal;

   $self->{v_on_demand} = $vertical  ||'' eq "on_demand";
   $self->{h_on_demand} = $horizontal||'' eq "on_demand";

   return $self;
}

=head1 ACCESSORS

=cut

sub lines
{
   my $self = shift;
   return $self->child->lines + ( $self->hextent ? 1 : 0 );
}

sub cols
{
   my $self = shift;
   return $self->child->cols + ( $self->vextent ? 1 : 0 );
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

sub _v_visible
{
   my $self = shift;
   return 0 unless my $vextent = $self->{vextent};
   return 1 unless $self->{v_on_demand};
   return $vextent->limit > 0;
}

=head2 $hextent = $scrollbox->hextent

Returns the L<Tickit::Widget::ScrollBox::Extent> object representing the box's
horizontal scrolling extent.

=cut

sub hextent
{
   my $self = shift;
   return $self->{hextent};
}

sub _h_visible
{
   my $self = shift;
   return 0 unless my $hextent = $self->{hextent};
   return 1 unless $self->{h_on_demand};
   return $hextent->limit > 0;
}

=head1 METHODS

=cut

sub reshape
{
   my $self = shift;

   my $window = $self->window or return;
   my $child  = $self->child or return;

   my $vextent = $self->vextent;
   my $hextent = $self->hextent;

   my $v_spare = $child->lines - $window->lines;
   my $h_spare = $child->cols  - $window->cols;

   # visibility of each bar might depend on the visibility of the other, if it
   # it was exactly at limit
   $v_spare++ if $v_spare == 0 and $h_spare > 0;
   $h_spare++ if $h_spare == 0 and $v_spare > 0;

   my $v_visible = $vextent && ( !$self->{v_on_demand} || $v_spare > 0 );
   my $h_visible = $hextent && ( !$self->{h_on_demand} || $h_spare > 0 );

   my @viewportgeom = ( 0, 0,
      $window->lines - ( $h_visible ? 1 : 0 ),
      $window->cols  - ( $v_visible ? 1 : 0 ) );

   my $viewport;
   if( $viewport = $self->{viewport} ) {
      $viewport->change_geometry( @viewportgeom );
   }
   else {
      $viewport = $window->make_sub( @viewportgeom );
      $self->{viewport} = $viewport;
   }

   $vextent->set_viewport( $viewport->lines, $child->lines ) if $vextent;
   $hextent->set_viewport( $viewport->cols,  $child->cols  ) if $hextent;

   my ( $childtop, $childlines ) =
      $vextent ? ( -$vextent->start, $vextent->total )
               : ( 0, max( $child->lines, $viewport->lines ) );

   my ( $childleft, $childcols ) =
      $hextent ? ( -$hextent->start, $hextent->total )
               : ( 0, max( $child->cols, $viewport->cols ) );

   my @childgeom = ( $childtop, $childleft, $childlines, $childcols );

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

=head2 $scrollbox->scroll( $downward, $rightward )

Requests the content be scrolled downward a number of lines and rightward a
number of columns (either of which which may be negative).

=cut

sub scroll
{
   my $self = shift;
   my ( $downward, $rightward ) = @_;
   $self->vextent->scroll( $downward )  if $self->vextent and defined $downward;
   $self->hextent->scroll( $rightward ) if $self->hextent and defined $rightward;
}

=head2 $scrollbox->scroll_to( $top, $left )

Requests the content be scrolled such that the given line and column number of
the child's content is the topmost visible in the container.

=cut

sub scroll_to
{
   my $self = shift;
   my ( $top, $left ) = @_;
   $self->vextent->scroll_to( $top )  if $self->vextent and defined $top;
   $self->hextent->scroll_to( $left ) if $self->hextent and defined $left;
}

sub _extent_scrolled
{
   my $self = shift;

   my $vextent = $self->vextent;
   my $hextent = $self->hextent;

   my $child = $self->child or return;
   my $childwin = $child->window or return;

   $childwin->reposition( $vextent ? -$vextent->start : 0,
                          $hextent ? -$hextent->start : 0 );

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

   my $v_visible = $self->_v_visible;
   my $h_visible = $self->_h_visible;

   if( $v_visible and $rect->right == $cols ) {
      my $vextent = $self->vextent;
      my ( $bar_top, $mark_top, $mark_bottom, $bar_bottom ) =
         $vextent->scrollbar_geom( 1, $lines - 2 - ( $h_visible ? 1 : 0 ) );
      my $start = $vextent->start;

      $rb->text_at (        0, $cols-1,
         $start > 0 ? $self->get_style_values( "arrow_up" ) : " ", $arrow_pen );
      $rb->vline_at( $bar_top, $mark_top-1, $cols-1, LINE_DOUBLE, $scrollbar_pen, CAP_BOTH ) if $mark_top > $bar_top;
      $rb->erase_at(       $_, $cols-1, 1, $scrollmark_pen ) for $mark_top .. $mark_bottom-1;
      $rb->vline_at( $mark_bottom, $bar_bottom-1, $cols-1, LINE_DOUBLE, $scrollbar_pen, CAP_BOTH ) if $bar_bottom > $mark_bottom;
      $rb->text_at ( $bar_bottom, $cols-1,
         $start < $vextent->limit ? $self->get_style_values( "arrow_down" ) : " ", $arrow_pen );
   }

   if( $h_visible and $rect->bottom == $lines ) {
      my $hextent = $self->hextent;

      my ( $bar_left, $mark_left, $mark_right, $bar_right ) =
         $hextent->scrollbar_geom( 1, $cols - 2 - ( $v_visible ? 1 : 0 ) );
      my $start = $hextent->start;

      $rb->goto( $lines-1, 0 );

      $rb->text_at(  $lines-1, 0,
         $start > 0 ? $self->get_style_values( "arrow_left" ) : " ", $arrow_pen );
      $rb->hline_at( $lines-1, $bar_left, $mark_left-1, LINE_DOUBLE, $scrollbar_pen, CAP_BOTH ) if $mark_left > $bar_left;
      $rb->erase_at( $lines-1, $mark_left, $mark_right - $mark_left, $scrollmark_pen );
      $rb->hline_at( $lines-1, $mark_right, $bar_right-1, LINE_DOUBLE, $scrollbar_pen, CAP_BOTH ) if $bar_right > $mark_right;
      $rb->text_at(  $lines-1, $bar_right,
         $start < $hextent->limit ? $self->get_style_values( "arrow_right" ) : " ", $arrow_pen );

      $rb->erase_at( $lines-1, $cols-1, 1 ) if $v_visible;
   }
}

sub key_up_1    { my $vextent = shift->vextent; $vextent->scroll( -1 ) }
sub key_down_1  { my $vextent = shift->vextent; $vextent->scroll( +1 ) }
sub key_left_1  { my $hextent = shift->hextent; $hextent->scroll( -1 ) }
sub key_right_1 { my $hextent = shift->hextent; $hextent->scroll( +1 ) }

sub key_up_half    { my $vextent = shift->vextent; $vextent->scroll( -int( $vextent->viewport / 2 ) ) }
sub key_down_half  { my $vextent = shift->vextent; $vextent->scroll( +int( $vextent->viewport / 2 ) ) }
sub key_left_half  { my $hextent = shift->hextent; $hextent->scroll( -int( $hextent->viewport / 2 ) ) }
sub key_right_half { my $hextent = shift->hextent; $hextent->scroll( +int( $hextent->viewport / 2 ) ) }

sub key_to_top       { my $vextent = shift->vextent; $vextent->scroll_to( 0 ) }
sub key_to_bottom    { my $vextent = shift->vextent; $vextent->scroll_to( $vextent->limit ) }
sub key_to_leftmost  { my $hextent = shift->hextent; $hextent->scroll_to( 0 ) }
sub key_to_rightmost { my $hextent = shift->hextent; $hextent->scroll_to( $hextent->limit ) }

sub on_mouse
{
   my $self = shift;
   my ( $args ) = @_;

   my $type   = $args->type;
   my $button = $args->button;

   my $lines = $self->window->lines;
   my $cols  = $self->window->cols;

   my $vextent = $self->vextent;
   my $hextent = $self->hextent;

   my $vlen = $lines - 2 - ( $self->_h_visible ? 1 : 0 );
   my $hlen = $cols  - 2 - ( $self->_v_visible ? 1 : 0 );

   if( $type eq "press" and $button == 1 ) {
      if( $vextent and $args->col == $cols-1 ) {
         # Click in vertical scrollbar
         my ( undef, $mark_top, $mark_bottom, $bar_bottom ) = $vextent->scrollbar_geom( 1, $vlen );
         my $line = $args->line;

         if( $line == 0 ) { # up arrow
            $vextent->scroll( -1 );
         }
         elsif( $line < $mark_top ) { # above area
            $vextent->scroll( -int( $vextent->viewport / 2 ) );
         }
         elsif( $line < $mark_bottom ) {
            # press in mark - ignore for now - TODO: prelight?
         }
         elsif( $line < $bar_bottom ) { # below area
            $vextent->scroll( +int( $vextent->viewport / 2 ) );
         }
         elsif( $line == $bar_bottom ) { # down arrow
            $vextent->scroll( +1 );
         }
         return 1;
      }
      if( $hextent and $args->line == $lines-1 ) {
         # Click in horizontal scrollbar
         my ( undef, $mark_left, $mark_right, $bar_right ) = $hextent->scrollbar_geom( 1, $hlen );
         my $col = $args->col;

         if( $col == 0 ) { # left arrow
            $hextent->scroll( -1 );
         }
         elsif( $col < $mark_left ) { # above area
            $hextent->scroll( -int( $hextent->viewport / 2 ) );
         }
         elsif( $col < $mark_right ) {
            # press in mark - ignore for now - TODO: prelight
         }
         elsif( $col < $bar_right ) { # below area
            $hextent->scroll( +int( $hextent->viewport / 2 ) );
         }
         elsif( $col == $bar_right ) { # right arrow
            $hextent->scroll( +1 );
         }
         return 1;
      }
   }
   elsif( $type eq "drag_start" and $button == 1 ) {
      if( $vextent and $args->col == $cols-1 ) {
         # Drag in vertical scrollbar
         my ( undef, $mark_top, $mark_bottom ) = $vextent->scrollbar_geom( 1, $vlen );
         my $line = $args->line;

         if( $line >= $mark_top and $line < $mark_bottom ) {
            $self->{drag_offset} = $line - $mark_top;
            $self->{drag_bar}    = "v";
            return 1;
         }
      }
      if( $hextent and $args->line == $lines-1 ) {
         # Drag in horizontal scrollbar
         my ( undef, $mark_left, $mark_right ) = $hextent->scrollbar_geom( 1, $hlen );
         my $col = $args->col;

         if( $col >= $mark_left and $col < $mark_right ) {
            $self->{drag_offset} = $col - $mark_left;
            $self->{drag_bar}    = "h";
            return 1;
         }
      }
   }
   elsif( $type eq "drag" and $button == 1 and defined( $self->{drag_offset} ) ) {
      if( $self->{drag_bar} eq "v" ) {
         my $want_bar_top = $args->line - $self->{drag_offset} - 1;
         my $want_top = int( $want_bar_top * $vextent->total / $vlen + 0.5 );
         $vextent->scroll_to( $want_top );
      }
      if( $self->{drag_bar} eq "h" ) {
         my $want_bar_left = $args->col - $self->{drag_offset} - 1;
         my $want_left = int( $want_bar_left * $hextent->total / $hlen + 0.5 );
         $hextent->scroll_to( $want_left );
      }
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

Choice of left/right and top/bottom bar positions.

=item *

Click-and-hold on arrow buttons for auto-repeat

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
