use "collections"

type GSet[A: (Hashable val & Equatable[A])] is GHashSet[A, HashEq[A]]

type GSetIs[A: Any #share] is GHashSet[A, HashIs[A]]

class ref GHashSet[A: Any #share, H: HashFunction[A] val]
  is (Comparable[GHashSet[A, H]] & Convergent[GHashSet[A, H]])
  """
  An unordered mutable grow-only set. That is, it only allows insertion.

  Because the set is unordered and elements can only be added (never deleted),
  the results are eventually consistent when converged.

  All mutator methods accept and return a convergent delta-state.
  """
  embed _data: HashSet[A, H]

  new ref create() =>
    _data = HashSet[A, H]

  fun ref _data_set(value: A) => _data.set(value)

  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    _data.size()

  fun apply(value: val->A): val->A ? =>
    """
    Return the value if it's in the set, otherwise raise an error.
    """
    _data(value)?

  fun contains(value: val->A): Bool =>
    """
    Check whether the set contains the given value.
    """
    _data.contains(value)

  fun ref set[D: GHashSet[A, H] ref = GHashSet[A, H]](
    value: A,
    delta: D = recover GHashSet[A, H] end)
  : D^ =>
    """
    Add a value to the set.
    Accepts and returns a convergent delta-state.
    """
    _data.set(value)
    delta._data_set(value)
    delta

  fun ref union[D: GHashSet[A, H] ref = GHashSet[A, H]](
    that: Iterator[A],
    delta: D = recover GHashSet[A, H] end)
  : D^ =>
    """
    Add everything in the given iterator to the set.
    Accepts and returns a convergent delta-state.
    """
    for value in that do
      _data.set(value)
      delta._data_set(value)
    end
    delta

  fun ref converge(that: GHashSet[A, H] box): Bool =>
    """
    Converge from the given GSet into this one.
    For this data type, the convergence is a simple union.
    Returns true if the convergence added new information to the data structure.
    """
    let orig_size = _data.size()
    union(that._data.values())
    orig_size != _data.size()

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

  fun eq(that: GHashSet[A, H] box): Bool => _data.eq(that._data)
  fun ne(that: GHashSet[A, H] box): Bool => _data.ne(that._data)
  fun lt(that: GHashSet[A, H] box): Bool => _data.lt(that._data)
  fun le(that: GHashSet[A, H] box): Bool => _data.le(that._data)
  fun gt(that: GHashSet[A, H] box): Bool => _data.gt(that._data)
  fun ge(that: GHashSet[A, H] box): Bool => _data.ge(that._data)
  fun values(): Iterator[A]^ => _data.values()

  new ref from_tokens(that: TokenIterator[GSetToken[A]])? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    var count = that.next_count()?
    _data = _data.create(count)
    while (count = count - 1) > 0 do
      _data.set(that.next[A]()?)
    end

  fun each_token(fn: {ref(Token[GSetToken[A]])} ref) =>
    """
    Call the given function for each token, serializing as a sequence of tokens.
    """
    fn(_data.size())
    for value in _data.values() do fn(value) end

  fun to_tokens(): TokenIterator[GSetToken[A]] =>
    """
    Serialize an instance of this data structure to a stream of tokens.
    """
    Tokens[GSetToken[A]].to_tokens(this)

type GSetToken[A] is A
