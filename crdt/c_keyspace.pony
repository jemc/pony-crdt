use "collections"
use "_private"

type CKeyspace[
  K: (Hashable & Equatable[K] val),
  V: (Convergent[V] ref & Replicated ref)]
  is HashCKeyspace[K, V, HashEq[K]]

type CKeyspaceIs[
  K: Any val,
  V: (Convergent[V] ref & Replicated ref)]
  is HashCKeyspace[K, V, HashIs[K]]

class ref HashCKeyspace[
  K: Any val,
  V: (Convergent[V] ref & Replicated ref),
  H: HashFunction[K] val]

  let _ctx: DotContext
  embed _map: HashMap[K, V, H]

  new ref create(id: ID) => (_ctx, _map) = (_ctx.create(id), _map.create())
  new ref _create_in(ctx': DotContext) => (_ctx, _map) = (ctx', _map.create())
  fun _context(): this->DotContext => _ctx
  fun is_empty(): Bool => _map.size() == 0
  fun size(): USize => _map.size()
  fun keys(): Iterator[this->K]^ => _map.keys()
  fun values(): Iterator[this->V]^ => _map.values()
  fun pairs(): Iterator[(this->K, this->V)]^ => _map.pairs()
  fun apply(k: box->K!): this->V? => _map(k)?

  fun ref at(k: box->K!): V =>
    // TODO: add an optimized function in Pony's Map for this use case.
    try _map(k)? else
      let empty = V._create_in(_ctx)
      _map(k) = empty
      empty
    end

  // TODO: Find a way to bring remove functionality back?
  // fun ref remove[D: HashCKeyspace[K, V, H] ref = HashCKeyspace[K, V, H] ref]
  //   (k: K, delta': D = recover D(0) end): D
  // =>
  //   try
  //     let v = _map.remove(k)?._2
  //     delta'.at(k).converge(v.clear())
  //   end
  //   consume delta'

  // fun ref clear[D: HashCKeyspace[K, V, H] ref = HashCKeyspace[K, V, H] ref]
  //   (delta': D = recover D(0) end): D
  // =>
  //   for (k, v) in _map.pairs() do
  //     delta'.at(k).converge(v.clear())
  //   end
  //   _map.clear()
  //   consume delta'

  fun ref converge(that: HashCKeyspace[K, V, H] box): Bool =>
    var changed = false

    // Temporarily disable convergence of the shared context.
    // Each of the inner CRDTs will try to converge their context,
    // but we can't allow this when the context is shared,
    // because their converge logic rely on converging the context last.
    let converge_disabled = _ctx.set_converge_disabled(true)

    // TODO: Find a way to bring remove functionality back?
    // // For each entry that exists only here, and not in that keyspace,
    // // converge an imaginary empty instance into our local instance.
    // // This is how removals are propagated.
    // // TODO: Ouch! This seems very inefficient to do as described in the paper.
    // // How can we improve on this model, maybe sacrificing some failure modes?
    // for (k, v) in _map.pairs() do
    //   if not that._map.contains(k) then
    //     if v._converge_empty_in(that._ctx) then changed = true end
    //     if v.is_empty() then try _map.remove(k)? end end
    //   end
    // end

    // For each entry in the other map, converge locally.
    // If this results in an empty data structure, remove it to save memory.
    for (k, v) in that._map.pairs() do
      let local = at(k)
      if local.converge(v) then changed = true end
      if local.is_empty() then try _map.remove(k)? end end
    end

    // Re-enable converge for the context, then converge it.
    _ctx.set_converge_disabled(converge_disabled)
    if _ctx.converge(that._ctx) then changed = true end

    changed

  fun ref _converge_empty_in(ctx': DotContext box): Bool =>
    var changed = false

    // Temporarily disable convergence of the shared context.
    // Each of the inner CRDTs will try to converge their context,
    // but we can't allow this when the context is shared,
    // because their converge logic rely on converging the context last.
    let converge_disabled = _ctx.set_converge_disabled(true)

    // For each entry that exists only here, and not in that keyspace,
    // converge an imaginary empty instance into our local instance.
    // This is how removals are propagated.
    // TODO: This seems pretty inefficient... how can we improve on this model?
    for (k, v) in _map.pairs() do
      if v._converge_empty_in(ctx') then changed = true end
      if v.is_empty() then try _map.remove(k)? end end
    end

    // Re-enable converge for the context, then converge it.
    _ctx.set_converge_disabled(converge_disabled)
    if _ctx.converge(ctx') then changed = true end

    changed

  fun string(): String iso^ =>
    """
    Return a best effort at printing the map. If K and V are Stringable, use
    string representations of them; otherwise print them as question marks.
    """
    var buf = recover String((size() * 8) + 1) end
    buf.push('%')
    buf.push('{')
    var first = true
    for (k, v) in pairs() do
      if first then first = false else buf .> push(';').push(' ') end
      iftype K <: Stringable #read then
        buf.append(k.string())
      else
        buf.push('?')
      end
      buf .> push(' ') .> push('=') .> push('>') .> push(' ')
      iftype V <: Stringable #read then
        buf.append(v.string())
      else
        buf.push('?')
      end
    end
    buf.push('}')
    consume buf

  fun ref from_tokens(that: TokensIterator)? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    if that.next[USize]()? != 2 then error end

    _ctx.from_tokens(that)?

    let converge_disabled = _ctx.set_converge_disabled(true)

    var count = that.next[USize]()?
    if (count % 2) != 0 then error end
    count = count / 2

    // TODO: _map.reserve(count)
    while (count = count - 1) > 0 do
      _map.update(that.next[K]()?, V._create_in(_ctx) .> from_tokens(that)?)
    end

    _ctx.set_converge_disabled(converge_disabled)

  fun ref each_token(tokens: Tokens) =>
    """
    Serialize the data structure, capturing each token into the given Tokens.
    """
    tokens.push(USize(2))

    _ctx.each_token(tokens)

    let converge_disabled = _ctx.set_converge_disabled(true)

    tokens.push(_map.size() * 2)
    for (k, v) in _map.pairs() do
      tokens.push(k)
      v.each_token(tokens)
    end

    _ctx.set_converge_disabled(converge_disabled)

  fun each_token_of_history(tokens: Tokens) =>
    """
    Serialize the causal history, capturing each token into the given Tokens.
    """
    _ctx.each_token(tokens)

  fun compare_history_with_tokens(that: TokensIterator): (Bool, Bool)? =>
    """
    Compare the causal context with that represented by the given token stream.
    Raises an error if the tokens couldn't be parsed as a causal context.
    Returns two boolean values, representing differences that are present.
    The first return value is true if this context has dots missing in that one.
    The other return value is true if that context has dots missing in this one.
    """
    // TODO: consider comparing without allocating and deserializing the tokens.
    _ctx.compare(DotContext(0) .> from_tokens(that)?)
