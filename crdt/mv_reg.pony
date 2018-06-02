use "_private"
use "collections"

type MVReg[A: (Hashable val & Equatable[A])]
  is MVHashReg[A, HashEq[A]]

type MVRegIs[A: (Hashable val & Equatable[A])]
  is MVHashReg[A, HashIs[A]]

class ref MVHashReg[A: Equatable[A] val, H: HashFunction[A] val]
  is (Comparable[MVHashReg[A, H]] & Causal[MVHashReg[A, H]])
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
    Return true if there are no values ever recorded from any replica.
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

  fun ref update[D: MVHashReg[A, H] ref = MVHashReg[A, H]](
    value': A,
    delta': D = recover MVHashReg[A, H](0) end)
  : D^ =>
    """
    Set the value of the register, overriding all currently visible values.
    After this function, the register will have a single value locally, at least
    until any concurrent updates are converged, adding more values into the set.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_all(delta'._kernel)
    _kernel.set(value', delta'._kernel)
    delta'

  fun ref clear[D: MVHashReg[A, H] ref = MVHashReg[A, H]](
    delta': D = recover MVHashReg[A, H](0) end)
  : D^ =>
    """
    Remove all locally visible elements from the set.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_all(delta'._kernel)
    delta'

  fun ref converge(that: MVHashReg[A, H] box): Bool =>
    """
    Converge from the given MVReg into this one.
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
  fun eq(that: MVHashReg[A, H] box): Bool => result().eq(that.result())
  fun ne(that: MVHashReg[A, H] box): Bool => result().ne(that.result())
  fun lt(that: MVHashReg[A, H] box): Bool => result().lt(that.result())
  fun le(that: MVHashReg[A, H] box): Bool => result().le(that.result())
  fun gt(that: MVHashReg[A, H] box): Bool => result().gt(that.result())
  fun ge(that: MVHashReg[A, H] box): Bool => result().ge(that.result())
  fun values(): Iterator[A]^ => result().values()

  fun ref from_tokens(that: TokensIterator)? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    _kernel.from_tokens(that)?

  fun ref each_token(tokens: Tokens) =>
    """
    Serialize the data structure, capturing each token into the given Tokens.
    """
    _kernel.each_token(tokens)
