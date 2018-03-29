primitive _UJSONEq
  """
  An "equality-testing" function that returns true if the path array on the left
  is an exact match of the path array on the right.
  """
  fun apply(
    a: (Array[String] val, UJSONValue),
    a': (Array[String] val, UJSONValue))
  : Bool =>
    _UJSONPathEq(a, a') and _UJSONValueHashFn.eq(a._2, a'._2)

primitive _UJSONPathEq
  """
  An "equality-testing" function that returns true if the path array on the left
  is an exact match of the path array on the right.
  """
  fun apply(
    a: (Array[String] val, UJSONValue),
    a': (Array[String] val, UJSONValue))
  : Bool =>
    (a._1.size() == a'._1.size()) and _UJSONPathEqPrefix(a, a')

primitive _UJSONPathEqPrefix
  """
  An "equality-testing" function that returns true if the path array on the left
  is a prefix of the path array on the right. Note that this is not commutative,
  so the order of arguments matters.
  """
  fun apply(
    a: (Array[String] val, UJSONValue),
    a': (Array[String] val, UJSONValue))
  : Bool =>
    try
      for (index, path_segment) in a._1.pairs() do
        if a'._1(index)? != path_segment then return false end
      end
      true
    else
      false
    end
