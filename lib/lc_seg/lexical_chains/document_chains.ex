defmodule LcSeg.LexicalChains.DocumentChains do
  @moduledoc """
  A struct representing: 
  * the state of all lexical chains found in a document, as well
  * the "current set" of lexical chains that are being iterated over
  * the length of the whole document (measured in length of TranscriptLine's)
  """

  alias LcSeg.LexicalChains.Chain

  @type t() :: %__MODULE__{
          document_length: number(),
          current_chain_ids: [Chain.uuid()],
          catalog: %{String.t() => Chain.t()}
        }

  defstruct [:document_length, current_chain_ids: [], catalog: %{}]
end
