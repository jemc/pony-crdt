use "_private"
use "collections"

type AWORSet[A: (Hashable val & Equatable[A])]
  is AWORHashSet[A, HashEq[A]]

type AWORSetIs[A: (Hashable val & Equatable[A])]
  is AWORHashSet[A, HashIs[A]]

class ref AWORHashSet[A: Equatable[A] val, H: HashFunction[A] val]
  is (Comparable[AWORHashSet[A, H]] & Causal[AWORHashSet[A, H]])
  """
  An unordered mutable set that supports removing locally visible elements
  ("observed remove") using per-replica sequence numbers to track causality.

  In the case where an insertion and a deletion for the same element have
  no causal relationship (they happened concurrently on differen replicas),
  the insertion will override the deletion ("add wins"). For a similar data
  structure with the opposite bias, see the "remove wins" variant (RWORSet).

  This data structure delegates causality tracking to the reusable "dot kernel"
  abstraction. Because that abstraction provides an eventually-consistent set
  of replica-associated values, and this data structure uses a commutative
  strategy for reading out the values, the result is eventually consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  embed _kernel: DotKernel[A]

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
    This is true at creation, after calling the clear method,
    or after a converge that results in all values being cleared.
    """
    _kernel.is_empty()

  fun result(): HashSet[A, H] =>
    """
    Return the elements of the resulting logical set as a single flat set.
    Information about specific deletions is discarded, so that the case of a
    deleted element is indistinct from that of an element never inserted.
    """
    var out = HashSet[A, H]
    for value in _kernel.values() do out.set(value) end
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
    for value in _kernel.values() do
      if value == value' then return true end
    end
    false

  fun ref set[D: AWORHashSet[A, H] ref = AWORHashSet[A, H]](
    value': A,
    delta': D = recover AWORHashSet[A, H](0) end)
  : D^ =>
    """
    Add a value to the set.
    Accepts and returns a convergent delta-state.
    """
    // As a memory optimization, first remove value' in any/all replicas.
    // The value only needs a dot in one replica - this one we're in now.
    _kernel.remove_value[Eq[A]](value', delta'._kernel)
    _kernel.set(value', delta'._kernel)
    delta'

  fun ref unset[D: AWORHashSet[A, H] ref = AWORHashSet[A, H]](
    value': A,
    delta': D = recover AWORHashSet[A, H](0) end)
  : D^ =>
    """
    Remove a value from the set.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_value[Eq[A]](value', delta'._kernel)
    delta'

  fun ref clear[D: AWORHashSet[A, H] ref = AWORHashSet[A, H]](
    delta': D = recover AWORHashSet[A, H](0) end)
  : D^ =>
    """
    Remove all locally visible elements from the set.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_all(delta'._kernel)
    delta'

  fun ref union[D: AWORHashSet[A, H] ref = AWORHashSet[A, H]](
    that': Iterator[A],
    delta': D = recover AWORHashSet[A, H](0) end)
  : D^ =>
    """
    Add everything in the given iterator to the set.
    Accepts and returns a convergent delta-state.
    """
    for value' in that' do set(value', delta') end
    delta'

  fun ref converge(that: AWORHashSet[A, H] box): Bool =>
    """
    Converge from the given AWORSet into this one.
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
  fun eq(that: AWORHashSet[A, H] box): Bool => result().eq(that.result())
  fun ne(that: AWORHashSet[A, H] box): Bool => result().ne(that.result())
  fun lt(that: AWORHashSet[A, H] box): Bool => result().lt(that.result())
  fun le(that: AWORHashSet[A, H] box): Bool => result().le(that.result())
  fun gt(that: AWORHashSet[A, H] box): Bool => result().gt(that.result())
  fun ge(that: AWORHashSet[A, H] box): Bool => result().ge(that.result())
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
