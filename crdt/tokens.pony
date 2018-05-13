interface ref _TokensSource
  fun ref each_token(tokens: Tokens)

class Tokens
  embed array: Array[Any val] = array.create()
  
  new ref create() => None
  fun ref push(a: Any val) => array.push(a)
  fun ref from(s: _TokensSource) => s.each_token(this)
  fun iterator(): TokensIterator => _TokensIterator(array.values())

interface TokensIterator
  fun ref next[A: Any val](): A?

class _TokensIterator
  let _iter: Iterator[Any val]
  
  new ref create(iter': Iterator[Any val]) => _iter = iter'
  fun ref next[A: Any val](): A? => _iter.next()? as A
