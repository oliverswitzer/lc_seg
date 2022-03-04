defmodule LcSeg.TranscriptParser do
  @doc """
  Implement this module to format your conversations to a struct that LcSeg expects
  """

  alias LcSeg.TranscriptLine

  @callback parse(any()) :: {:ok, [TranscriptLine.t()]}
end
