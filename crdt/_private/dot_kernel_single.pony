use ".."
use "collections"

class ref DotKernelSingle[A: Any #share] is Convergent[DotKernelSingle[A]]
  """
  This class is a reusable abstraction meant for use inside other CRDTs.

  It is a variant of the DotKernel class which changes the indexing of the
  map of active values, such that at most one value per replica is retained.
  This simplifies the logic for data structures like CCounter which operate
  with this assumption.

  See the docs for the DotKernel class for more information.
  """
  let _id: ID
  embed _ctx: _DotContext
  embed _map: Map[ID, (U32, A)]

  new create(id': ID) =>
    """
    Instantiate under the given unique replica id.
    
    It will only be possible to add dotted values under this replica id,
    aside from converging it as external data with the `converge` function.
    """
    _id  = id'
    _ctx = _ctx.create()
    _map = _map.create()

  fun id(): ID =>
    """
    Return the replica id used to instantiate this kernel.
    """
    _id

  fun values(): Iterator[A]^ =>
    """
    Return an iterator over the active values in this kernel.
    """
    object is Iterator[A]
      let iter: Iterator[(U32, A)] = _map.values()
      fun ref has_next(): Bool => iter.has_next()
      fun ref next(): A? => iter.next()?._2
    end

  fun ref update[D: DotKernelSingle[A] ref = DotKernelSingle[A]](
    value': A,
    delta': D = recover DotKernelSingle[A](0) end)
  : D^ =>
    """
    Update the value for this replica in the map of active values.
    The next-sequence-numbered dot for this replica will be used, so that the
    new value has a happens-after causal relationship with the previous value.
    """
    let dot = _ctx.next_dot(_id)
    _map(dot._1) = (dot._2, value')
    delta'._map(dot._1) = (dot._2, value')
    delta'._ctx.set(dot)
    delta'

  fun ref upsert[D: DotKernelSingle[A] ref = DotKernelSingle[A]](
    value': A,
    fn': {(A, A): A^} box,
    delta': D = recover DotKernelSingle[A](0) end)
  : D^ =>
    """
    Update the 
    """
    let value = try fn'(_map(_id)?._2, value') else value' end
    update(value, delta')

  fun ref remove_value[
    E: EqFn[A] val,
    D: DotKernelSingle[A] ref = DotKernelSingle[A]](
    value': A,
    delta': D = recover DotKernelSingle[A](0) end)
  : D^ =>
    """
    Remove all dots with this value from the map of active values, using the
    given eq_fn for testing equality between pairs of values of type A.
    They will be retained in the causal context (if they were already present).

    This removes the dots and associated value while keeping reminders that
    we have seen them before, so that we can ignore them if we see them again.

    If the value was not present, this function silently does nothing.

    Accepts and returns a convergent delta-state.
    """
    let removables: Array[ID] = []
    for (id', (n, value)) in _map.pairs() do
      if E(value', value) then
        removables.push(id')
        let dot = (id', n)
        delta'._ctx.set(dot, false) // wait to compact until the end
      end
    end
    for id' in removables.values() do try _map.remove(id')? end end

    delta'._ctx.compact() // now we can compact just once
    delta'

  fun ref remove_all[D: DotKernelSingle[A] ref = DotKernelSingle[A]](
    delta': D = recover DotKernelSingle[A](0) end)
  : D^ =>
    """
    Remove all dots currently present in the map of active values.
    They will be retained in the causal context.

    This removes the dots and associated values while keeping reminders that
    we have seen them before, so that we can ignore them if we see them again.

    Accepts and returns a convergent delta-state.
    """
    for (id', (n, value)) in _map.pairs() do
      let dot = (id', n)
      delta'._ctx.set(dot, false) // wait to compact until the end
    end

    _map.clear()

    delta'._ctx.compact() // now we can compact just once
    delta'

  fun ref converge(that: DotKernelSingle[A] box): Bool =>
    """
    Catch up on active values and dot history from that kernel into this one,
    using the dot history as a context for understanding for which disagreements
    we are out of date, and for which disagreements the other is out of date.
    """
    var changed = false
    // TODO: more efficient algorithm?

    // Active values that exist only in the other kernel and haven't yet been
    // seen in our history of dots should be added to our map of active values.
    for (id', (n, value)) in that._map.pairs() do
      let dot = (id', n)
      if (_map.get_or_else(id', (0, value))._1 < n) and (not _ctx.contains(dot)) then
        _map(id') = (n, value)
        changed = true
      end
    end

    // Active values that now exist only in our kernel but were already seen
    // by that kernel's history of dots should be removed from our map.
    let removables: Array[ID] = []
    for (id', (n, value)) in _map.pairs() do
      let dot = (id', n)
      if (not that._map.contains(id')) and that._ctx.contains(dot) then
        removables.push(id')
        changed = true
      end
    end
    for id' in removables.values() do try _map.remove(id')? end end

    // Finally, catch up on the entire history of dots that the other kernel
    // knows about, Because we're now caught up on the fruits of that history.
    if _ctx.converge(that._ctx) then
      changed = true
    end

    changed

  fun string(): String iso^ =>
    """
    Return a best effort at printing the data structure.
    This is intended for debugging purposes only.
    """
    let out = recover String end
    out.append("(DotKernelSingle")
    for (id', (n, value)) in _map.pairs() do
      let dot = (id', n)
      out.>push(';').>push(' ').>push('(')
      out.append(dot._1.string())
      out.>push(',').>push(' ')
      out.append(dot._2.string())
      out.>push(')').>push(' ').>push('-').>push('>').>push(' ')
      iftype A <: Stringable #read
      then out.append(value.string())
      else out.push('?')
      end
    end
    out.>push(';').>push(' ')
    out.append(_ctx.string())
    out

  new ref from_tokens(that: TokenIterator[(ID | U32 | A)])? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    if that.next_count()? != 3 then error end

    _id = that.next[ID]()?

    _ctx = _ctx.from_tokens(Tokens[(ID | U32 | A)].subset[(ID | U32)](that))?

    var count = that.next_count()?
    if (count % 3) != 0 then error end
    count = count / 3

    _map = _map.create(count)
    while (count = count - 1) > 0 do
      _map.update(
        that.next[ID]()?,
        (that.next[U32]()?, that.next[A]()?)
      )
    end

  fun each_token(fn: {ref(Token[(ID | U32 | A)])} ref) =>
    """
    Call the given function for each token, serializing as a sequence of tokens.
    """
    fn(USize(3))

    fn(_id)

    _ctx.each_token(fn)

    fn(_map.size() * 3)
    for (i, (n, v)) in _map.pairs() do
      fn(i)
      fn(n)
      fn(v)
    end

  fun to_tokens(): TokenIterator[(ID | U32 | A)] =>
    """
    Serialize an instance of this data structure to a stream of tokens.
    """
    Tokens[(ID | U32 | A)].to_tokens(this)
