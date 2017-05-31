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
    
    a.>converge(b.data()).>converge(c.data())
    b.>converge(c.data()).>converge(a.data())
    c.>converge(a.data()).>converge(b.data())
    
    h.assert_eq[USize](a.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[USize](b.size(), 3)
    h.assert_eq[GSet[String]](a, b)
    h.assert_eq[GSet[String]](b, c)
    h.assert_eq[GSet[String]](c, a)
