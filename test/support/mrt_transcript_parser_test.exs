defmodule Test.LcSeg.MrtTranscriptParserTest do
  use ExUnit.Case

  alias Test.LcSeg.MrtTranscriptParser
  alias LcSeg.TranscriptLine

  test "converts MRT files to transcripts correctly" do
    Path.wildcard("test/fixtures/transcripts/*.mrt")
    |> Enum.each(fn path ->
      {:ok, transcript_lines} = MrtTranscriptParser.parse(path)

      assert match?(%TranscriptLine{}, List.first(transcript_lines)),
             "First: Extracts valid transcript lines from #{path}"

      assert match?(%TranscriptLine{}, List.last(transcript_lines)),
             "Last: Extracts valid transcript lines from #{path}"
    end)
  end
end
