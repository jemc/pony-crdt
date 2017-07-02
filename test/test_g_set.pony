use "ponytest"
use "../crdt"

class TestGSet is UnitTest
  new iso create() => None
  fun name(): String => "crdt.GSet"
  
  fun apply(h: TestHelper) =>
    let a = GSet[String]
    let b = GSet[String]
    let c = GSet[String]
    
    a.set("apple")
    b.set("banana")
    c.set("currant")
    
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[GSet[String]](a, b)
    h.assert_ne[GSet[String]](b, c)
    h.assert_ne[GSet[String]](c, a)
    
    a.>converge(b).>converge(c)
    b.>converge(c).>converge(a)
    c.>converge(a).>converge(b)
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[GSet[String]](a, b)
    h.assert_eq[GSet[String]](b, c)
    h.assert_eq[GSet[String]](c, a)

class TestGSetDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.GSet (ẟ)"
  
  fun apply(h: TestHelper) =>
    let a = GSet[String]
    let b = GSet[String]
    let c = GSet[String]
    
    let a_delta = a.set("apple")
    let b_delta = b.set("banana")
    let c_delta = c.set("currant")
    
    h.assert_eq[USize](a.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_eq[USize](b.size(), 1)
    h.assert_ne[GSet[String]](a, b)
    h.assert_ne[GSet[String]](b, c)
    h.assert_ne[GSet[String]](c, a)
    
    a.>converge(b_delta).>converge(c_delta)
    b.>converge(c_delta).>converge(a_delta)
    c.>converge(a_delta).>converge(b_delta)
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[GSet[String]](a, b)
    h.assert_eq[GSet[String]](b, c)
    h.assert_eq[GSet[String]](c, a)
