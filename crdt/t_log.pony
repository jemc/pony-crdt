class ref TLog[
  A: Comparable[A] val,
  T: Comparable[T] val = U64,
  B: (BiasGreater | BiasLesser) = BiasGreater]
  is (Equatable[TLog[A, T, B]] & Convergent[TLog[A, T, B]])
  """
  A sorted list of ordered log entries, each with a value and logical timestamp.
  (U64 by default, though it may be any Comparable immutable type). The list
  of entries is sorted in descending timestamp order (with the most recent
  entries appearing first in the list).

  If the logical timestamp is equal for two compared entries, the sort order
  be determined by the bias type parameter. BiasGreater implies that the greater
  of the two compared values will appear as more recent, while BiasLesser
  implies the opposite. The default bias is BiasGreater. If both the timestamp
  and value properties of the log entries under comparison are equal, they are
  considered duplicates of eachother, and all but one will be discarded.

  A cutoff timestamp is also specified, and all entries whose timestamp is less
  than the cutoff will be discarded. Entries whose timestamps are greater than
  or equal to the cutoff will be retained until the cutoff is updated. Using
  a cutoff timestamp of zero is allowed, and indicates that all entries should
  be retained, allowing the size of the data structure to grow without bound.

  The cutoff timestamp can only ever be increased (always moving forward in
  time, never backward). When reconciling concurrent changes to the cutoff
  timestamp, the higher of the values is retained, preserving this property.

  Because there is a deterministic total order for all entries, conflicts can
  be resolved in a commutative way. Because duplicate entries are discarded,
  updates are idempotent. Because the cutoff timestamp can only ever increase,
  the those conflicts can also be resolved in a commutative, idempotent way.
  Thus, the resulting list of entries is eventually consistent in all replicas.
  The same bias must be used on all replicas for tie results to be consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  let _values: Array[(A, T)] = []
  var _cutoff: T

  new ref create(cutoff': T) =>
    _cutoff = cutoff'

  fun apply(index: USize): (A, T)? =>
    """
    Return the timestamp and value of the log entry at the given index.
    """
    _values(index)?

  fun size(): USize =>
    """
    Return the number of entries currently stored in the log.
    """
    _values.size()

  fun entries(): Iterator[(A, T)]^ =>
    """
    Return an iterator over the timestamp/value entries in the log.
    """
    _values.values()

  fun cutoff(): T =>
    """
    Return the current cutoff timestamp.
    """
    _cutoff

  fun tag _compare(l: (A, T), r: (A, T)): Compare =>
    if     l._2 >  r._2 then Greater
    elseif l._2 <  r._2 then Less
    elseif l._1 == r._1 then Equal
    elseif
      iftype B <: BiasGreater
      then l._1 > r._1
      else l._1 < r._1
      end
    then Greater
    else Less
    end

  fun _rank_of(value': A, timestamp': T): (USize | None) =>
    """
    Use binary search to find the proper index for this new entry.
    Returns None if an equal entry is already present.
    """
    if size() == 0 then return 0 end

    var min = USize(0)
    var max = size() - 1

    try
      while max >= min do
        let index = (min + max) / 2
        match _compare(this(index)?, (value', timestamp'))
        | Greater => min = index + 1
        | Less    => max = index - 1
        | Equal   => return None
        end
      end
    end

    min

  fun _cutoff_pos(timestamp': T): USize =>
    """
    Use binary search to find the leftmost occurrence of a timestamp less than
    the given one.
    """
    if size() == 0 then return 0 end

    var min = USize(0)
    var max = size() - 1

    try
      while max >= min do
        var index = (min + max) / 2
        match this(index)?._2.compare(timestamp')
        | Greater => min = index + 1
        | Less    => max = index - 1
        | Equal   => min = index + 1
        end
      end
    end

    min

  fun ref _write_no_delta(value': A, timestamp': T) =>
    if timestamp' < _cutoff then return end
    try
      let index = _rank_of(value', timestamp') as USize
      _values.insert(index, (value', timestamp'))?
    end

  fun ref _raise_cutoff_no_delta(cutoff': T) =>
    if _cutoff >= cutoff' then return end
    _cutoff = cutoff'

    if size() == 0 then return end
    try if _cutoff < this(size() - 1)?._2 then return end end
    try if _cutoff > this(0)?._2 then return _values.clear() end end

    _values.truncate(_cutoff_pos(cutoff'))

  fun ref write[D: TLog[A, T, B] ref = TLog[A, T, B]](
    value': A,
    timestamp': T,
    delta': (D | None) = None)
  : D^ =>
    """
    Write the value and timestamp to the log, preserving sort order,
    ignoring the write if its timestamp is earlier than the cutoff timestamp.
    """
    _write_no_delta(value', timestamp')

    match consume delta'
    | let delta: D =>
      delta._write_no_delta(value', timestamp')
      consume delta
    else
      recover TLog[A, T, B](_cutoff) .> _write_no_delta(value', timestamp') end
    end

  fun ref raise_cutoff[D: TLog[A, T, B] ref = TLog[A, T, B]](
    cutoff': T,
    delta': (D | None) = None)
  : D^ =>
    """
    Set the cutoff timestamp (only if it higher than the current value).
    All entries earlier than the new cutoff timestamp will be discarded.
    """
    _raise_cutoff_no_delta(cutoff')

    match consume delta'
    | let delta: D =>
      delta._raise_cutoff_no_delta(_cutoff)
      consume delta
    else
      recover TLog[A, T, B](_cutoff) end
    end

  fun ref trim[D: TLog[A, T, B] ref = TLog[A, T, B]](
    n': USize,
    delta': (D | None) = None)
  : D^ =>
    """
    Set the cutoff timestamp to the timestamp of the nth element, so that at
    least n entries will be retained locally, but discarding all entries of
    an earlier timestamp than that of the nth entry. If fewer than n' entries
    are present, the cutoff timestamp will remain unchanged.
    """
    try
      _cutoff = _values(n')?._2
      var n = n' + 1
      while (n = n + 1) < size() do
        if _values(n)?._2 < _cutoff then
          _values.truncate(n)
        end
      end
    end

    match consume delta'
    | let delta: D =>
      delta._raise_cutoff_no_delta(_cutoff)
      consume delta
    else
      recover TLog[A, T, B](_cutoff) end
    end

  fun ref converge(that: TLog[A, T, B] box): Bool =>
    """
    Converge from the given TLog into this one, inserting any new entries,
    ignoring any duplicate entries, and respecting the maximum allowed size.
    Returns true if the convergence added new information to the data structure.
    """
    var changed = false

    if that.cutoff() > _cutoff then
      _raise_cutoff_no_delta(that.cutoff())
      changed = true
    end

    var this_index = USize(0)
    var that_index = USize(0)
    try
      while (this_index < size()) and (that_index < that.size()) do
        let this_pair = this(this_index)?
        let that_pair = that(that_index)?

        if that_pair._2 < _cutoff then break end

        match _compare(this_pair, that_pair)
        | Greater => that_index = that_index - 1 // hold back that_index
        | Less    => changed = true; _values.insert(this_index, that_pair)?
        | Equal   => None
        end

        this_index = this_index + 1
        that_index = that_index + 1
      end

      while that_index < that.size() do
        let that_pair = that(that_index = that_index + 1)?
        if that_pair._2 < _cutoff then break end
        _values.push(that_pair)
        changed = true
      end
    end

    changed

  fun string(): String iso^ =>
    """
    Return a best effort at printing the log. If A and T are Stringable, use
    the string representation of them; otherwise print as question marks.
    """
    let buf = recover String end
    buf.push('[')
    let iter = entries()
    for (value', timestamp') in iter do
      buf.push('(')
      iftype A <: Stringable val then
        buf.append(value'.string())
      else
        buf.push('?')
      end
      buf .> push(',').push(' ')
      iftype T <: Stringable val then
        buf.append(timestamp'.string())
      else
        buf.push('?')
      end
      buf.push(')')
      if iter.has_next() then buf .> push(';').push(' ') end
    end
    buf.push(']')
    consume buf

  fun ne(that: TLog[A, T, B] box): Bool => not eq(that)
  fun eq(that: TLog[A, T, B] box): Bool =>
    let this_iter = this.entries()
    let that_iter = that.entries()
    if this.size() != that.size() then return false end

    try
      while this_iter.has_next() and that_iter.has_next() do
        if _compare(this_iter.next()?, that_iter.next()?) isnt Equal then
          return false
        end
      end
      true
    else
      false
    end
