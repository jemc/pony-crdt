use "ponytest"
use ".."

class TestUJSONNode is UnitTest
  new iso create() => None
  fun name(): String => "crdt.UJSONNode (parse/print)"

  fun apply(h: TestHelper) =>
    ///
    // Keywords

    example(h, "true",  "true")
    example(h, "false", "false")
    example(h, "null",  "null")

    ///
    // Numbers

    example(h, "123", "123")
    example(h, "-123", "-123")
    example(h, "123.456", "123.456")
    example(h, "-123.456", "-123.456")
    example(h, "123e2", "12300")
    example(h, "-123e-2", "-1.23")
    example(h, "-123.456e2", "-12345.6")
    example(h, "123.456e-2", "1.23456")

    ///
    // Maps and Sets

    example(h,
      """{"fruit":"apple"}""",
      """{"fruit":"apple"}""")

    example(h,
      """["apple","banana","currant"]""",
      """["apple","banana","currant"]""")

    example(h,
      """{"fruit":["apple","banana","currant"],"edible":true}""",
      """{"fruit":["apple","banana","currant"],"edible":true}""")

    example(h,
      """{"n":{"e":{"s":{"t":true}}}}""",
      """{"n":{"e":{"s":{"t":true}}}}""")

    example(h, // a single-element set will not be rendered as a set
      """{"fruit":["apple"]}""",
      """{"fruit":"apple"}""")

    example(h, // an empty set will be pruned
      """{"fruit":"apple","empty":[]}""",
      """{"fruit":"apple"}""")

    example(h, // an empty map will be pruned
      """{"fruit":"apple","empty":{}}""",
      """{"fruit":"apple"}""")

    example(h, // duplicate elements in a set will be pruned
      """{"fruit":["apple","banana","apple"]}""",
      """{"fruit":["apple","banana"]}""")

    example(h, // duplicate keys in a map will be merged
      """{"fruit":"apple","fruit":"banana","edible":true}""",
      """{"fruit":["apple","banana"],"edible":true}""")

    example(h, // a set of maps will be merged
      """[{"fruit":"apple"},{"fruit":"banana"},{"edible":true}]""",
      """{"fruit":["apple","banana"],"edible":true}""")

    example(h, // a set of maps and non-maps will only merge the maps
      """[1,2,3,{"fruit":"apple"},{"fruit":"banana"},{"edible":true}]""",
      """[1,2,3,{"fruit":["apple","banana"],"edible":true}]""")

    example(h, // empty sets and maps within a set will be pruned
      """[1,2,3,[],{},[{}],[[[]]]]""",
      """[1,2,3]""")

    example(h, // nested sets will be merged
      """[1,2,3,[4,[5,[6]]],[[[7]]]]""",
      """[1,2,3,4,5,6,7]""")

    ///
    // Void (no data present at all)

    example(h, "", "")
    example(h, "{}", "")
    example(h, "[]", "")
    example(h, "[{}]", "")
    example(h, "[{},{},{}]", "")
    example(h, "[[],[],[]]", "")
    example(h, "[[[[[]]]]]", "")

  fun example(
    h: TestHelper,
    parse: String,
    print: String,
    loc: SourceLoc = __loc)
  =>
    let errs = Array[String]
    try
      let actual = UJSONNode.from_string(parse, errs)?.string()
      h.assert_eq[String](consume actual, print, "", loc)
    else
      for err in errs.values() do h.log(err) end
      h.assert_no_error({()? => error }, "Couldn't parse: " + parse, loc)
    end
