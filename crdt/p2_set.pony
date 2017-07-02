use mut = "collections"
use std = "collections/persistent"

type P2Set[A: (mut.Hashable val & Equatable[A])] is P2HashSet[A, mut.HashEq[A]]

type P2SetIs[A: Any #share] is P2HashSet[A, mut.HashIs[A]]

class ref P2HashSet[A: Any #share, H: mut.HashFunction[A] val]
  is (Comparable[P2HashSet[A, H]] & Convergent[P2HashSet[A, H] box])
  """
  An unordered mutable two-phase set that supports one-time removal.
  That is, once an element has been deleted it may never be inserted again.
  In other words, the deletion is final, and may not be overridden.
  Any attempts to insert an already-deleted element will be silently ignored.
  
  This data structure is based on two grow-only sets (GSet); one for insertions
  and one for deletions. An element is present in the combined logical set if
  it is present in only the insertion set (not in the deletion set).
  
  Because the set is composed of two grow-only sets that are eventually
  consistent when converged, the overall result is also eventually consistent.
  """
  var _ins: std.HashSet[A, H]
  var _del: std.HashSet[A, H]
  
  new ref create() =>
    _ins = std.HashSet[A, H]
    _del = std.HashSet[A, H]
  
  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    result().size()
  
  fun apply(value: val->A): val->A ? =>
    """
    Return the value if it's in the set, otherwise raise an error.
    """
    if _del.contains(value) then error else _ins(value) end
  
  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    _ins.contains(value) and not _del.contains(value)
  
  fun ref clear() =>
    """
    Remove all elements from the set.
    """
    _del = _del or _ins
  
  fun ref set(value: A) =>
    """
    Add a value to the set.
    """
    _ins = _ins + value
  
  fun ref unset(value: box->A!) =>
    """
    Remove a value from the set.
    """
    _del = _del + value
  
  fun ref extract(value: box->A!): A^ ? =>
    """
    Remove a value from the set and return it. Raises an error if the value
    wasn't in the set.
    """
    if _del.contains(value) then error end
    _del = _del + value
    _ins(value)
  
  fun ref union(that: Iterator[A]) =>
    """
    Add everything in the given iterator to the set.
    """
    for value in that do
      set(consume value)
    end
  
  fun ref converge(that: P2HashSet[A, H] box) =>
    """
    Converge from the given pair of persistent HashSets into this set.
    For this data type, the convergence is the union of both constituent sets.
    """
    _ins = _ins or that._ins
    _del = _del or that._del
  
  fun result(): std.HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    _ins.without(_del)
  
  fun string(): String iso^ =>
    """
    Return a best effort at printing the set. If A is a Stringable box, use the
    string representation of each value; otherwise print the as question marks.
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
  
  fun eq(that: P2HashSet[A, H] box): Bool => result().eq(that.result())
  fun ne(that: P2HashSet[A, H] box): Bool => result().ne(that.result())
  fun lt(that: P2HashSet[A, H] box): Bool => result().lt(that.result())
  fun le(that: P2HashSet[A, H] box): Bool => result().le(that.result())
  fun gt(that: P2HashSet[A, H] box): Bool => result().gt(that.result())
  fun ge(that: P2HashSet[A, H] box): Bool => result().ge(that.result())
  fun values(): Iterator[A]^ => result().values()
