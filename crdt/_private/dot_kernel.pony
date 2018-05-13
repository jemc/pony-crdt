use ".."
use "collections"

class ref DotKernel[A: Any val] is Replicated
  """
  This class is a reusable abstraction meant for use inside other CRDTs.

  It contains a "dot context", which is used to track a logical remembrance
  of all changes we've generated and observed. Each is represented by a "dot",
  where the dot is a unique replica identifier and a sequence number.
  See docs for the DotContext type for more information on how this works.

  We also maintain a map of "active" values - those we wish to retain for
  inclusion in the calculation of the result value, using whatever semantics
  are appropriate for that calculation, based on the needs of the outer
  data structure that holds this kernel. For example, the CCounter calculates
  its result by summing all active values, while the AWORSet calculates its
  result by returning the active values as a set. Other data structures may
  use more exotic calculations.

  Each active value is associated with a "dot" - a point in causal history
  on a particular replica. Because we retain a remembrance of all dots we've
  ever seen in the "dot context", we can determine whether data we observe is
  new to us or outdated by checking if the dot is already in the dot context.

  Note that because active values are indexed by their dot (and not simply
  their replica id) it is possible to retain multiple active values per
  replica if the outer data structure doesn't take steps to prevent this.
  For some data structures, this is desirable; for others, it isn't.
  If you wish to always keep only the latest causal active value per replica,
  prefer using the DotKernelSingle class instead of this one.
  """
  let _ctx: DotContext
  embed _map: HashMap[_Dot, A, _DotHashFn]

  new create(id': ID) =>
    """
    Instantiate under the given unique replica id.

    It will only be possible to add dotted values under this replica id,
    aside from converging it as external data with the `converge` function.
    """
    _ctx = _ctx.create(id')
    _map = _map.create()

  new create_in(ctx': DotContext) =>
    """
    Instantiate under the given DotContext.
    """
    _ctx = ctx'
    _map = _map.create()

  fun context(): this->DotContext =>
    """
    Get the underlying DotContext.
    """
    _ctx

  fun is_empty(): Bool =>
    """
    Return true if there are no values recorded from any replica.
    This is true at creation, after calling the clear method,
    or after a converge that results in all values being cleared.
    """
    _map.size() == 0

  fun values(): Iterator[A]^ =>
    """
    Return an iterator over the active values in this kernel.
    """
    _map.values()

  fun pairs(): Iterator[(_Dot, A)]^ =>
    """
    Return an iterator over the active values and their associated dots.
    """
    _map.pairs()

  fun ref set[D: DotKernel[A] ref = DotKernel[A]](
    value': A,
    delta': D = recover DotKernel[A](0) end)
  : D^ =>
    """
    Add the given value to the map of active values, under this replica id.
    The next-sequence-numbered dot for this replica will be used, so that the
    new value has a happens-after causal relationship with previous value(s).
    """
    let dot = _ctx.next_dot()
    _map(dot) = value'
    delta'._map(dot) = value'
    delta'._ctx.set(dot)
    delta'

  fun ref remove_value[E: EqFn[A] val, D: DotKernel[A] ref = DotKernel[A]](
    value': A,
    delta': D = recover DotKernel[A](0) end)
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
    let removables: Array[_Dot] = []
    for (dot, value) in _map.pairs() do
      if E(value', value) then
        removables.push(dot)
        delta'._ctx.set(dot, false) // wait to compact until the end
      end
    end
    for dot in removables.values() do try _map.remove(dot)? end end

    delta'._ctx.compact() // now we can compact just once
    delta'

  fun ref remove_all[D: DotKernel[A] ref = DotKernel[A]](
    delta': D = recover DotKernel[A](0) end)
  : D^ =>
    """
    Remove all dots currently present in the map of active values.
    They will be retained in the causal context.

    This removes the dots and associated values while keeping reminders that
    we have seen them before, so that we can ignore them if we see them again.

    Accepts and returns a convergent delta-state.
    """
    for dot in _map.keys() do
      delta'._ctx.set(dot, false) // wait to compact until the end
    end

    _map.clear()

    delta'._ctx.compact() // now we can compact just once
    delta'

  fun ref converge(that: DotKernel[A] box): Bool =>
    """
    Catch up on active values and dot history from that kernel into this one,
    using the dot history as a context for understanding for which disagreements
    we are out of date, and for which disagreements the other is out of date.
    """
    var changed = false
    // TODO: more efficient algorithm?

    // Active values that exist only in the other kernel and haven't yet been
    // seen in our history of dots should be added to our map of active values.
    for (dot, value) in that.pairs() do
      if (not _map.contains(dot)) and (not _ctx.contains(dot)) then
        _map(dot) = value
        changed = true
      end
    end

    // Active values that now exist only in our kernel but were already seen
    // by that kernel's history of dots should be removed from our map.
    let removables: Array[_Dot] = []
    for dot in _map.keys() do
      if (not that._map.contains(dot)) and that._ctx.contains(dot) then
        removables.push(dot)
        changed = true
      end
    end
    for dot' in removables.values() do try _map.remove(dot')? end end

    // Finally, catch up on the entire history of dots that the other kernel
    // knows about, Because we're now caught up on the fruits of that history.
    // It's important that we do this as the last step; both this local logic,
    // and some broader assumptions regarding sharing contexts rely on the
    // fact that the context is converged after the data.
    // Note that this call will be a no-op when the context is shared.
    if _ctx.converge(that._ctx) then
      changed = true
    end

    changed

  fun ref converge_empty_in(ctx': DotContext box): Bool =>
    """
    Optimize for the special case of converging from a peer with an empty map,
    taking only their DotContext as an argument for resolving disagreements.
    """
    var changed = false

    // Active values that now exist only in our kernel but were already seen
    // by that kernel's history of dots should be removed from our map.
    let removables: Array[_Dot] = []
    for dot in _map.keys() do
      if ctx'.contains(dot) then
        removables.push(dot)
        changed = true
      end
    end
    for dot' in removables.values() do try _map.remove(dot')? end end

    // Finally, catch up on the entire history of dots that the other kernel
    // knows about, Because we're now caught up on the fruits of that history.
    // It's important that we do this as the last step; both this local logic,
    // and some broader assumptions regarding sharing contexts rely on the
    // fact that the context is converged after the data.
    // Note that this call will be a no-op when the context is shared.
    if _ctx.converge(ctx') then
      changed = true
    end

    changed

  fun string(): String iso^ =>
    """
    Return a best effort at printing the data structure.
    This is intended for debugging purposes only.
    """
    let out = recover String end
    out.append("(DotKernel")
    for (dot, value) in _map.pairs() do
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

  fun ref from_tokens(that: TokensIterator) ? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    if that.next[USize]()? != 2 then error end

    _ctx.from_tokens(that)?

    var count = that.next[USize]()?
    if (count % 3) != 0 then error end
    count = count / 3

    // TODO: _map.reserve(count)
    while (count = count - 1) > 0 do
      _map.update((that.next[ID]()?, that.next[U32]()?), that.next[A]()?)
    end

  fun ref from_tokens_map(
    that: TokensIterator,
    a_fn: {(TokensIterator): A?} val)
    ?
  =>
    """
    Deserialize an instance of this data structure from a stream of tokens,
    using a custom function for deserializing the B tokens as instance(s) of A.
    """
    if that.next[USize]()? != 2 then error end

    _ctx.from_tokens(that)?

    var count = that.next[USize]()?
    if (count % 3) != 0 then error end
    count = count / 3

    // TODO: _map.reserve(count)
    while (count = count - 1) > 0 do
      _map.update((that.next[ID]()?, that.next[U32]()?), a_fn(that)?)
    end

  fun ref each_token(tokens: Tokens) =>
    """
    Serialize the data structure, capturing each token into the given Tokens.
    """
    each_token_map(tokens, {(tokens, a) => tokens.push(a) })

  fun ref each_token_map(tokens: Tokens, a_fn: {(Tokens, A)} val) =>
    """
    Serialize the data structure, capturing each token into the given Tokens.
    using a custom function for serializing the A type as one or more B tokens.
    """
    tokens.push(USize(2))

    _ctx.each_token(tokens)

    tokens.push(_map.size() * 3)
    for ((i, n), v) in _map.pairs() do
      tokens.push(i)
      tokens.push(n)
      a_fn(tokens, v)
    end
