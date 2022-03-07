defmodule LcSeg.LexicalChains.Chain do
  @type uuid :: String.t()
  @type t() :: %__MODULE__{
          term: String.t(),
          id: uuid(),
          term_freq: number(),
          length: number(),
          hiatus: number(),
          score: number()
        }
  @enforce_keys [:term]

  defstruct [:term, :id, score: nil, term_freq: 0, length: 0, hiatus: 0]
end
