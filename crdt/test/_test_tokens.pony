use "ponytest"
use ".."

primitive _TestTokensWellFormed
  fun apply(h: TestHelper, tokens: Tokens, loc: SourceLoc = __loc) =>
    var expected: USize = 1
    var actual:   USize = 0
    let iter = tokens.array.values()
    try
      while true do
        match iter.next()?
        | let size: USize => expected = expected + size
        end
        actual = actual + 1
      end
    end
    h.assert_eq[USize](expected, actual, "token count", loc)
