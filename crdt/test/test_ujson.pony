use "ponytest"
use ".."

class TestUJSON is UnitTest
  new iso create() => None
  fun name(): String => "crdt.UJSON"

  fun apply(h: TestHelper) =>
    """
    This test implements a few of the examples depicted in the paper:
      A Conflict-Free Replicated JSON Datatype
      (Martin Kleppmann, Alastair R. Beresford)
      https://arxiv.org/abs/1608.03960

    Note that not all of the examples depicted there apply to the UJSON data
    type, because UJSON does not handle ordered lists.

    Because those examples don't exercise the full capabilities of UJSON,
    we also include some examples of our own after the "figure" examples.
    """
    figure_1(h)
    figure_2(h)
    figure_5(h)
    add_wins(h)

  fun figure_1(h: TestHelper) =>
    """
    Concurrent assignment to the same register by different replicas.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    // TODO: use update sugar after fixing ponyc to allow value' as param name.
    p.update(["key"], "A")

    h.assert_false(p.converge(q))
    h.assert_true(q.converge(p))

    var expected = """{"key":"A"}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    p.update(["key"], "B")
    q.update(["key"], "C")

    h.assert_true(p.converge(q))
    h.assert_true(q.converge(p))

    expected = """{"key":["B","C"]}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

  fun figure_2(h: TestHelper) =>
    """
    Modifying a nested map while concurrently the entire map is overwritten.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    p.update(["colors"; "blue"], "#0000ff")

    h.assert_false(p.converge(q))
    h.assert_true(q.converge(p))

    var expected = """{"colors":{"blue":"#0000ff"}}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    p.update(["colors"; "red"], "#ff0000")

    expected = """{"colors":{"red":"#ff0000","blue":"#0000ff"}}"""
    h.assert_eq[String](p.get().string(), expected)

    q.clear(["colors"])
    q.update(["colors"; "green"], "#00ff00")

    expected = """{"colors":{"green":"#00ff00"}}"""
    h.assert_eq[String](q.get().string(), expected)

    h.assert_true(p.converge(q))
    h.assert_true(q.converge(p))

    expected = """{"colors":{"red":"#ff0000","green":"#00ff00"}}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

  fun figure_5(h: TestHelper) =>
    """
    Concurrently assigning values of different types to the same map key.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    p.update(["a"; "x"], "y")

    var expected = """{"a":{"x":"y"}}"""
    h.assert_eq[String](p.get().string(), expected)

    q.update(["a"], "z")

    expected = """{"a":"z"}"""
    h.assert_eq[String](q.get().string(), expected)

    h.assert_true(p.converge(q))
    h.assert_true(q.converge(p))

    expected = """{"a":["z",{"x":"y"}]}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    // Add on some tests for accessing and printing nested values.
    expected = """["z",{"x":"y"}]"""
    h.assert_eq[String](p.get(["a"]).string(), expected)

    expected = """"y""""
    h.assert_eq[String](p.get(["a"; "x"]).string(), expected)

    expected = """"""
    h.assert_eq[String](p.get(["a"; "bogus"]).string(), expected)

  fun add_wins(h: TestHelper) =>
    """
    Concurrent insertion and deletion the same element favors the insertion.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    p.insert(["fruits"], "apple")

    h.assert_false(p.converge(q))
    h.assert_true(q.converge(p))

    var expected = """{"fruits":"apple"}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    p.insert(["fruits"], "dewberry")
    p.remove(["fruits"], "dewberry")
    q.insert(["fruits"], "dewberry")

    expected = """{"fruits":"apple"}"""
    h.assert_eq[String](p.get().string(), expected)

    expected = """{"fruits":["apple","dewberry"]}"""
    h.assert_eq[String](q.get().string(), expected)

    h.assert_true(p.converge(q))
    h.assert_true(q.converge(p))

    expected = """{"fruits":["apple","dewberry"]}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

class TestUJSONDelta is UnitTest
  new iso create() => None
  fun name(): String => "crdt.UJSON (ẟ)"

  fun apply(h: TestHelper) =>
    """
    See docstring for TestUJSON.
    """
    figure_1(h)
    figure_2(h)
    figure_5(h)
    add_wins(h)

  fun figure_1(h: TestHelper) =>
    """
    Concurrent assignment to the same register by different replicas.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    // TODO: use update sugar after fixing ponyc to allow value' as param name.
    var p_delta = p.update(["key"], "A")

    h.assert_false(p.converge(p_delta))
    h.assert_true(q.converge(p_delta))

    var expected = """{"key":"A"}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    p_delta = p.update(["key"], "B")
    var q_delta = q.update(["key"], "C")

    h.assert_true(p.converge(q_delta))
    h.assert_true(q.converge(p_delta))

    expected = """{"key":["B","C"]}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

  fun figure_2(h: TestHelper) =>
    """
    Modifying a nested map while concurrently the entire map is overwritten.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    var p_delta = p.update(["colors"; "blue"], "#0000ff")

    h.assert_false(p.converge(p_delta))
    h.assert_true(q.converge(p_delta))

    var expected = """{"colors":{"blue":"#0000ff"}}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    p_delta = p.update(["colors"; "red"], "#ff0000")

    expected = """{"colors":{"red":"#ff0000","blue":"#0000ff"}}"""
    h.assert_eq[String](p.get().string(), expected)

    var q_delta = q.clear(["colors"])
    q_delta = q.update(["colors"; "green"], "#00ff00", q_delta)

    expected = """{"colors":{"green":"#00ff00"}}"""
    h.assert_eq[String](q.get().string(), expected)

    h.assert_true(p.converge(q_delta))
    h.assert_true(q.converge(p_delta))

    expected = """{"colors":{"red":"#ff0000","green":"#00ff00"}}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

  fun figure_5(h: TestHelper) =>
    """
    Concurrently assigning values of different types to the same map key.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    var p_delta = p.update(["a"; "x"], "y")

    var expected = """{"a":{"x":"y"}}"""
    h.assert_eq[String](p.get().string(), expected)

    var q_delta = q.update(["a"], "z")

    expected = """{"a":"z"}"""
    h.assert_eq[String](q.get().string(), expected)

    h.assert_true(p.converge(q_delta))
    h.assert_true(q.converge(p_delta))

    expected = """{"a":["z",{"x":"y"}]}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    // Add on some tests for accessing and printing nested values.
    expected = """["z",{"x":"y"}]"""
    h.assert_eq[String](p.get(["a"]).string(), expected)

    expected = """"y""""
    h.assert_eq[String](p.get(["a"; "x"]).string(), expected)

    expected = """"""
    h.assert_eq[String](p.get(["a"; "bogus"]).string(), expected)

  fun add_wins(h: TestHelper) =>
    """
    Concurrent insertion and deletion the same element favors the insertion.
    """
    let p = UJSON("p".hash())
    let q = UJSON("q".hash())

    var p_delta = p.insert(["fruits"], "apple")

    h.assert_false(p.converge(p_delta))
    h.assert_true(q.converge(p_delta))

    var expected = """{"fruits":"apple"}"""
    h.assert_eq[String](p.get().string(), expected)
    h.assert_eq[String](q.get().string(), expected)

    p_delta = p.insert(["fruits"], "dewberry")
    p_delta = p.remove(["fruits"], "dewberry", p_delta)
    var q_delta = q.insert(["fruits"], "dewberry")

    expected = """{"fruits":"apple"}"""
    h.assert_eq[String](p.get().string(), expected)

    expected = """{"fruits":["apple","dewberry"]}"""
    h.assert_eq[String](q.get().string(), expected)

    h.assert_true(p.converge(q_delta))
    h.assert_true(q.converge(p_delta))

    h.assert_eq[String](p.get().string(), """{"fruits":["apple","dewberry"]}""")
    h.assert_eq[String](q.get().string(), """{"fruits":["dewberry","apple"]}""")
