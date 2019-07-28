primitive _Math
  fun saturated_sum[T: (Integer[T] val & Unsigned)](x: T, y: T): T =>
    """
    summing two unsigned integers while avoiding overflow by returning
    the datatypes maximum value in this case.
    """
    (let sum: T, let overflow: Bool) = x.addc(y)
    if overflow then
      T.max_value()
    else
      sum
    end
