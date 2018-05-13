use "_private"
use "collections"

type RWORSet[A: (Hashable val & Equatable[A])]
  is RWORHashSet[A, HashEq[A]]

type RWORSetIs[A: (Hashable val & Equatable[A])]
  is RWORHashSet[A, HashIs[A]]

class ref RWORHashSet[A: Equatable[A] val, H: HashFunction[A] val]
  is (Comparable[RWORHashSet[A, H]] & Causal[RWORHashSet[A, H]])
  """
  An unordered mutable set that supports removing locally visible elements
  ("observed remove") using per-replica sequence numbers to track causality.

  In the case where an insertion and a deletion for the same element have
  no causal relationship (they happened concurrently on differen replicas),
  the deletion will override the insertion ("remove wins"). For a similar data
  structure with the opposite bias, see the "add wins" variant (AWORSet).

  This data structure delegates causality tracking to the reusable "dot kernel"
  abstraction. Because that abstraction provides an eventually-consistent set
  of replica-associated values, and this data structure uses a commutative
  strategy for reading out the values, the result is eventually consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  embed _kernel: DotKernel[(A, Bool)]

  new ref create(id: ID) =>
    """
    Instantiate under the given unique replica id.
    """
    _kernel = _kernel.create(id)

  new ref _create_in(ctx': DotContext) =>
    _kernel = _kernel.create_in(ctx')

  fun _context(): this->DotContext =>
    _kernel.context()

  fun is_empty(): Bool =>
    """
    Return true if there are no values recorded from any replica.
    This is true both at creation, after calling the clear method,
    or after a converge that results in all values being cleared.
    """
    _kernel.is_empty()

  fun result(): HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    // For each distinct value in the dot kernel, check the insert/delete tokens
    // to calculate a final boolean token, with deletes shadowing insertions.
    let tokens = HashMap[A, Bool, H]
    for (value, is_insert) in _kernel.values() do
      tokens(value) = is_insert and try tokens(value)? else true end
    end

    // Read the merged tokens' values into the output, counting only insertions.
    let out = HashSet[A, H]
    for (value, is_insert) in tokens.pairs() do
      if is_insert then out.set(value) end
    end

    out

  fun size(): USize =>
    """
    Return the number of items in the set.
    """
    result().size()

  fun contains(value': A): Bool =>
    """
    Check whether the set contains the given value.
    """
    var inserted = false

    // For each instance of this value in the dot kernel, take the
    // insert/delete tokens into account, with deletions shado
    for (value, is_insert) in _kernel.values() do
      if value == value' then
        if is_insert
        then inserted = true
        else return false // if we see a deletion, it shadows all insertions
        end
      end
    end

    inserted

  fun ref set[D: RWORHashSet[A, H] ref = RWORHashSet[A, H]](
    value': A,
    delta': D = recover RWORHashSet[A, H](0) end)
  : D^ =>
    """
    Add a value to the set.
    Accepts and returns a convergent delta-state.
    """
    // Clear any locally visible insertions and deletions for this value,
    // then add an insertion token (true) for it.
    _kernel.remove_value[EqTuple2[A, Bool]]((value', true), delta'._kernel)
    _kernel.remove_value[EqTuple2[A, Bool]]((value', false), delta'._kernel)
    _kernel.set((value', true), delta'._kernel)
    delta'

  fun ref unset[D: RWORHashSet[A, H] ref = RWORHashSet[A, H]](
    value': A,
    delta': D = recover RWORHashSet[A, H](0) end)
  : D^ =>
    """
    Remove a value from the set.
    Accepts and returns a convergent delta-state.
    """
    // Clear any locally visible insertions and deletions for this value,
    // then add an deletion token (false) for it.
    _kernel.remove_value[EqTuple2[A, Bool]]((value', true), delta'._kernel)
    _kernel.remove_value[EqTuple2[A, Bool]]((value', false), delta'._kernel)
    _kernel.set((value', false), delta'._kernel)
    delta'

  fun ref clear[D: RWORHashSet[A, H] ref = RWORHashSet[A, H]](
    delta': D = recover RWORHashSet[A, H](0) end)
  : D^ =>
    """
    Remove all locally visible elements from the set.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_all(delta'._kernel)
    delta'

  fun ref union[D: RWORHashSet[A, H] ref = RWORHashSet[A, H]](
    that': Iterator[A],
    delta': D = recover RWORHashSet[A, H](0) end)
  : D^ =>
    """
    Add everything in the given iterator to the set.
    Accepts and returns a convergent delta-state.
    """
    for value' in that' do set(value', delta') end
    delta'

  fun ref converge(that: RWORHashSet[A, H] box): Bool =>
    """
    Converge from the given RWORSet into this one.
    Returns true if the convergence added new information to the data structure.
    """
    _kernel.converge(that._kernel)

  fun ref _converge_empty_in(ctx': DotContext box): Bool =>
    """
    Optimize for the special case of converging from a peer with an empty map,
    taking only their DotContext as an argument for resolving disagreements.
    """
    _kernel.converge_empty_in(ctx')

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
      iftype A <: Stringable then
        buf.append(value.string())
      else
        buf.push('?')
      end
    end
    buf.push('}')
    consume buf

  // TODO: optimize comparison functions:
  fun eq(that: RWORHashSet[A, H] box): Bool => result().eq(that.result())
  fun ne(that: RWORHashSet[A, H] box): Bool => result().ne(that.result())
  fun lt(that: RWORHashSet[A, H] box): Bool => result().lt(that.result())
  fun le(that: RWORHashSet[A, H] box): Bool => result().le(that.result())
  fun gt(that: RWORHashSet[A, H] box): Bool => result().gt(that.result())
  fun ge(that: RWORHashSet[A, H] box): Bool => result().ge(that.result())
  fun values(): Iterator[A]^ => result().values()

  fun ref from_tokens(that: TokensIterator)? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    _kernel.from_tokens(that)?

  fun ref each_token(tokens: Tokens) =>
    """
    Call the given function for each token, serializing as a sequence of tokens.
    """
    _kernel.each_token(tokens)
