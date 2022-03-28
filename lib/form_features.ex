defmodule FormFeatures do
  @moduledoc """

  """

  @doc """
  Returns a list of all silent moments in the transcript

  Note that any silences preceeded by a question are considered "pauses" in speech and are not considered moments of silence.
  """
  @type transcript_span :: %{start: float, duration: float}
  @spec silences(transcripts :: [TranscriptLine.t()]) ::
          silence_spans :: [transcript_span()]
  def silences(transcript) do
    first_transcript = List.first(transcript)

    {_prev, silences} =
      transcript
      |> combine_overlaps()
      |> Enum.reduce(
        {nil, [%{start: 0.0, duration: first_transcript.start}]},
        fn tr, {prev_tr, silences} ->
          if prev_tr && !ended_with_question?(prev_tr) do
            duration = Float.round(tr.start - prev_tr.end, 1)

            {tr, [%{start: prev_tr.end, duration: duration}] ++ silences}
          else
            {tr, silences}
          end
        end
      )

    silences
    |> Enum.reverse()
  end

  defp ended_with_question?(%{combined_lines: lines}) do
    lines
    |> List.last()
    |> String.ends_with?("?")
  end

  @spec combine_overlaps([TranscriptLine.t()]) ::
          [%{start: float(), lines: [String.t()], end: float()}]
  def combine_overlaps(transcripts) do
    transcripts
    |> Enum.sort_by(& &1.end)
    |> Enum.chunk_while(
      {nil, []},
      fn tr, {previous, chunk} ->
        if previous == nil do
          {:cont,
           {tr,
            %{
              start: tr.start,
              combined_lines: [tr.text],
              end: tr.end
            }}}
        else
          trs_overlap? =
            previous.end >=
              tr.start

          if trs_overlap? do
            {:cont,
             {tr,
              %{
                start: chunk.start,
                combined_lines: chunk.combined_lines ++ [tr.text],
                end: tr.end
              }}}
          else
            {:cont, chunk,
             {tr,
              %{
                start: tr.start,
                combined_lines: [tr.text],
                end: tr.end
              }}}
          end
        end
      end,
      fn {_, transcripts} ->
        {:cont, transcripts, :unused}
      end
    )
  end
end
