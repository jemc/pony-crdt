use "ponytest"
use "../crdt"

class TestLWWSet is UnitTest
  new iso create() => None
  fun name(): String => "crdt.LWWSet"
  
  fun apply(h: TestHelper) =>
    let a = LWWSet[String]
    let b = LWWSet[String]
    let c = LWWSet[String]
    
    a.set("apple", 5)
    b.set("banana", 5)
    c.set("currant", 5)
    
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[LWWSet[String]](a, b)
    h.assert_ne[LWWSet[String]](b, c)
    h.assert_ne[LWWSet[String]](c, a)
    
    a.>converge(b).>converge(c)
    b.>converge(c).>converge(a)
    c.>converge(a).>converge(b)
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
    
    c.unset("currant", 6)
    a.>converge(c)
    b.>converge(c)
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
    
    c.unset("banana", 4)
    c.unset("apple", 5)
    a.>converge(c)
    b.>converge(c)
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
    
    c.unset("banana", 7)
    c.unset("apple", 8)
    a.>converge(c)
    b.>converge(c)
    
    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)

class TestLWWSetDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.LWWSet (ẟ)"
  
  fun apply(h: TestHelper) =>
    let a = LWWSet[String]
    let b = LWWSet[String]
    let c = LWWSet[String]
    
    var a_delta = a.set("apple", 5)
    var b_delta = b.set("banana", 5)
    var c_delta = c.set("currant", 5)
    
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[LWWSet[String]](a, b)
    h.assert_ne[LWWSet[String]](b, c)
    h.assert_ne[LWWSet[String]](c, a)
    
    a.>converge(b_delta).>converge(c_delta)
    b.>converge(c_delta).>converge(a_delta)
    c.>converge(a_delta).>converge(b_delta)
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
    
    c_delta = c.unset("currant", 6)
    a.>converge(c_delta)
    b.>converge(c_delta)
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
    
    c_delta = c.unset("banana", 4)
    c_delta = c.unset("apple", 5, consume c_delta)
    a.>converge(c_delta)
    b.>converge(c_delta)
    
    h.assert_eq[USize](a.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[USize](b.size(), 2)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
    
    c_delta = c.unset("banana", 7)
    c_delta = c.unset("apple", 8, consume c_delta)
    a.>converge(c_delta)
    b.>converge(c_delta)
    
    h.assert_eq[USize](a.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[USize](b.size(), 0)
    h.assert_eq[LWWSet[String]](a, b)
    h.assert_eq[LWWSet[String]](b, c)
    h.assert_eq[LWWSet[String]](c, a)
