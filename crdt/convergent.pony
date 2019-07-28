use "_private"

interface Convergent[A: Convergent[A] #read]
  fun ref converge(that: box->A): Bool
    """
    Converge from that data structure into this one, mutating this one.
    The other data structure may be either a delta-state or a complete state.
    Returns true if the convergence added new information to the data structure.
    """

  new ref _create_in(ctx: DotContext)
    """
    Create an instance of the data structure within the context (if applicable).
    """

  fun ref _converge_empty_in(ctx: DotContext box): Bool
    """
    Converge an imaginary instance of a data structure with no information
    other than being within the given context. This saves on an allocation.
    """

  fun is_empty(): Bool
    """
    Return true if the data structure contains no information (bottom state).
    """
