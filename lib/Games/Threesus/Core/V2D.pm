# Stores a 2-dimensional point or displacement in space as two integer values.
package Games::Threesus::Core::V2D;
use v5.14;
use Moo;
use Types::Standard qw(Str Int ArrayRef HashRef);
use strictures 1;
use namespace::clean;

has X => (isa => Int, is => 'rw');
has Y => (isa => Int, is => 'rw');

## Returns whether this IntVector2D is equal to the specified object.
#public override bool Equals(object obj)
#{
#  if(obj is IntVector2D)
#    return Equals((IntVector2D)obj);
#  else
#    return false;
#}
#
## Returns whether this IntVector2D is equal to the specified IntVector2D.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#public bool Equals(IntVector2D v)
#{
#  return X == v.X && Y == v.Y;
#}
#
## Compares this IntVector2D to the specified object.
#int IComparable.CompareTo(object obj)
#{
#  return CompareTo((IntVector2D)obj);
#}
#
## Compares this vector to the specified IntVector2D.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#public int CompareTo(IntVector2D v)
#{
#  int result = X.CompareTo(v.X);
#  if(result != 0)
#    return result;
#  return Y.CompareTo(v.Y);
#}
#
## Returns the hash code for this IntVector2D.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#public override int GetHashCode()
#{
#  unchecked
#  {
#    int hash = 17;
#    hash = hash * 23 + X.GetHashCode();
#    hash = hash * 23 + Y.GetHashCode();
#    return hash;
#  }
#}
#
## Returns an IntVector2D perpendicular to this IntVector2D.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#public IntVector2D Perp()
#{
#  return new IntVector2D(-Y, X);
#}
#
## Returns the string representation of this IntVector2D.
#public override string ToString()
#{
#  return "{X=" + X + ",Y=" + Y + "}";
#}
#
##endregion
##region sub Methods
#
## Computes the dot product of v1 and v2 and returns the resulting value.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub int DotProduct(IntVector2D v1, IntVector2D v2)
#{
#  return v1.X * v2.X + v1.Y * v2.Y;
#}
#
## Computes the cross product of v1 and v2 and returns the resulting value.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub int CrossProduct(IntVector2D v1, IntVector2D v2)
#{
#  return v1.X * v2.Y - v2.X * v1.Y;
#}
#
## Performs a component-wise multiplication of the specified Vectors.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D ComponentMultiply(IntVector2D v1, IntVector2D v2)
#{
#  return new IntVector2D(v1.X * v2.X, v1.Y * v2.Y);
#}
#
##endregion
##region Operators
#
## Returns whether the specified Vectors are equal.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub bool operator ==(IntVector2D v1, IntVector2D v2)
#{
#  return v1.X == v2.X && v1.Y == v2.Y;
#}
#
## Returns whether the specified Vectors are not equal.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub bool operator !=(IntVector2D v1, IntVector2D v2)
#{
#  return v1.X != v2.X || v1.Y != v2.Y;
#}
#
## Returns the summation of the specified vectors.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator +(IntVector2D v1, IntVector2D v2)
#{
#  v1.X += v2.X;
#  v1.Y += v2.Y;
#  return v1;
#}
#
## Returns the subtraction of v2 from v1.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator -(IntVector2D v1, IntVector2D v2)
#{
#  v1.X -= v2.X;
#  v1.Y -= v2.Y;
#  return v1;
#}
#
## Returns the negation of the specified IntVector2D.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator -(IntVector2D v)
#{
#  v.X = -v.X;
#  v.Y = -v.Y;
#  return v;
#}
#
## Returns the component-wise multiplication of the specified IntVector2D and factor.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator *(IntVector2D v, int factor)
#{
#  v.X *= factor;
#  v.Y *= factor;
#  return v;
#}
#
## Returns the component-wise multiplication of the specified factor and IntVector2D.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator *(int factor, IntVector2D v)
#{
#  v.X *= factor;
#  v.Y *= factor;
#  return v;
#}
#
## Returns the component-wise division of the specified IntVector2D numerator by the specified denominator.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator /(IntVector2D v, int denominator)
#{
#  v.X /= denominator;
#  v.Y /= denominator;
#  return v;
#}
#
## Returns the component-wise division of the specified numerator by the specified IntVector2D denominator.
#[MethodImpl(MethodImplOptions.AggressiveInlining)]
#sub IntVector2D operator /(int numerator, IntVector2D v)
#{
#  v.X = numerator / v.X;
#  v.Y = numerator / v.Y;
#  return v;
#}

1;
# vi:ai:et:sw=2 ts=2

