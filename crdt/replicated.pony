interface Replicated
  fun ref from_tokens(that: TokensIterator)?
    """
    Deserialize an instance of this data structure from a stream of tokens.
    """

  fun ref each_token(tokens: Tokens)
    """
    Serialize the data structure, capturing each token into the given Tokens.
    """
