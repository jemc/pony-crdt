use std = "collections"

type P2Set[A: (std.Hashable val & Equatable[A])] is P2HashSet[A, std.HashEq[A]]

type P2SetIs[A: Any #share] is P2HashSet[A, std.HashIs[A]]

class ref P2HashSet[A: Any #share, H: std.HashFunction[A] val]
  is (Comparable[P2HashSet[A, H]] & Convergent[P2HashSet[A, H]])
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

  All mutator methods accept and return a convergent delta-state.
  """
  embed _ins: std.HashSet[A, H]
  embed _del: std.HashSet[A, H]

  new ref create() =>
    _ins = std.HashSet[A, H]
    _del = std.HashSet[A, H]

  fun ref _ins_set(value: A) => _ins.set(value)
  fun ref _del_set(value: A) => _del.set(value)

  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    result().size()

  fun apply(value: val->A): val->A ? =>
    """
    Return the value if it's in the set, otherwise raise an error.
    """
    if _del.contains(value) then error else _ins(value)? end

  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    _ins.contains(value) and not _del.contains(value)

  fun ref clear() =>
    """
    Remove all elements from the set.
    """
    _del.union(_ins.values())
    _ins.clear() // not strictly necessary, but reduces memory footprint

  fun ref set[D: P2HashSet[A, H] ref = P2HashSet[A, H]](
    value: A,
    delta: D = recover P2HashSet[A, H] end)
  : D^ =>
    """
    Add a value to the set.
    Accepts and returns a convergent delta-state.
    """
    if not _del.contains(value) then
      _ins.set(value)
      delta._ins_set(value)
    end
    consume delta

  fun ref unset[D: P2HashSet[A, H] ref = P2HashSet[A, H]](
    value: A,
    delta: D = recover P2HashSet[A, H] end)
  : D^ =>
    """
    Remove a value from the set.
    Accepts and returns a convergent delta-state.
    """
    // TODO: Reduce memory footprint by also removing from _ins set?
    _ins.unset(value) // not strictly necessary, but reduces memory footprint
    _del.set(value)
    delta._del_set(value)
    consume delta

  fun ref union[D: P2HashSet[A, H] ref = P2HashSet[A, H]](
    that: Iterator[A],
    delta: D = recover P2HashSet[A, H] end)
  : D^ =>
    """
    Add everything in the given iterator to the set.
    Accepts and returns a convergent delta-state.
    """
    var delta' = consume delta
    for value in that do
      delta' = set[D](value, consume delta')
    end
    consume delta'

  fun ref converge(that: P2HashSet[A, H] box): Bool =>
    """
    Converge from the given P2Set into this one.
    For this data type, the convergence is the union of both constituent sets.
    Returns true if the convergence added new information to the data structure.
    """
    let orig_size = _ins.size() + _del.size()
    // TODO: deal with cases where we want _ins to be deleted.
    _ins.union(that._ins.values())
    _del.union(that._del.values())
    orig_size != (_ins.size() + _del.size())

  fun result(): std.HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    _ins.without(_del)

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

  fun eq(that: P2HashSet[A, H] box): Bool => result().eq(that.result())
  fun ne(that: P2HashSet[A, H] box): Bool => result().ne(that.result())
  fun lt(that: P2HashSet[A, H] box): Bool => result().lt(that.result())
  fun le(that: P2HashSet[A, H] box): Bool => result().le(that.result())
  fun gt(that: P2HashSet[A, H] box): Bool => result().gt(that.result())
  fun ge(that: P2HashSet[A, H] box): Bool => result().ge(that.result())
  fun values(): Iterator[A]^ => result().values()
