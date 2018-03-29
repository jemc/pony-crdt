use std = "collections"

type UJSONValue is (None | Bool | I64 | F64 | String)

primitive _UJSONValueHashFn is std.HashFunction[UJSONValue]
  fun hash(x': UJSONValue): U64 => digestof x'
  fun eq(x': UJSONValue, y: UJSONValue): Bool =>
    match x'
    | let x: None   => y is None
    | let x: Bool   => try x == (y as Bool)   else false end
    | let x: I64    => try x == (y as I64)    else false end
    | let x: F64    => try x == (y as F64)    else false end
    | let x: String => try x == (y as String) else false end
    end
