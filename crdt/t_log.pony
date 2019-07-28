use "_private"

class ref TLog[
  A: Comparable[A] val,
  T: (Integer[T] & Unsigned) = U64,
  B: (BiasGreater | BiasLesser) = BiasGreater]
  is (Equatable[TLog[A, T, B]] & Convergent[TLog[A, T, B]] & Replicated)
  """
  A sorted list of ordered log entries, each with a value and logical timestamp.
  (U64 by default, though it may be any unsigned integer type). The list of
  entries is sorted in descending timestamp order (with the most recent entries
  appearing first in the list).

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
  var _cutoff: T             = T.from[U8](0)
  let _checklist: (DotChecklist | None)

  new ref create() =>
    _checklist = None

  new ref _create_in(ctx: DotContext) =>
    _checklist = DotChecklist(ctx)

  fun ref _checklist_write() =>
    match _checklist | let c: DotChecklist => c.write() end

  fun ref _converge_empty_in(ctx: DotContext box): Bool => // ignore the context
    false

  fun is_empty(): Bool =>
    """
    Return true if the data structure contains no information (bottom state).
    """
    (_values.size() == 0) and (_cutoff == T.from[U8](0))

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
    // Optimize for the common case of this new entry being the latest one.
    try
      match _compare(this(0)?, (value', timestamp'))
      | Equal   => return None // this entry already exists
      | Less    => return 0    // this new entry belongs at the head
      | Greater => None        // this new entry belongs somewhere else
      end
    else return 0
    end

    // Do a binary search over the remainder of the range to find the index.
    var min = USize(1)
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
    delta': D = D)
  : D^ =>
    """
    Write the value and timestamp to the log, preserving sort order,
    ignoring the write if its timestamp is earlier than the cutoff timestamp.
    """
    _write_no_delta(value', timestamp')
    _checklist_write()

    delta'
      .> _raise_cutoff_no_delta(_cutoff)
      .> _write_no_delta(value', timestamp')

  fun ref raise_cutoff[D: TLog[A, T, B] ref = TLog[A, T, B]](
    cutoff': T,
    delta': D = D)
  : D^ =>
    """
    Set the cutoff timestamp (only if it higher than the current value).
    All entries earlier than the new cutoff timestamp will be discarded.
    """
    _raise_cutoff_no_delta(cutoff')
    _checklist_write()

    delta' .> _raise_cutoff_no_delta(_cutoff)

  fun ref trim[D: TLog[A, T, B] ref = TLog[A, T, B]](
    n': USize,
    delta': D = D)
  : D^ =>
    """
    Set the cutoff timestamp to the timestamp of the nth element, so that at
    least n' entries will be retained locally, but discarding all entries of
    an earlier timestamp than that of the nth entry. If fewer than n' entries
    are present, the cutoff timestamp will remain unchanged. If n' is zero, the
    effect is the same as calling the clear method.
    """
    if n' == 0 then return clear(delta') end

    try
      _cutoff = _values(n' - 1)?._2
      _checklist_write()
      var n = n' - 1
      while (n = n + 1) < size() do
        if _values(n)?._2 < _cutoff then
          _values.truncate(n)
        end
      end
    end

    delta' .> _raise_cutoff_no_delta(_cutoff)

  fun ref clear[D: TLog[A, T, B] ref = TLog[A, T, B]](delta': D = D): D^ =>
    """
    Raise the cutoff timestamp to be the timestamp of the latest entry plus one,
    such that all local entries in the log will be discarded due to having
    timestamps earlier than the cutoff timestamp. If there are no entries in
    the local log, this method will have no effect.
    """
    try
      _cutoff = _values(0)?._2 + T.from[U8](1)
      _values.clear()
    end

    delta' .> _raise_cutoff_no_delta(_cutoff)

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

  fun ref from_tokens(that: TokensIterator)? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    var count = that.next[USize]()?

    if count < 1 then error end
    count = count - 1
    _cutoff = that.next[T]()?

    if (count % 2) != 0 then error end
    count = count / 2

    // TODO: _values.reserve(count)
    while (count = count - 1) > 0 do
      _values.push((that.next[A]()?, that.next[T]()?))
    end

  fun ref each_token(tokens: Tokens) =>
    """
    Serialize the data structure, capturing each token into the given Tokens.
    """
    tokens.push(1 + (_values.size() * 2))
    tokens.push(_cutoff)
    for (v, t) in _values.values() do
      tokens.push(v)
      tokens.push(t)
    end
