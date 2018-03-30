use "collections"

type TSet[
  A: (Hashable val & Equatable[A]),
  T: Comparable[T] val = U64,
  B: (BiasInsert | BiasDelete) = BiasInsert]
  is THashSet[A, T, B, HashEq[A]]

type TSetIs[
  A: (Hashable val & Equatable[A]),
  T: Comparable[T] val = U64,
  B: (BiasInsert | BiasDelete) = BiasInsert]
  is THashSet[A, T, B, HashIs[A]]

class ref THashSet[
  A: Any #share,
  T: Comparable[T] val,
  B: (BiasInsert | BiasDelete),
  H: HashFunction[A] val]
  is
  ( Comparable[THashSet[A, T, B, H]]
  & Convergent[THashSet[A, T, B, H]] )
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
  The default bias is BiasInsert.

  Because the set is composed of two grow-only sets that are eventually
  consistent when converged, the overall result is also eventually consistent.
  The same bias must be used on all replicas for tie results to be consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  embed _data: HashMap[A, (T, Bool), H]

  new ref create() =>
    _data = HashMap[A, (T, Bool), H]

  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    result().size()

  fun apply(value: val->A): T ? =>
    """
    Return the logical timestamp if it's in the set, otherwise raise an error.
    """
    (let timestamp, let present) = _data(value)?
    if not present then error end
    timestamp

  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    _data.contains(value) and (try _data(value)? else return false end)._2

  fun ref _set_no_delta(value: A, timestamp: T): Bool =>
    try
      (let current_timestamp, let current_status) = _data(value)?
      if timestamp < current_timestamp then return false end
      iftype B <: BiasDelete then
        if (timestamp == current_timestamp) then return false end
      end
      if (timestamp == current_timestamp) and (current_status == true) then
        return false
      end
    end
    _data(value) = (timestamp, true)
    true

  fun ref _unset_no_delta(value: box->A!, timestamp: T): Bool =>
    try
      (let current_timestamp, let current_status) = _data(value)?
      if timestamp < current_timestamp then return false end
      iftype B <: BiasInsert then
        if (timestamp == current_timestamp) then return false end
      end
      if (timestamp == current_timestamp) and (current_status == false) then
        return false
      end
    end
    _data(value) = (timestamp, false)
    true

  fun ref clear[D: THashSet[A, T, B, H] ref = THashSet[A, T, B, H]](
    timestamp: T,
    delta: D = recover THashSet[A, T, B, H] end)
  : D^ =>
    """
    Remove all elements from the set.
    Accepts and returns a convergent delta-state.
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

  fun ref set[D: THashSet[A, T, B, H] ref = THashSet[A, T, B, H]](
    value: A,
    timestamp: T,
    delta: D = recover THashSet[A, T, B, H] end)
  : D^ =>
    """
    Add a value to the set.
    Accepts and returns a convergent delta-state.
    """
    _set_no_delta(value, timestamp)
    delta._set_no_delta(value, timestamp)
    consume delta

  fun ref unset[D: THashSet[A, T, B, H] ref = THashSet[A, T, B, H]](
    value: box->A!,
    timestamp: T,
    delta: D = recover THashSet[A, T, B, H] end)
  : D^ =>
    """
    Remove a value from the set.
    Accepts and returns a convergent delta-state.
    """
    _unset_no_delta(value, timestamp)
    delta._unset_no_delta(value, timestamp)
    consume delta

  fun ref union[D: THashSet[A, T, B, H] ref = THashSet[A, T, B, H]](
    that: Iterator[(A, T)],
    delta: D = recover THashSet[A, T, B, H] end)
  : D^ =>
    """
    Add everything in the given iterator to the set.
    Accepts and returns a convergent delta-state.
    """
    for (value, timestamp) in that do
      _set_no_delta(value, timestamp)
      delta._set_no_delta(value, timestamp)
    end
    consume delta

  fun ref converge(that: THashSet[A, T, B, H] box): Bool =>
    """
    Converge from the given TSet into this one.
    For this data type, the convergence is the union of both constituent sets.
    Returns true if the convergence added new information to the data structure.
    """
    var changed = false
    for (value, (timestamp, present)) in that._data.pairs() do
      let this_value_changed =
        if present
        then _set_no_delta(value, timestamp)
        else _unset_no_delta(value, timestamp)
        end
      changed = changed or this_value_changed
    end
    changed

  fun result(): HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    var out = HashSet[A, H]
    for (value, (timestamp, present)) in _data.pairs() do
      if present then out.set(value) end
    end
    out

  fun map(): HashMap[A, T, H] =>
    """
    Return the elements of the resulting logical set as a single flat map, with
    the elements as keys and logical timestamps of the insertion as timestamps.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    var out = HashMap[A, T, H]
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

  // TODO: optimize comparison functions:
  fun eq(that: THashSet[A, T, B, H] box): Bool => result().eq(that.result())
  fun ne(that: THashSet[A, T, B, H] box): Bool => result().ne(that.result())
  fun lt(that: THashSet[A, T, B, H] box): Bool => result().lt(that.result())
  fun le(that: THashSet[A, T, B, H] box): Bool => result().le(that.result())
  fun gt(that: THashSet[A, T, B, H] box): Bool => result().gt(that.result())
  fun ge(that: THashSet[A, T, B, H] box): Bool => result().ge(that.result())
  fun values(): Iterator[A]^     => result().values()
  fun timestamps(): Iterator[T]^ => map().values()
  fun pairs(): Iterator[(A, T)]^ => map().pairs()
