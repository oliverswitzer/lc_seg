defmodule LcSeg do
  @moduledoc """
  Documentation for `LcSeg`.
  """

  alias LcSeg.LexicalChains
  alias LcSeg.TranscriptLine
  alias LcSeg.LexicalChains.DocumentChains
  alias LcSeg.LexicalChains.Chain
  alias LcSeg.DocumentCleaner

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
          document_chains =
            update_current_chains(term_frequencies, document_chains, allowed_hiatus)

          {
            [{tr, document_chains.current_chain_ids}] ++ output,
            document_chains
          }
      end)

    document_chains =
      document_chains
      |> LexicalChains.score_all_chains()

    output
    |> Enum.reverse()
    |> Enum.map(fn {tr, chain_ids} ->
      {tr,
       Enum.map(chain_ids, fn chain_id ->
         {:ok, chain} = LexicalChains.get_chain(document_chains, chain_id)
         chain
       end)}
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

  defp update_current_chains(term_counts, document_chains, allowed_hiatus) do
    document_chains =
      document_chains
      |> LexicalChains.update_hiatuses(term_counts)
      |> terminate_inactive_chains(allowed_hiatus)

    term_counts
    |> Enum.reduce(document_chains, fn {term, term_count}, document_chains ->
      {:ok, chain_for_term, document_chains} =
        LexicalChains.find_or_create_chain(document_chains, term)

      if chain_for_term.hiatus < allowed_hiatus do
        {:ok, _chain, document_chains} =
          LexicalChains.increment_chain(document_chains, chain_for_term, term_count)

        document_chains
      else
        {:ok, _chain, document_chains} =
          LexicalChains.terminate_chain(document_chains, chain_for_term)

        document_chains
      end
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
