#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2013 -- leonerd@leonerd.org.uk

package Tickit::Widget::ScrollBox::Extent;

use strict;
use warnings;

our $VERSION = '0.03';

use Scalar::Util qw( weaken );

=head1 NAME

C<Tickit::Widget::ScrollBox::Extent> - represents the range of scrolling extent

=head1 DESCRIPTION

This small utility object stores the effective scrolling range for a
L<Tickit::Widget::ScrollBox>. They are not constructed directly, but instead
returned by the C<vextent> method of the associated ScrollBox.

=cut

sub new
{
   my $class = shift;
   my ( $scrollbox, $id ) = @_;

   my $self = bless {
      start => 0,
      id    => $id,
   }, $class;

   weaken( $self->{scrollbox} = $scrollbox );
   return $self;
}

# Internal; used by T:W:ScrollBox
sub set_viewport
{
   my $self = shift;
   my ( $viewport, $total ) = @_;

   $total = $viewport if $viewport > $total;

   $self->{viewport} = $viewport;
   $self->{total}    = $total;

   my $limit = $total - $viewport;
   $self->{start} = $limit if $self->{start} > $limit;
}

=head1 ACCESSORS

=cut

=head2 $viewport = $extent->viewport

Returns the size of the viewable portion of the scrollable area (the
"viewport").

=cut

sub viewport
{
   my $self = shift;
   return $self->{viewport};
}

=head2 $total = $extent->total

Returns the total size of the scrollable area; which is always at least the
size of the viewport.

=cut

sub total
{
   my $self = shift;
   return $self->{total};
}

=head2 $limit = $extent->limit

Returns the limit of the offset; the largest value the start offset may be.
This is simply C<$total - $viewport>.

=cut

sub limit
{
   my $self = shift;
   return $self->{total} - $self->{viewport};
}

=head2 $start = $extent->start

Returns the start position offset of the viewport within the total area. This
is always at least zero, and no greater than the limit.

=cut

sub start
{
   my $self = shift;
   return $self->{start};
}

=head1 METHODS

=cut

=head2 $extent->scroll( $delta )

Requests to move the start by the amount given. This will be clipped if it
moves outside the allowed range.

=cut

sub scroll
{
   my $self = shift;
   $self->scroll_to( $self->start + $_[0] );
}

=head2 $extent->scroll_to( $new_start )

Requests to move the start to that given. This will be clipped if it is
outside the allowed range.

=cut

sub scroll_to
{
   my $self = shift;
   my ( $start ) = @_;

   $start = 0 if $start < 0;
   my $limit = $self->limit;
   $start = $limit if $start > $limit;

   return if $self->{start} == $start;

   my $delta = $start - $self->{start};

   $self->{start} = $start;
   $self->{scrollbox}->_extent_scrolled( $self->{id}, $delta, $start );
}

=head2 ( $bar_top, $mark_top, $mark_bottom, $bar_bottom ) = $extent->scrollbar_geom( $top, $length )

Calculates the start and end positions of a scrollbar and the mark within it
to represent the position of the extent. Returns four integer indexes within
C<$length>.

=cut

sub scrollbar_geom
{
   my $self = shift;
   my ( $top, $length ) = @_;

   my $total = $self->total;

   my $bar_length = int( $self->viewport * $length / $total + 0.5 );
   $bar_length = 1 if $bar_length < 1;

   my $bar_start = $top + int( $self->start * $length / $total + 0.5 );

   return ( $top, $bar_start, $bar_start + $bar_length, $top + $length );
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
