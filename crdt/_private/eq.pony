
interface EqFn[A]
  new val create()
  fun apply(a: A, a': A): Bool

primitive Eq[A: Equatable[A] #read]
  fun apply(a: A, a': A): Bool =>
    a.eq(a')

primitive EqIs[A: Any #any]
  fun apply(a: A, a': A): Bool =>
    a is a'

primitive EqTuple2[A: Equatable[A] #read, B: Equatable[B] #read]
  fun apply(a: (A, B), a': (A, B)): Bool =>
    a._1.eq(a'._1) and a._2.eq(a'._2)
