class ref LWWReg[
  A: Comparable[A] val,
  T: Comparable[T] val = U64,
  B: (BiasGreater | BiasLesser) = BiasGreater]
  is (Equatable[LWWReg[A, T, B]] & Convergent[LWWReg[A, T, B] box])
  """
  A mutable register with last-write-wins semantics for updating the value.
  That is, every update operation includes a logical timestamp (U64 by default,
  though it may be any Comparable immutable type), and update operationss are
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
  """
  var _value: A
  var _timestamp: T
  
  new ref create(value': A, timestamp': T) =>
    (_value, _timestamp) = (value', timestamp')
  
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
  
  fun ref _update_no_delta(value': A, timestamp': T) =>
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
    end
  
  fun ref update(
    value': A,
    timestamp': T,
    delta': (LWWReg[A, T, B] trn | None) = None)
  : LWWReg[A, T, B] trn^ =>
    """
    Update the value and timestamp of the register, provided that the given
    timestamp is newer than the current timestamp of the register.
    If the given timestamp is older, the update is ignored.
    """
    _update_no_delta(value', timestamp')
    
    match consume delta'
    | let delta: LWWReg[A, T, B] trn =>
      delta._update_no_delta(value', timestamp')
      consume delta
    else
      recover LWWReg[A, T, B](value', timestamp') end
    end
  
  fun ref converge(that: LWWReg[A, T, B] box) =>
    """
    Converge from the given LWWReg into this one.
    For this data type, the convergence is a simple update operation.
    """
    _update_no_delta(that.value(), that.timestamp())
  
  fun string(): String iso^ =>
    """
    Return a best effort at printing the register. If A is Stringable, use
    the string representation of the value; otherwise print as a question mark.
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
    iftype A <: Stringable val then
      buf.append(value().string())
    else
      buf.push('?')
    end
    buf.push(')')
    consume buf
  
  fun eq(that: LWWReg[A, T, B] box): Bool => value().eq(that.value())
  fun ne(that: LWWReg[A, T, B] box): Bool => value().ne(that.value())
  fun lt(that: LWWReg[A, T, B] box): Bool => value().lt(that.value())
  fun le(that: LWWReg[A, T, B] box): Bool => value().le(that.value())
  fun gt(that: LWWReg[A, T, B] box): Bool => value().gt(that.value())
  fun ge(that: LWWReg[A, T, B] box): Bool => value().ge(that.value())
