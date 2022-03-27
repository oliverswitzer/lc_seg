defmodule LcSeg do
  @moduledoc """
  An elixir implementation of the LcSeg algorithim featured in Discourse 
  Segmentation of Multi-Party Conversation (Galley 2003)

  Use this module to calculate the Lexical Cohesion (ie similarity between windows of a conversation).
  over the course of a conversation. 

  The method computes the cosine simlarity between overlapping windows of lexical 
  chains of fixed window size `k` (where k is measured in number of transcript lines.)

  Lexical chains used in this paper are simple, and are built around term repitions 
  of stemmed words.

  Example usage:
  iex> transcripts = YourTranscriptParser.parse()
  [%TranscriptLine{text: "Hello.", start: 0.0, end: 21.2}, ...]

  iex> cohesion = LcSeg.cohesion_over_time(transcripts, k: 3)
  [%{playback_time: 0.0, cohesion: 0.8}, ...]
  iex> LcSeg.topic_change_probabilities(cohesion)
  [%{playback_time: 0.0, probability: 0.81}, ...]
  """

  alias LcSeg.LexicalChains
  alias LcSeg.TranscriptLine
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain
  alias LcSeg.DocumentCleaner

  @type cohesion_datapoint :: %{playback_time: float(), cohesion: float()}
  @type topic_change_datapoint :: %{playback_time: float(), probability: float()}

  @doc """
  Will return an array of topic change data points. Each data point is an approximation
  of the probability that a topic change occured. This probability is approximated 
  via computing the rate of change of cohesion at each minima in the cohesion over time.
  """
  @spec topic_change_probabilities([cohesion_datapoint()]) :: [topic_change_datapoint()]
  def topic_change_probabilities(cohesion_over_time) do
    %{maxima: local_maxima, minima: local_minima} =
      cohesion_over_time
      |> Enum.map(& &1.cohesion)
      |> Measures.local_minima_and_maxima()

    probabilities =
      local_minima
      |> Enum.map(fn minima ->
        siblings = closest_siblings(minima, local_maxima)

        if length(Enum.reject(siblings, &is_nil/1)) == 2 do
          [left_maxima, right_maxima] = siblings
          c = cohesion_over_time

          probability =
            topic_change_probability(
              cohesion_at(c, left_maxima),
              cohesion_at(c, right_maxima),
              cohesion_at(c, minima)
            )

          %{
            playback_time: Enum.at(c, minima) |> Map.get(:playback_time),
            probability: probability
          }
        end
      end)
      |> Enum.reject(&is_nil/1)

    stats =
      probabilities
      |> Enum.map(& &1.probability)
      |> Statistex.statistics()

    probabilities
    |> Enum.filter(fn p ->
      p.probability > stats.average - 0.05 * stats.standard_deviation
    end)
  end

  defp topic_change_probability(left, right, minima) do
    1 / 2 * (left + right - 2 * minima)
  end

  defp cohesion_at(cohesion_over_time, index) do
    Enum.at(cohesion_over_time, index)
    |> Map.get(:cohesion)
  end

  def closest_siblings(index, indices) do
    right =
      indices
      |> Enum.find(&(&1 > index))

    left =
      indices
      |> Enum.reverse()
      |> Enum.find(&(&1 < index))

    [left, right]
  end

  @doc """
  Returns an array of cohesion data points. Each data point represents the lexical 
  "cohesion" between two adjacent windows of sized `k` in the transcript. `k` is
  measured in distinct TranscriptLine's.

  Cohesion is a measure of cosine similarity between the overlapping lexical chains
  and their associated scores in the adjacent windows.
  """
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
