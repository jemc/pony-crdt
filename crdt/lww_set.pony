use mut = "collections"
use std = "collections/persistent"

type LWWSet[
  A: (mut.Hashable val & Equatable[A]),
  T: Comparable[T] val = U64,
  B: (BiasInsert | BiasDelete) = BiasInsert]
  is LWWHashSet[A, T, B, mut.HashEq[A]]

type LWWSetIs[
  A: (mut.Hashable val & Equatable[A]),
  T: Comparable[T] val = U64,
  B: (BiasInsert | BiasDelete) = BiasInsert]
  is LWWHashSet[A, T, B, mut.HashIs[A]]

class ref LWWHashSet[
  A: Any #share,
  T: Comparable[T] val,
  B: (BiasInsert | BiasDelete),
  H: mut.HashFunction[A] val]
  is (Comparable[LWWHashSet[A, T, B, H]] & Convergent[LWWHashSet[A, T, B, H]])
  """
  A mutable set with last-write-wins semantics for insertion and deletion.
  That is, every insertion and deletion operation includes a logical timestamp
  (U64 by default, though it may be any Comparable immutable type), and
  operations are overridden only by those with a higher logical timestamp.
  
  This implies that the timestamps must be correct (or at least logically so)
  in order for the last-write-wins semantics to hold true.
  
  This data structure is based on two grow-only sets (GSet); one for insertions
  and one for deletions. Both sets include the logical timestamp for each
  element. An element is present in the combined logical set if it is present
  in only the insertion set (not in the deletion set), or if the logical
  timestamp of the insertion is higher than that of the deletion.
  
  If the logical timestamp is equal for two compared operations, the tie will
  be broken by the bias type parameter. BiasInsert implies that inserts will
  override deletions in a tie, while BiasDelete implies the opposite.
  
  When a new element of the internal set shadows an older element (by having a
  higher logical timestamp) of the same type (both insertions or both deletions)
  the shadowed element can be safely pruned from memory without losing any
  convergence guarantees of the data structure, because there is no operation
  that can ever remove the shadowing element or lift them out of the shadow.
  
  Because the set is composed of two grow-only sets that are eventually
  consistent when converged, the overall result is also eventually consistent.
  The same bias must be used on all replicas for tie results to be consistent.
  """
  var _ins: std.HashMap[A, T, H]
  var _del: std.HashMap[A, T, H]
  
  new ref create() =>
    _ins = std.HashMap[A, T, H]
    _del = std.HashMap[A, T, H]
  
  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    result().size()
  
  fun apply(value: val->A): T ? =>
    """
    Return the logical timestamp if it's in the set, otherwise raise an error.
    """
    let timestamp = _ins(value)
    let present =
      iftype B <: BiasInsert then
        (try timestamp >= _del(value) else true end)
      else
        (try timestamp > _del(value) else true end)
      end
    if not present then error end
    timestamp
  
  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    iftype B <: BiasInsert then
      (try _ins(value) else return false end) >=
      (try _del(value) else return true end)
    else
      (try _ins(value) else return false end) >
      (try _del(value) else return true end)
    end
  
  fun ref clear() =>
    """
    Remove all elements from the set.
    """
    for (value, timestamp) in _ins.pairs() do unset(value, timestamp) end
  
  fun ref set(value: A, timestamp: T) =>
    """
    Add a value to the set.
    """
    if (try _ins(value) < timestamp else true end) then
      _ins = _ins.update(value, timestamp)
    end
  
  fun ref unset(value: box->A!, timestamp: T) =>
    """
    Remove a value from the set.
    """
    if (try _del(value) < timestamp else true end) then
      _del = _del.update(value, timestamp)
    end
  
  fun ref extract(value: box->A!): A^ ? =>
    """
    Remove a value from the set and return it. Raises an error if the value
    wasn't in the set.
    """
    apply(value)
    value
  
  fun ref union(that: Iterator[(A, T)]) =>
    """
    Add everything in the given iterator to the set.
    """
    for (value, timestamp) in that do
      set(consume value, timestamp)
    end
  
  fun ref converge(that: LWWHashSet[A, T, B, H]) =>
    """
    Converge from the given pair of persistent HashMaps into this set.
    For this data type, the convergence is the union of both constituent sets.
    """
    for (value, timestamp) in that._ins.pairs() do set(value, timestamp) end
    for (value, timestamp) in that._del.pairs() do unset(value, timestamp) end
  
  fun result(): std.HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    var out = std.HashSet[A, H]
    for (value, timestamp) in _ins.pairs() do
      let present =
        iftype B <: BiasInsert then
          (try _del(value) <= timestamp else true end)
        else
          (try _del(value) < timestamp else true end)
        end
      if present then out = out + value end
    end
    out
  
  fun map(): std.HashMap[A, T, H] =>
    """
    Return the elements of the resulting logical set as a single flat map, with
    the elements as keys and logical timestamps of the insertion as timestamps.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    var out = std.HashMap[A, T, H]
    for (value, timestamp) in _ins.pairs() do
      let present =
        iftype B <: BiasInsert then
          (try _del(value) <= timestamp else true end)
        else
          (try _del(value) < timestamp else true end)
        end
      if present then out = out.update(value, timestamp) end
    end
    out
  
  fun string(): String iso^ =>
    """
    Return a best effort at printing the set. If A is a Stringable box, use the
    string representation of each value; otherwise print the as question marks.
    """
    let buf = recover String((size() * 6) + 1) end
    buf.push('%')
    buf.push('{')
    var first = true
    for (value, timestamp) in pairs() do
      if first then first = false else buf .> push(';').push(' ') end
      iftype A <: Stringable val then
        buf.append(value.string())
      else
        buf.push('?')
      end
      buf .> push(',').push(' ')
      iftype T <: Stringable val then
        buf.append(timestamp.string())
      else
        buf.push('?')
      end
    end
    buf.push('}')
    consume buf
  
  fun eq(that: LWWHashSet[A, T, B, H] box): Bool => result().eq(that.result())
  fun ne(that: LWWHashSet[A, T, B, H] box): Bool => result().ne(that.result())
  fun lt(that: LWWHashSet[A, T, B, H] box): Bool => result().lt(that.result())
  fun le(that: LWWHashSet[A, T, B, H] box): Bool => result().le(that.result())
  fun gt(that: LWWHashSet[A, T, B, H] box): Bool => result().gt(that.result())
  fun ge(that: LWWHashSet[A, T, B, H] box): Bool => result().ge(that.result())
  fun values(): Iterator[A]^     => result().values()
  fun timestamps(): Iterator[T]^ => map().values()
  fun pairs(): Iterator[(A, T)]^ => map().pairs()
