use ".."
use "collections"

class ref _DotContext is Convergent[_DotContext]
  """
  This data structure is used internally by DotKernel.
  There shouldn't realy be a reason to use it outside of that context,
  and be aware that if you do, there are unsound patterns of use to avoid.
  See the rest of the docstrings in this file for more information.

  Represents the total set of "dots" received so far in known history,
  where each dot is a unique replica identifier and a sequence number.

  As a memory optimization, we represent that total set in two structures:
  The _complete history and the _dot_cloud. By compacting from _dot_cloud into
  the _complete history, we can avoid letting memory grow without bound,
  as long as any gaps in history eventually get filled by incoming dots.

  The _complete history represents the range of consecutive sequence numbers
  starting with zero that have already been observed for a given replica ID.
  Nothing new can be learned about this region of history.

  The _dot_cloud represents the set of arbitrary (ID, N) pairings which have
  not yet been absorbed into _complete because they are not consecutive.
  When enough dots are accumulated into the _dot_cloud to be consecutive
  with the current threshold of _complete history, they can compacted into it.
  """
  embed _complete:  Map[ID, U32]
  embed _dot_cloud: HashSet[_Dot, _DotHashFn]

  new ref create() =>
    _complete  = _complete.create()
    _dot_cloud = _dot_cloud.create()

  fun contains(dot: _Dot): Bool =>
    """
    Test if the given dot has been received yet in this causal history.
    """
    (_complete.get_or_else(dot._1, 0) >= dot._2) or _dot_cloud.contains(dot)

  fun ref compact() =>
    """
    Reduce memory footprint by absorbing as many members of the _dot_cloud set
    as possible into the _complete.

    Dots which represent the next sequence number for a known ID are moved into
    the _complete by incrementing the sequence number for that ID. Every
    missing ID in the _complete is treated as zero, with the next sequence
    number expected being one.

    Dots that are already present or outdated in the _complete (those whose
    sequence numbers are less than or equal to the known number for the same ID)
    are discarded.

    All other dots are kept in the _dot_cloud.

    The compaction operation does not lose any information.
    """
    var keep_compacting = true
    while keep_compacting do
      keep_compacting = false

      let remove_dots = Array[_Dot]
      for dot in _dot_cloud.values() do
        (let id, let n) = dot
        let n' = _complete.get_or_else(id, 0)

        if n == (n' + 1) then // this dot has the next sequence number
          _complete(id) = n
          remove_dots.push(dot)
          keep_compacting = true
        elseif n <= n' then // this dot is present/outdated
          remove_dots.push(dot)
        end
      end
      _dot_cloud.remove(remove_dots.values())
    end

  fun ref next_dot(id: ID): _Dot =>
    """
    Update the _complete with the next sequence number for the given ID,
    also returning the resulting dot.

    WARNING: This is only valid when there are no dots for it in _dot_cloud,
    meaning that this should only be used with the id of the local replica,
    and any `set` calls with `compact_now = false` must be followed `compact`
    before calling this function.

    In the future, we want to consider refactoring this abstraction to make
    it more difficult to make a mistake that breaks these assumptions, using
    Pony idioms of having the type system prevent you from doing unsafe actions.
    """
    // TODO: consider the refactor mentioned in the docstring.
    let n = try _complete.upsert(id, 1, {(n', _) => n' + 1 })? else 1 end
    (id, n)

  fun ref set(dot: _Dot, compact_now: Bool = true) =>
    """
    Add the given dot into the causal history represented here.

    If compact_now is set to false, auto-compaction will be skipped.
    This is useful for optimizing sites where `set` is called many times, but
    proceed with care, because operations like `next_dot` depend on compaction;
    make sure `compact` is called after any such optimized group of `set` calls.
    """
    _dot_cloud.set(dot)
    if compact_now then compact() end

  fun ref converge(that: _DotContext box): Bool =>
    """
    Add all dots from that causal history into this one.

    The consecutive ranges in _complete can be updated to the maximum range.
    The _dot_cloud can be updated by taking the union of the two sets.
    """
    var changed = false

    for (id, n) in that._complete.pairs() do
      if n > _complete.get_or_else(id, 0) then
        _complete(id) = n
        changed = true
      end
    end

    for dot in that._dot_cloud.values() do
      if _complete.get_or_else(dot._1, 0) < dot._2 then
        if not _dot_cloud.contains(dot) then
          _dot_cloud.set(dot)
          changed = true
        end
      end
    end

    _dot_cloud.union(that._dot_cloud.values())
    compact()
    changed

  fun string(): String iso^ =>
    """
    Return a best effort at printing the data structure.
    This is intended for debugging purposes only.
    """
    let out = recover String end
    out.append("(_DotContext")
    for (id, n) in _complete.pairs() do
      out.>push(';').>push(' ')
      out.append(id.string())
      out.>push(' ').>push('<').>push('=').>push(' ')
      out.append(n.string())
    end
    for (id, n) in _dot_cloud.values() do
      out.>push(';').>push(' ')
      out.append(id.string())
      out.>push(' ').>push('=').>push('=').>push(' ')
      out.append(n.string())
    end
    out.push(')')
    out

  new ref from_tokens(that: TokenIterator[(ID | U32)])? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    if that.next_count()? != 2 then error end

    var complete_count = that.next_count()?
    if (complete_count % 2) != 0 then error end
    complete_count = complete_count / 2

    _complete = _complete.create(complete_count)
    while (complete_count = complete_count - 1) > 0 do
      _complete.update(
        that.next[ID]()?,
        that.next[U32]()?
      )
    end

    var dot_cloud_count = that.next_count()?
    if (dot_cloud_count % 2) != 0 then error end
    dot_cloud_count = dot_cloud_count / 2

    _dot_cloud = _dot_cloud.create(dot_cloud_count)
    while (dot_cloud_count = dot_cloud_count - 1) > 0 do
      _dot_cloud.set(
        (that.next[ID]()?, that.next[U32]()?)
      )
    end

  fun each_token(fn: {ref(Token[(ID | U32)])} ref) =>
    """
    Call the given function for each token, serializing as a sequence of tokens.
    """
    fn(USize(2))

    fn(_complete.size() * 2)
    for (id, n) in _complete.pairs() do
      fn(id)
      fn(n)
    end

    fn(_dot_cloud.size() * 2)
    for (id, n) in _dot_cloud.values() do
      fn(id)
      fn(n)
    end

  fun to_tokens(): TokenIterator[(ID | U32)] =>
    """
    Serialize an instance of this data structure to a stream of tokens.
    """
    Tokens[(ID | U32)].to_tokens(this)
