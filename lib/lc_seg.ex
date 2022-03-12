defmodule LcSeg do
  @moduledoc """
  Documentation for `LcSeg`.
  """

  alias LcSeg.LexicalChains
  alias LcSeg.TranscriptLine
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain
  alias LcSeg.DocumentCleaner

  @spec lexical_cohesion_score([Chain.t()], [Chain.t()]) :: float()
  def lexical_cohesion_score(chain_window_1, chain_window_2) do
    # Don't think we can use MapSet here anymore, since score's *should* be different even for a chain with the same term since frequencies may vary from window to window now... need to figure out how to use MapSet.intersection somehow....
    chain_window_1 = MapSet.new(chain_window_1)
    chain_window_2 = MapSet.new(chain_window_2)

    common_chains = MapSet.intersection(chain_window_1, chain_window_2)

    chains_sum = sum_chains(common_chains)
    chains_sum / :math.sqrt(chains_sum * chains_sum)
  end

  defp sum_chains(common_chains) do
    common_chains
    |> Enum.map(&(&1.score * &1.score))
    |> Enum.sum()
  end

  @type lexical_chains_option :: {:allowed_hiatus, number()}
  @spec lexical_chains([TranscriptLine.t()], [lexical_chains_option()]) ::
          [{TranscriptLine.t(), [Chain.t()]}]
  def lexical_chains(transcript_lines, opts \\ []) do
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

          LexicalChains.score_chain(
            document_chains,
            chain,
            term_frequencies[chain.term]
          )
        end)

      {tr, chains}
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
