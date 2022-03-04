defmodule Test.LcSeg.MrtTranscriptParser do
  @behaviour LcSeg.TranscriptParser

  alias LcSeg.TranscriptLine

  @impl LcSeg.TranscriptParser
  def parse(mrt_file_path) do
    raw_transcript_xml = File.read!(mrt_file_path)

    {:ok, parsed} =
      Floki.parse_document(raw_transcript_xml)
      |> IO.inspect()

    transcript_lines =
      parsed
      |> Floki.find("transcript segment")
      |> Enum.map(fn segment ->
        time_range =
          ["starttime", "endtime"]
          |> Enum.map(&(hd(Floki.attribute(segment, &1)) |> String.to_float()))

        parsed =
          segment
          |> Floki.text()
          |> String.trim()

        if String.length(parsed) > 0,
          do: %TranscriptLine{
            text: parsed,
            start: Enum.at(time_range, 0),
            end: Enum.at(time_range, 1)
          },
          else: nil
      end)
      |> Enum.reject(&is_nil(&1))

    {:ok, transcript_lines}
  end
end
