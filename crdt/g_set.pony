use std = "collections"

type GSet[A: (std.Hashable val & Equatable[A])] is GHashSet[A, std.HashEq[A]]

type GSetIs[A: Any #share] is GHashSet[A, std.HashIs[A]]

class ref GHashSet[A: Any #share, H: std.HashFunction[A] val]
  is (Comparable[GHashSet[A, H]] & Convergent[GHashSet[A, H] box])
  """
  An unordered mutable grow-only set. That is, it only allows insertion.
  
  Because the set is unordered and elements can only be added (never deleted),
  the results are eventually consistent when converged.
  
  All mutator methods accept and return a convergent delta-state.
  """
  embed _data: std.HashSet[A, H]
  
  new ref create() =>
    _data = std.HashSet[A, H]
  
  fun ref _data_set(value: A) => _data.set(value)
  
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
  
  fun ref set(
    value: A,
    delta: GHashSet[A, H] trn = recover GHashSet[A, H] end)
  : GHashSet[A, H] trn^ =>
    """
    Add a value to the set.
    Accepts and returns a convergent delta-state.
    """
    _data.set(value)
    delta._data_set(value)
    delta
  
  fun ref union(
    that: Iterator[A],
    delta: GHashSet[A, H] trn = recover GHashSet[A, H] end)
  : GHashSet[A, H] trn^ =>
    """
    Add everything in the given iterator to the set.
    Accepts and returns a convergent delta-state.
    """
    for value in that do
      _data.set(value)
      delta._data_set(value)
    end
    delta
  
  fun ref converge(that: GHashSet[A, H] box) =>
    """
    Converge from the given GSet into this one.
    For this data type, the convergence is a simple union.
    """
    union(that._data.values())
  
  fun string(): String iso^ =>
    """
    Return a best effort at printing the set. If A is a Stringable, use the
    string representation of each value; otherwise print them as question marks.
    """
    let buf = recover String((size() * 3) + 1) end
    buf.push('%')
    buf.push('{')
    var first = true
    for value in values() do
      if first then first = false else buf .> push(';').push(' ') end
      iftype A <: Stringable val then
        buf.append(value.string())
      else
        buf.push('?')
      end
    end
    buf.push('}')
    consume buf
  
  fun eq(that: GHashSet[A, H] box): Bool => _data.eq(that._data)
  fun ne(that: GHashSet[A, H] box): Bool => _data.ne(that._data)
  fun lt(that: GHashSet[A, H] box): Bool => _data.lt(that._data)
  fun le(that: GHashSet[A, H] box): Bool => _data.le(that._data)
  fun gt(that: GHashSet[A, H] box): Bool => _data.gt(that._data)
  fun ge(that: GHashSet[A, H] box): Bool => _data.ge(that._data)
  fun values(): Iterator[A]^ => _data.values()
