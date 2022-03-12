defmodule LcSeg.LexicalChains.Chain do
  @type uuid :: String.t()
  @type t() :: %__MODULE__{
          term: String.t(),
          id: uuid(),
          length: number(),
          hiatus: number(),
          score: number() | nil
        }
  @enforce_keys [:term]

  defstruct [:term, :id, score: nil, length: 0, hiatus: 0]
end
