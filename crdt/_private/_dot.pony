use ".."
use "collections"

type _Dot is (ID, U32)

primitive _DotHashFn is HashFunction[_Dot]
  // TODO: better hash combine?
  fun hash(x: _Dot): USize => (0x3f * x._1.hash()) + x._2.hash()
  fun eq(x: _Dot, y: _Dot): Bool => (x._1 == y._1) and (x._2 == y._2)
