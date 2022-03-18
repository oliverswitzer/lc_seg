defmodule LcSeg do
  @moduledoc """
  Documentation for `LcSeg`.
  """

  alias LcSeg.LexicalChains
  alias LcSeg.TranscriptLine
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain
  alias LcSeg.DocumentCleaner

  @type cohesion_datapoint :: %{playback_time: float(), cohesion: float()}
  @type cohesion_over_time_options :: {:k, number()}
  @spec cohesion_over_time(
          [TranscriptWithMetadata.t()],
          cohesion_over_time_options()
        ) :: [cohesion_datapoint()]
  def cohesion_over_time(transcripts, opts \\ []) do
    k = Keyword.get(opts, :k, 2)
    document_length = length(transcripts)

    transcripts
    |> to_windows_of_size(k)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [window_1, window_2] ->
      overlapping_chains = overlapping_chains(window_1.chains, window_2.chains)
      score_vector_1 = score_window(overlapping_chains, window_1, document_length)
      score_vector_2 = score_window(overlapping_chains, window_2, document_length)

      %{
        cohesion: cosine_similarity(score_vector_1, score_vector_2),
        playback_time: window_2.first_transcript.start
      }
    end)
  end

  defp to_windows_of_size(transcripts, k) do
    transcripts
    |> Enum.chunk_every(k, k - 1)
    |> Enum.map(fn transcript_window ->
      updated_window =
        transcript_window
        |> group_chains_and_frequencies_for_window()

      updated_window
      |> Map.put(:chains, Enum.uniq_by(updated_window.chains, & &1.id))
    end)
  end

  defp score_window(chains, %{term_frequencies: term_frequencies}, document_length) do
    chains
    |> Enum.map(fn c ->
      tf = term_frequencies[c.term] || 0
      tf * :math.log(document_length / c.length)
    end)
  end

  def overlapping_chains(chain_window_1, chain_window_2) do
    chain_window_1_ids = MapSet.new(chain_window_1)
    chain_window_2_ids = MapSet.new(chain_window_2)

    MapSet.intersection(chain_window_1_ids, chain_window_2_ids)
    |> MapSet.to_list()
  end

  defp group_chains_and_frequencies_for_window(transcripts) do
    window = %{
      term_frequencies: %{},
      chains: [],
      first_transcript: List.first(transcripts).transcript
    }

    transcripts
    |> Enum.reduce(window, fn tr, acc ->
      acc
      |> Map.put(
        :term_frequencies,
        merge_frequencies(acc.term_frequencies, tr.term_frequencies)
      )
      |> Map.put(:chains, acc.chains ++ tr.chains)
    end)
  end

  defp merge_frequencies(a, b) do
    Map.merge(a, b, fn _k, v1, v2 -> v1 + v2 end)
  end

  @spec cosine_similarity([float()], [float()]) :: float()
  def cosine_similarity(vector_1, vector_2) do
    if Enum.empty?(vector_1) || Enum.empty?(vector_2) || Enum.sum(vector_1) == 0 ||
         Enum.sum(vector_2) == 0 do
      0.0
    else
      Similarity.cosine(vector_1, vector_2)
    end
  end

  defmodule TranscriptWithMetadata do
    @type t :: %__MODULE__{
            transcript: TranscriptLine.t(),
            term_frequencies: %{String.t() => number()},
            chains: [Chain.t()]
          }
    defstruct transcript: nil, term_frequencies: %{}, chains: []
  end

  @type calculate_lexical_chains_option :: {:allowed_hiatus, number()}
  @spec calculate_lexical_chains(
          [TranscriptLine.t()],
          [calculate_lexical_chains_option()]
        ) :: [
          TranscriptWithMetadata.t()
        ]
  def calculate_lexical_chains(transcript_lines, opts \\ []) do
    allowed_hiatus = Keyword.get(opts, :allowed_hiatus, 1)
    document_length = length(transcript_lines)

    {output, document_chains} =
      transcript_lines
      |> with_term_frequencies()
      |> Enum.reduce({[], %DocumentChains{document_length: document_length}}, fn
        %{transcript: tr, term_frequencies: term_frequencies}, {output, document_chains} ->
          terms = Map.keys(term_frequencies)

          document_chains =
            update_current_chains(
              terms,
              document_chains,
              allowed_hiatus
            )

          {
            [{tr, term_frequencies, document_chains.current_chain_ids}] ++ output,
            document_chains
          }
      end)

    output
    |> Enum.reverse()
    |> Enum.map(fn {tr, term_frequencies, chain_ids} ->
      chains =
        Enum.map(chain_ids, fn chain_id ->
          {:ok, chain} = LexicalChains.get_chain(document_chains, chain_id)
          chain
        end)

      %TranscriptWithMetadata{
        transcript: tr,
        chains: chains,
        term_frequencies: term_frequencies
      }
    end)
  end

  defp with_term_frequencies(transcript_lines) do
    transcript_lines
    |> Enum.map(fn %{text: text} = tr ->
      cleaned_text = DocumentCleaner.clean(text)

      term_frequencies =
        cleaned_text
        |> String.split(" ")
        |> Enum.frequencies()
        |> Map.reject(fn {term, _count} -> term == " " end)

      %{transcript: tr, term_frequencies: term_frequencies}
    end)
  end

  defp update_current_chains(terms, document_chains, allowed_hiatus) do
    document_chains =
      document_chains
      |> LexicalChains.update_hiatuses(terms)
      |> terminate_inactive_chains(allowed_hiatus)

    terms
    |> Enum.reduce(document_chains, fn term, document_chains ->
      {:ok, chain_for_term, document_chains} =
        LexicalChains.find_or_create_chain(document_chains, term)

      {:ok, _chain, document_chains} =
        LexicalChains.increment_chain(document_chains, chain_for_term)

      document_chains
    end)
  end

  defp terminate_inactive_chains(document_chains, allowed_hiatus) do
    LexicalChains.current_chains(document_chains)
    |> Enum.filter(&(&1.hiatus > allowed_hiatus))
    |> Enum.reduce(document_chains, fn chain, dc ->
      {:ok, _chain, dc} = LexicalChains.terminate_chain(dc, chain)
      dc
    end)
  end
end
