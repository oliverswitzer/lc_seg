defmodule LcSegTest do
  use ExUnit.Case
  doctest LcSeg

  alias Test.LcSeg.MrtTranscriptParser

  test "greets the world" do
    transcript = MrtTranscriptParser.parse("test/fixtures/transcripts/Bdb001.mrt")
  end
end
