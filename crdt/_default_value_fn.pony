// TODO: Use Pony's future value-dependent types instead of this hack.
interface val _DefaultValueFn[A]
  new val create()
  fun apply(): A

primitive _DefaultValueString is _DefaultValueFn[String]
  new create() => None
  fun apply(): String => ""

primitive _DefaultValueNumber[A: (Number & Real[A] val)] is _DefaultValueFn[A]
  new create() => None
  fun apply(): A => A.from[U8](0)
