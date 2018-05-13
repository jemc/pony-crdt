use "_private"

type TRegString[
  T: (Integer[T] & Unsigned) = U64,
  B: (BiasGreater | BiasLesser) = BiasGreater]
  is TReg[String, _DefaultValueString, T, B]

type TRegNumber[
  A: (Number & Real[A] val),
  T: (Integer[T] & Unsigned) = U64,
  B: (BiasGreater | BiasLesser) = BiasGreater]
  is TReg[A, _DefaultValueNumber[A], T, B]

class ref TReg[
  A: Comparable[A] val,
  V: _DefaultValueFn[A] val,
  T: (Integer[T] & Unsigned) = U64,
  B: (BiasGreater | BiasLesser) = BiasGreater]
  is (Equatable[TReg[A, V, T, B]] & Convergent[TReg[A, V, T, B]] & Replicated)
  """
  A mutable register with last-write-wins semantics for updating the value.
  That is, every update operation includes a logical timestamp (U64 by default,
  though it may be any unsigned integer type), and update operationss are
  overridden only by those with a higher logical timestamp.

  This implies that the timestamps must be correct (or at least logically so)
  in order for the last-write-wins semantics to hold true.

  If the logical timestamp is equal for two compared operations, the tie will
  be broken by the bias type parameter. BiasGreater implies that the greater of
  the two compared values will be chosen, while BiasLesser implies the opposite.
  The default bias is BiasGreater.

  Because there is an order-independent way of comparing both the timestamp and
  the value term of all update operations, all conflicts can be resolved in a
  commutative way; thus, the result is eventually consistent in all replicas.
  The same bias must be used on all replicas for tie results to be consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  var _value:     A = V()
  var _timestamp: T = T.from[U8](0)

  new ref create() => None

  new ref _create_in(ctx: DotContext) => // ignore the context
    None

  fun ref _converge_empty_in(ctx: DotContext box): Bool => // ignore the context
    false

  fun is_empty(): Bool =>
    """
    Return true if the data structure contains no information (bottom state).
    """
    _timestamp == T.from[U8](0)

  fun apply(): A =>
    """
    Return the current value of the register.
    """
    _value

  fun value(): A =>
    """
    Return the current value of the register.
    """
    _value

  fun timestamp(): T =>
    """
    Return the latest timestamp of the register.
    """
    _timestamp

  fun ref _update_no_delta(value': A, timestamp': T): Bool =>
    if
      (timestamp' > _timestamp) or (
        (timestamp' == _timestamp)
      and
        iftype B <: BiasGreater
        then value' > _value
        else value' < _value
        end
      )
    then
      _value     = value'
      _timestamp = timestamp'
      true
    else
      false
    end

  fun ref update[D: TReg[A, V, T, B] ref = TReg[A, V, T, B]](
    value': A,
    timestamp': T,
    delta': D = D)
  : D^ =>
    """
    Update the value and timestamp of the register, provided that the given
    timestamp is newer than the current timestamp of the register.
    If the given timestamp is older, the update is ignored.
    Accepts and returns a convergent delta-state.
    """
    _update_no_delta(value', timestamp')

    delta' .> _update_no_delta(value', timestamp')

  fun ref converge(that: TReg[A, V, T, B] box): Bool =>
    """
    Converge from the given TReg into this one.
    For this data type, the convergence is a simple update operation.
    Returns true if the convergence added new information to the data structure.
    """
    _update_no_delta(that.value(), that.timestamp())

  fun string(): String iso^ =>
    """
    Return a best effort at printing the log. If A and T are Stringable, use
    the string representation of them; otherwise print as question marks.
    """
    let buf = recover String(8) end
    buf.push('%')
    buf.push('(')
    iftype A <: Stringable val then
      buf.append(value().string())
    else
      buf.push('?')
    end
    buf .> push(',').push(' ')
    iftype T <: Stringable val then
      buf.append(timestamp().string())
    else
      buf.push('?')
    end
    buf.push(')')
    consume buf

  fun eq(that: TReg[A, V, T, B] box): Bool => value().eq(that.value())
  fun ne(that: TReg[A, V, T, B] box): Bool => value().ne(that.value())
  fun lt(that: TReg[A, V, T, B] box): Bool => value().lt(that.value())
  fun le(that: TReg[A, V, T, B] box): Bool => value().le(that.value())
  fun gt(that: TReg[A, V, T, B] box): Bool => value().gt(that.value())
  fun ge(that: TReg[A, V, T, B] box): Bool => value().ge(that.value())

  fun ref from_tokens(that: TokensIterator)? =>
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """
    if that.next[USize]()? != 2 then error end
    _value     = that.next[A]()?
    _timestamp = that.next[T]()?

  fun ref each_token(tokens: Tokens) =>
    """
    Serialize the data structure, capturing each token into the given Tokens.
    """
    tokens.push(USize(2))
    tokens.push(_value)
    tokens.push(_timestamp)
