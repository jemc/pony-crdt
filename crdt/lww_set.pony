use std = "collections"

type LWWSet[
  A: (std.Hashable val & Equatable[A]),
  T: Comparable[T] val = U64,
  B: (BiasInsert | BiasDelete) = BiasInsert]
  is LWWHashSet[A, T, B, std.HashEq[A]]

type LWWSetIs[
  A: (std.Hashable val & Equatable[A]),
  T: Comparable[T] val = U64,
  B: (BiasInsert | BiasDelete) = BiasInsert]
  is LWWHashSet[A, T, B, std.HashIs[A]]

class ref LWWHashSet[
  A: Any #share,
  T: Comparable[T] val,
  B: (BiasInsert | BiasDelete),
  H: std.HashFunction[A] val]
  is
  ( Comparable[LWWHashSet[A, T, B, H]]
  & Convergent[LWWHashSet[A, T, B, H] box] )
  """
  A mutable set with last-write-wins semantics for insertion and deletion.
  That is, every insertion and deletion operation includes a logical timestamp
  (U64 by default, though it may be any Comparable immutable type), and
  operations are overridden only by those with a higher logical timestamp.
  
  This implies that the timestamps must be correct (or at least logically so)
  in order for the last-write-wins semantics to hold true.
  
  This data structure is conceptually composed of two grow-only sets (GSet);
  one for insertions and one for deletions. Both sets include the logical
  timestamp for each element. An element is present in the combined logical set
  if it is present in only the insertion set (not in the deletion set), or if
  the logical timestamp of the insertion is higher than that of the deletion.
  
  The actual implementation is a bit more memory-optimized than a literal pair
  of GSets - it stores the data as a map with the elements as keys and each
  value being a 2-tuple with the highest logical timestamp so far and a boolean
  indicating whether that timestamp represents an insertion or a deletion.
  
  If the logical timestamp is equal for two compared operations, the tie will
  be broken by the bias type parameter. BiasInsert implies that inserts will
  override deletions in a tie, while BiasDelete implies the opposite.
  
  Because the set is composed of two grow-only sets that are eventually
  consistent when converged, the overall result is also eventually consistent.
  The same bias must be used on all replicas for tie results to be consistent.
  """
  embed _data: std.HashMap[A, (T, Bool), H]
  
  new ref create() =>
    _data = std.HashMap[A, (T, Bool), H]
  
  fun ref _data_update(value: A, status: (T, Bool)) => _data(value) = status
  
  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    result().size()
  
  fun apply(value: val->A): T ? =>
    """
    Return the logical timestamp if it's in the set, otherwise raise an error.
    """
    (let timestamp, let present) = _data(value)
    if not present then error end
    timestamp
  
  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    _data.contains(value) and (try _data(value) else return false end)._2
  
  fun ref _set_no_delta(value: A, timestamp: T) =>
    try
      (let current_timestamp, let _) = _data(value)
      if timestamp < current_timestamp then return end
      iftype B <: BiasDelete then
        if (timestamp == current_timestamp) then return end
      end
    end
    _data(value) = (timestamp, true)
  
  fun ref _unset_no_delta(value: box->A!, timestamp: T) =>
    try
      (let current_timestamp, let _) = _data(value)
      if timestamp < current_timestamp then return end
      iftype B <: BiasInsert then
        if (timestamp == current_timestamp) then return end
      end
    end
    _data(value) = (timestamp, false)
  
  fun ref clear(
    timestamp: T,
    delta: LWWHashSet[A, T, B, H] trn = recover LWWHashSet[A, T, B, H] end)
  : LWWHashSet[A, T, B, H] trn^ =>
    """
    Remove all elements from the set.
    """
    // TODO: save memory and have stronger consistency by setting a "cleared"
    // timestamp internally, removing all entries older than this timestamp,
    // and testing against that timestamp before receiving any new entries.
    // This timestamp could also be "raised" in a periodic garbage collection
    // to shrink the memory footprint of the state without losing information.
    // Note that this timestamp will need to be part of the replicated state.
    // When this feature is added, it should be noted in the dosctring for this
    // data type that the memory usage is not grow-only, which is a highly
    // desirable feature that we want to highlight wherever we can.
    for value in _data.keys() do
      _unset_no_delta(value, timestamp)
      delta._unset_no_delta(value, timestamp)
    end
    consume delta
  
  fun ref set(
    value: A,
    timestamp: T,
    delta: LWWHashSet[A, T, B, H] trn = recover LWWHashSet[A, T, B, H] end)
  : LWWHashSet[A, T, B, H] trn^ =>
    """
    Add a value to the set.
    """
    _set_no_delta(value, timestamp)
    delta._set_no_delta(value, timestamp)
    consume delta
  
  fun ref unset(
    value: box->A!,
    timestamp: T,
    delta: LWWHashSet[A, T, B, H] trn = recover LWWHashSet[A, T, B, H] end)
  : LWWHashSet[A, T, B, H] trn^ =>
    """
    Remove a value from the set.
    """
    _unset_no_delta(value, timestamp)
    delta._unset_no_delta(value, timestamp)
    consume delta
  
  fun ref union(
    that: Iterator[(A, T)],
    delta: LWWHashSet[A, T, B, H] trn = recover LWWHashSet[A, T, B, H] end)
  : LWWHashSet[A, T, B, H] trn^ =>
    """
    Add everything in the given iterator to the set.
    """
    for (value, timestamp) in that do
      _set_no_delta(value, timestamp)
      delta._set_no_delta(value, timestamp)
    end
    consume delta
  
  fun ref converge(that: LWWHashSet[A, T, B, H] box) =>
    """
    Converge from the given LWWSet into this one.
    For this data type, the convergence is the union of both constituent sets.
    """
    for (value, (timestamp, present)) in that._data.pairs() do
      if present
      then _set_no_delta(value, timestamp)
      else _unset_no_delta(value, timestamp)
      end
    end
  
  fun result(): std.HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    var out = std.HashSet[A, H]
    for (value, (timestamp, present)) in _data.pairs() do
      if present then out.set(value) end
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
    for (value, (timestamp, present)) in _data.pairs() do
      if present then out(value) = timestamp end
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
