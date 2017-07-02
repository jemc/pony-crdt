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
