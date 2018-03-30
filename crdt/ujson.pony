use "_private"

class ref UJSON is (Equatable[UJSON] & Convergent[UJSON])
  """
  UJSON is a subset of JSON that contains only unordered data structures.
  In effect, UJSON data acts like multi-value registers (MVReg) inside
  nested observed-remove maps (ORMap), stored in a simple, efficient way.

  Like a multi-value register, concurrent writes to the same key in will appear
  as a set of values when those writes converge to being locally visible.
  In serialized UJSON, this is represented with JSON's array notation, which
  is available for this semantics because ordered arrays are not supported.

  When nested keys are located under the same multi-value register, they
  appear as a nested map, using JSON's object notation. All such keys are
  treated as being part of the same map; thus, it is impossible to hold multiple
  distinct maps in the same multi-value register, because those maps become
  merged into the same map. To keep nested maps separate, they must be nested
  under different keys of the outer map rather than under the same key.

  UJSON output can be parsed by any standard JSON parser. It can also accept
  any valid JSON string as input (though information may be lost, in accordance
  with the constraints in the previous two paragraphs).

  This data structure delegates causality tracking to the reusable "dot kernel"
  abstraction. Because that abstraction provides an eventually-consistent set
  of replica-associated values, and this data structure uses a commutative
  strategy for reading out the values, the result is eventually consistent.

  All mutator methods accept and return a convergent delta-state.
  """
  embed _kernel: DotKernel[(Array[String] val, UJSONValue)]

  // TODO: Fix ponyc to allow getting private fields from a lambda in this type,
  // then remove this workaround method.
  fun _get_kernel(): this->DotKernel[(Array[String] val, UJSONValue)] => _kernel

  new ref create(id: ID) =>
    """
    Instantiate under the given unique replica id.
    """
    _kernel = DotKernel[(Array[String] val, UJSONValue)](id)

  fun get(path': Array[String] val = []): UJSONNode =>
    """
    Get a UJSONNode representing all of the values at or under the given path.
    Call UJSONNode.is_void to check for the case of no values for this path.
    The result is optimized for printing as JSON with UJSONNode.string.
    """
    let builder = _UJSONNodeBuilder(path')
    for (path, value) in _kernel.values() do builder.collect(path, value) end
    builder.root()

  fun ref put[D: UJSON ref = UJSON](
    path': Array[String] val,
    node': UJSONNode,
    delta': D = recover UJSON(0) end)
  : D^ =>
    """
    Put a UJSONNode (all the values at and within it) at the given path.
    All locally visible values currently at or under that path will be removed.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_value[_UJSONPathEqPrefix]((path', None), delta'._kernel)
    node'._flat_each(path', {(path, value)(delta') =>
      _kernel.set((path, value), delta'._get_kernel())
    })
    delta'

  fun ref update[D: UJSON ref = UJSON](
    path': Array[String] val,
    value': UJSONValue,
    delta': D = recover UJSON(0) end)
  : D^ =>
    """
    Set a new value for the specified path.
    All locally visible values currently at or under that path will be removed.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_value[_UJSONPathEqPrefix]((path', None), delta'._kernel)
    _kernel.set((path', value'), delta'._kernel)
    delta'

  fun ref clear[D: UJSON ref = UJSON](
    path': Array[String] val = [],
    delta': D = recover UJSON(0) end)
  : D^ =>
    """
    Remove all locally visible values currently at or under the given path.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_value[_UJSONPathEqPrefix]((path', None), delta'._kernel)
    delta'

  fun ref insert[D: UJSON ref = UJSON](
    path': Array[String] val,
    value': UJSONValue,
    delta': D = recover UJSON(0) end)
  : D^ =>
    """
    Add a new value at the specified path.
    Any other locally visible values at or under that path will be retained.
    Accepts and returns a convergent delta-state.
    """
    _kernel.set((path', value'), delta'._kernel)
    delta'

  fun ref remove[D: UJSON ref = UJSON](
    path': Array[String] val,
    value': UJSONValue,
    delta': D = recover UJSON(0) end)
  : D^ =>
    """
    Remove the specified value from the specified path, if it exists there.
    If that value is not locally visible at that path, nothing will happen.
    Any other locally visible values at or under that path will be retained.
    Accepts and returns a convergent delta-state.
    """
    _kernel.remove_value[_UJSONEq]((path', value'), delta'._kernel)
    delta'

  fun ref converge(that: UJSON box): Bool =>
    """
    Converge from the given AWORSet into this one.
    Returns true if the convergence added new information to the data structure.
    """
    _kernel.converge(that._kernel)

  fun string(): String iso^ =>
    """
    Return the values in the data type, printed as a JSON object/set.
    """
    get().string()

  fun eq(that: UJSON box): Bool => get() == that.get()
  fun ne(that: UJSON box): Bool => not eq(that)
