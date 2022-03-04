defmodule LcSeg.TranscriptParser do
  @doc """
  Implement this module to format your conversations to a struct that LcSeg expects
  """

  defmodule TranscriptLine do
    @type t :: %{
            text: String.t(),
            start: float(),
            end: float()
          }
    @enforce_keys [:text, :start, :end]
    defstruct [:text, :start, :end]
  end

  @callback parse(any()) :: [TranscriptLine.t()]
end
