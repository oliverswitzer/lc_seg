defmodule LcSeg.TranscriptLine do
  @type t :: %{
          text: String.t(),
          start: float(),
          end: float()
        }
  @enforce_keys [:text, :start, :end]
  defstruct [:text, :start, :end]
end
