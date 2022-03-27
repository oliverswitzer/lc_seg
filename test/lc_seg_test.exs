defmodule LcSegTest do
  use ExUnit.Case

  import Euclid.Assertions
  import Test.LcSeg.Factory

  alias LcSeg
  alias LcSeg.DocumentCleaner

  setup do
    transcript = [
      "Hi President Johnson. How are those bananas?",
      "The bananas are great! As President I enjoy them.",
      "Great Mr. President",
      "Johnson?"
    ]

    [transcript: transcript]
  end

  describe "cohesion_over_time/2" do
    test "scores overlapping chains over a fixed size window of size 3 (k)" do
      transcript =
        [
          "Hi President Johnson. How is that pineapple?",
          "The pineapple is great!",
          "Great Mr. President",
          "Johnson?",
          "Yes I'm here, what is it?",
          "Oh, nothing, I thought you we're gone",
          "No I'm here, just eating this pineapple"
        ]
        |> to_transcript_lines()
        |> LcSeg.calculate_lexical_chains()

      cohesion_over_time = LcSeg.cohesion_over_time(transcript, k: 3)

      assert length(cohesion_over_time) == 3

      transcript_3_start = Enum.at(transcript, 2).transcript.start
      transcript_5_start = Enum.at(transcript, 4).transcript.start
      transcript_7_start = Enum.at(transcript, 6).transcript.start

      assert [
               %{playback_time: ^transcript_3_start, cohesion: _cohesion_1},
               %{playback_time: ^transcript_5_start, cohesion: _cohesion_2},
               %{playback_time: ^transcript_7_start, cohesion: _cohesion_3}
             ] = cohesion_over_time
    end

    test "scores overlapping chains over a fixed size window of 2 (k)", %{transcript: transcript} do
      transcript =
        transcript
        |> to_transcript_lines()
        |> LcSeg.calculate_lexical_chains()

      cohesion_over_time = LcSeg.cohesion_over_time(transcript, k: 2)

      assert length(cohesion_over_time) == 3

      transcript_2_start = Enum.at(transcript, 1).transcript.start
      transcript_3_start = Enum.at(transcript, 2).transcript.start
      transcript_4_start = Enum.at(transcript, 3).transcript.start

      assert [
               %{playback_time: ^transcript_2_start, cohesion: _cohesion_1},
               %{playback_time: ^transcript_3_start, cohesion: _cohesion_2},
               %{playback_time: ^transcript_4_start, cohesion: _cohesion_3}
             ] = cohesion_over_time

      cohesion_over_time
      |> Enum.each(fn %{cohesion: c} ->
        assert c >= 0 && c <= 1
      end)
    end
  end

  describe "calculate_lexical_chains/1" do
    test "finds and scores all lexical chains in the given transcript", %{transcript: transcript} do
      transcript = to_transcript_lines(transcript)
      johnson_chain = %{term: DocumentCleaner.clean("Johnson"), length: 1}
      second_johnson_chain = %{term: DocumentCleaner.clean("Johnson"), length: 1}
      banana_chain = %{term: DocumentCleaner.clean("banana"), length: 2}
      president_chain = %{term: DocumentCleaner.clean("President"), length: 3}
      enjoy_chain = %{term: DocumentCleaner.clean("enjoy"), length: 1}

      assert transcript = LcSeg.calculate_lexical_chains(transcript)

      %{
        transcript: first_line,
        chains: first_chains,
        term_frequencies: _first_line_frequencies
      } = Enum.at(transcript, 0)

      assert %{text: "Hi President Johnson. How are those bananas?"} = first_line

      assert_eq(
        [johnson_chain, president_chain, banana_chain],
        term_and_length(first_chains),
        ignore_order: true
      )

      %{
        transcript: second_line,
        chains: second_chains,
        term_frequencies: _second_line_frequencies
      } = Enum.at(transcript, 1)

      assert %{text: "The bananas are great! As President I enjoy them."} = second_line

      assert_eq(
        [johnson_chain, banana_chain, president_chain, enjoy_chain],
        term_and_length(second_chains),
        ignore_order: true
      )

      %{transcript: third_line, chains: third_chains, term_frequencies: _third_line_frequencies} =
        Enum.at(transcript, 2)

      assert %{text: "Great Mr. President"} = third_line

      # Johnson chain disappears in third line because it has not been seen for 1 transcript line, which is the default config specified by allowed_hiatus
      assert_eq(
        [president_chain, enjoy_chain, banana_chain],
        term_and_length(third_chains),
        ignore_order: true
      )

      %{
        transcript: fourth_line,
        chains: fourth_chains,
        term_frequencies: _fourth_line_frequencies
      } = Enum.at(transcript, 3)

      assert %{text: "Johnson?"} = fourth_line

      # Johnson chain reappears in fourth line with only a length of 1, since this is a new chain for Johnson.
      assert_eq(
        [second_johnson_chain, president_chain],
        term_and_length(fourth_chains),
        ignore_order: true
      )
    end

    defp term_and_length(chains) do
      chains
      |> Enum.map(&%{term: &1.term, length: &1.length})
    end
  end

  defp to_transcript_lines(raw_transcripts) do
    raw_transcripts
    |> Enum.with_index()
    |> Enum.map(&build(:transcript_line, %{text: elem(&1, 0), start: elem(&1, 1)}))
  end
end
