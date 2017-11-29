trait Convergent[A: Convergent[A] #read]
  fun ref converge(that: box->A): Bool
    """
    Converge from that data structure into this one, mutating this one.
    The other data structure may be either a delta-state or a complete state.
    Returns true if the convergence added new information to the data structure.
    """
