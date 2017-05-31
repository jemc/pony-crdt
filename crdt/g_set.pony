use mut = "collections"
use std = "collections/persistent"

type GSet[A: (mut.Hashable val & Equatable[A])] is GHashSet[A, mut.HashEq[A]]

type GSetIs[A: Any #share] is GHashSet[A, mut.HashIs[A]]

class ref GHashSet[A: Any #share, H: mut.HashFunction[A] val]
  is (Comparable[GHashSet[A, H]] & Convergent[std.HashSet[A, H]])
  """
  An unordered mutable grow-only set. That is, it only allows insertion.
  
  Because the set is unordered and elements can only be added (never deleted),
  the results are eventually consistent when converged.
  """
  var _data: std.HashSet[A, H]
  
  new ref create() =>
    _data = std.HashSet[A, H]
  
  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    _data.size()
  
  fun apply(value: val->A): val->A ? =>
    """
    Return the value if it's in the set, otherwise raise an error.
    """
    _data(value)
  
  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    _data.contains(value)
  
  fun ref set(value: A) =>
    """
    Add a value to the set.
    """
    _data = _data + value
  
  fun ref union(that: Iterator[A]) =>
    """
    Add everything in the given iterator to the set.
    """
    for value in that do
      set(consume value)
    end
  
  fun data(): std.HashSet[A, H] =>
    """
    Return the underlying data, for replicating/converging with other instances.
    """
    _data
  
  fun ref converge(data': std.HashSet[A, H]) =>
    """
    Converge from the given persistent HashSet into this one.
    For this convergent replicated data type, the convergence is a simple union.
    """
    union(data'.values())
  
  fun string(): String iso^ =>
    """
    Return a best effort at printing the set. If A is a Stringable box, use the
    string representation of each value; otherwise print the as question marks.
    """
    let buf = recover String((size() * 3) + 1) end
    buf.push('%')
    buf.push('{')
    var first = true
    for value in _data.values() do
      if first then first = false else buf .> push(';').push(' ') end
      iftype A <: Stringable val then
        buf.append(value.string())
      else
        buf.push('?')
      end
    end
    buf.push('}')
    consume buf
  
  fun eq(that: GHashSet[A, H] box): Bool => _data.eq(that.data())
  fun ne(that: GHashSet[A, H] box): Bool => _data.ne(that.data())
  fun lt(that: GHashSet[A, H] box): Bool => _data.lt(that.data())
  fun le(that: GHashSet[A, H] box): Bool => _data.le(that.data())
  fun gt(that: GHashSet[A, H] box): Bool => _data.gt(that.data())
  fun ge(that: GHashSet[A, H] box): Bool => _data.ge(that.data())
  fun values(): Iterator[A]^ => _data.values()
