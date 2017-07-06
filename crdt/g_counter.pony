use "collections"

class ref GCounter[A: U64 val = U64] // TODO: allow any unsigned integer?
  is (Comparable[GCounter[A]] & Convergent[GCounter[A] box])
  """
  A mutable grow-only counter. That is, the value can only be increased.
  
  This data type tracks the state seen from each replica, thus the size of the
  state will grow proportionally with the number of total replicas. New replicas
  may be added as peers at any time, provided that they use unique ids.
  Read-only replicas which never change state and only observe need not use
  unique ids, and should use an id of zero, by convention.
  
  The state of each replica represents the value incremented so far by that
  particular replica. This local value may only ever increase, never decrease.
  The total value of the counter is the sum of the local value of all replicas.
  
  When converging state from other replicas, we retain the maximum observed
  value from each replica id. Because a higher value always implies later
  logical time for that replica, and we only keep the highest value seen from
  each replica, we will always retain the latest value seen from each replica.
  
  Because the view of values from each other replica is eventually consistent,
  the summed value of the overall counter is also eventually consistent.
  
  All mutator methods accept and return a convergent delta-state.
  """
  let _id: U64
  var _data: Map[U64, A]
  
  new ref create(id': U64) =>
    """
    Instantiate the GCounter under the given unique replica id.
    """
    _id   = id'
    _data = Map[U64, A]
  
  fun apply(): A =>
    """
    Return the current value of the counter (the sum of all replica values).
    """
    value()
  
  fun value(): A =>
    """
    Return the current value of the counter (the sum of all replica values).
    """
    var sum = A(0)
    for v in _data.values() do sum = sum + v end
    sum
  
  fun ref _data_update(id': U64, value': A) => _data(id') = value'
  
  fun ref increment[D: GCounter[A] #write = GCounter[A] trn](
    value': A = 1,
    delta': D = recover GCounter[A](0) end)
  : D^ =>
    """
    Increment the counter by the given value.
    Accepts and returns a convergent delta-state.
    """
    try
      let v' = _data.upsert(_id, value', {(v: A, value': A): A => v + value' })
      delta'._data_update(_id, v')
    end
    consume delta'
  
  fun ref converge(that: GCounter[A] box) =>
    """
    Converge from the given GCounter into this one.
    For each replica state, we select the maximum value seen so far (grow-only).
    """
    for (id, value') in that._data.pairs() do
      try _data.upsert(id, value', {(v: A, value': A): A => v.max(value') }) end
    end
  
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
  
  fun eq(that: GCounter[A] box): Bool => value().eq(that.value())
  fun ne(that: GCounter[A] box): Bool => value().ne(that.value())
  fun lt(that: GCounter[A] box): Bool => value().lt(that.value())
  fun le(that: GCounter[A] box): Bool => value().le(that.value())
  fun gt(that: GCounter[A] box): Bool => value().gt(that.value())
  fun ge(that: GCounter[A] box): Bool => value().ge(that.value())
