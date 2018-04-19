use "collections"

type Token[A: Any #share] is (USize | A)

interface box _TokenSource[A: Any #share]
  fun each_token(fn: {ref(Token[A])} ref)

interface TokenIterator[A: Any #share]
  fun ref next[B: Token[A] = A](): B?
  fun ref next_count(): USize? => next[USize]()?

primitive Tokens[A: Any #share]
  fun to_tokens(src: _TokenSource[A]): TokenIterator[A] =>
    let out = Array[Token[A]]
    src.each_token({(token)(out) => out.push(token) })
    _TokenIteratorFromIterator[A](out.values())

  fun subset[B: (A & Any #share)](iter: TokenIterator[A]): TokenIterator[B] =>
    _TokenIteratorSubset[A, B](iter)

class _TokenIteratorFromIterator[A: Any #share] is TokenIterator[A]
  let _iter: Iterator[Token[A]]
  new ref create(iter': Iterator[Token[A]]) => _iter = iter'
  fun ref next[B: Token[A] = A](): B? => _iter.next()? as B

class _TokenIteratorSubset[
  A: Any #share,
  B: (A & Any #share)]
  is TokenIterator[B]
  let _iter: TokenIterator[A]
  new ref create(iter': TokenIterator[A]) => _iter = iter'
  fun ref next[C: (Token[B] & Any #share)](): C? => _iter.next[C]()?
