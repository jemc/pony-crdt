# pony-crdt

Convergent Replicated Data Types (CRDTs) for the Pony language.

CRDTs are a special class of data types that can be replicated in a highly-available, partition-tolerant distributed system to yield results that are eventually consistent. That is, with enough message passing, replicas will eventually converge to the same result, even faced with arbitrary partitions.

In order to acheive commutativity and idempotence, these data structures all impose certain constraints that are often more limiting than typical localized data structures, but if you can model all the state in your application in terms of CRDTs, then you can get eventually consistent replication "for free". In practice, this kind of consideration is often a critical step to scaling a highly-available stateful service.
