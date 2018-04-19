use "ponytest"
use ".."

primitive _TestTokensWellFormed[A: Any val]
  fun apply(h: TestHelper, tokens: TokenIterator[A], loc: SourceLoc = __loc) =>
    var expected: USize = 1
    var actual:   USize = 0
    try
      while true do
        match tokens.next[Token[A]]()?
        | let size: USize => expected = expected + size
        end
        actual = actual + 1
      end
    end
    h.assert_eq[USize](expected, actual, "token count", loc)
