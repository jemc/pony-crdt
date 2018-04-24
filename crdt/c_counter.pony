use "_private"
use "collections"

class ref CCounter[A: (Integer[A] val & (Unsigned | Signed)) = U64]
  is (Comparable[CCounter[A]] & Convergent[CCounter[A]])
  """
  A mutable counter, which can be both increased and decreased.

  This data type has the same general semantics as PNCounter, but instead of
  being modeled as two GCounters (positive and negative), is is built with the
  generic "dot kernel" abstraction used for tracking causality of updates.

  Each replica tracks its local value as a dot in the dot kernel. When updating
  the local value, the old dot is removed and a new dot with a happens-after
  relationship to the old dot (sequence number incremented) is added.
  When converging, dots that have the same id are trimmed so that only the one
  with the latest sequence number will remain.

  The total value of the counter is the sum of the local values of all replicas.

  Because the dot kernel abstraction provides an eventually-consistent set
  of replica-associated values, and this data structure uses a commutative
  strategy for folding them into a result, that result is eventually consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  embed _kernel: DotKernelSingle[A]

  new ref create(id: ID) =>
    """
    Instantiate the CCounter under the given unique replica id.
    """
    _kernel = DotKernelSingle[A](id)

  fun apply(): A =>
    """
    Return the current value of the counter (the sum of all local values).
    """
    value()

  fun value(): A =>
    """
    Return the current value of the counter (the sum of all local values).
    """
    var sum: A = 0
    for v in _kernel.values() do sum = sum + v end
    sum

  fun ref increment[D: CCounter[A] ref = CCounter[A]](
    value': A = 1,
    delta': D = recover CCounter[A](0) end)
  : D^ =>
    """
    Increment the counter by the given value.
    Accepts and returns a convergent delta-state.
    """
    _kernel.upsert(value', {(v, value') => v + value' }, delta'._kernel)
    delta'

  fun ref decrement[D: CCounter[A] ref = CCounter[A]](
    value': A = 1,
    delta': D = recover CCounter[A](0) end)
  : D^ =>
    """
    Decrement the counter by the given value.
    Accepts and returns a convergent delta-state.
    """
    _kernel.upsert(-value', {(v, value') => v + value' }, delta'._kernel)
    delta'

  fun ref converge(that: CCounter[A] box): Bool =>
    """
    Converge from the given CCounter into this one.
    Returns true if the convergence added new information to the data structure.
    """
    _kernel.converge(that._kernel)

  fun string(): String iso^ =>
    """
    Print the value of the counter.
    """
    value().string()

  fun eq(that: CCounter[A] box): Bool => value().eq(that.value())
  fun ne(that: CCounter[A] box): Bool => value().ne(that.value())
  fun lt(that: CCounter[A] box): Bool => value().lt(that.value())
  fun le(that: CCounter[A] box): Bool => value().le(that.value())
  fun gt(that: CCounter[A] box): Bool => value().gt(that.value())
  fun ge(that: CCounter[A] box): Bool => value().ge(that.value())

  new ref from_tokens(that: TokenIterator[CCounterToken[A]])? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    _kernel = _kernel.from_tokens(that)?

  fun each_token(fn: {ref(Token[CCounterToken[A]])} ref) =>
    """
    Call the given function for each token, serializing as a sequence of tokens.
    """
    _kernel.each_token(fn)

  fun to_tokens(): TokenIterator[CCounterToken[A]] =>
    """
    Serialize an instance of this data structure to a stream of tokens.
    """
    _kernel.to_tokens()

type CCounterToken[A] is (ID | U32 | A)
