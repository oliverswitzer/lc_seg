defmodule LcSegTest do
  use ExUnit.Case
  doctest LcSeg

  import Test.LcSeg.Factory

  alias LcSeg
  alias LcSeg.TranscriptLine

  describe "lexical_chains/1" do
    test "finds all lexical chains in the given transcript" do
      transcript = [
        tr1 = build(:transcript_line, %{text: "Hi president Johnson. What are you doing today?"}),
        tr2 =
          build(:transcript_line, %{
            text: "today I'm doing nothing. I am not a president"
          }),
        tr3 = build(:transcript_line, %{text: "You are a president"})
      ]

      president_chain = %{term: "president", length: 3}
      today_chain = %{term: "today", length: 2}

      assert [
               %{%TranscriptLine{} => [^president_chain, ^today_chain]},
               %{%TranscriptLine{} => [^president_chain, ^today_chain]},
               %{%TranscriptLine{} => [^president_chain]}
             ] = LcSeg.lexical_chains(transcript)
    end
  end
end
