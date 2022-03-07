defmodule LcSeg do
  @moduledoc """
  Documentation for `LcSeg`.
  """

  alias LcSeg.LexicalChains
  alias LcSeg.LexicalChains.DocumentChains

  @type lexical_chains_option :: {:allowed_hiatus, number()}
  @spec lexical_chains([TranscriptLine.t()], [lexical_chains_option()]) ::
          [%{TranscriptLine.t() => [LexicalChain.t()]}]
  def lexical_chains(transcript_lines, opts) do
    allowed_hiatus = Keyword.get(opts, :allowed_hiatus, 1)

    transcript_lines
    |> Enum.map(fn %{text: text} = tr ->
      Map.put(tr, :text, clean_document(text))
    end)
    |> Enum.reduce({[], %DocumentChains{}}, fn
      tr, {output, document_chains} ->
        term_counts = Enum.frequencies(tr.text |> String.split(" "))
        document_chains = update_current_chains(term_counts, document_chains, allowed_hiatus)

        {tr, document_chains.current_chain_ids} ++ output
    end)
  end

  defp update_current_chains(term_counts, document_chains, allowed_hiatus) do
    document_chains = LexicalChains.update_hiatuses(document_chains, term_counts)

    term_counts
    |> Enum.reduce(document_chains, fn {term, term_count}, document_chains ->
      {:ok, chain_for_term, document_chains} =
        LexicalChains.find_or_create_chain(document_chains, term)

      if chain_for_term.hiatus < allowed_hiatus do
        # Should set hiatus to zero 
        {:ok, _chain, document_chains} =
          LexicalChains.increment_chain(document_chains, chain_for_term, term_count)

        document_chains
      else
        {:ok, _chain, document_chains} =
          LexicalChains.terminate_and_score_chain(document_chains, chain_for_term)

        document_chains
      end
    end)
  end

  def remove_stopwords(text) do
    String.split(text, " ")
    |> Enum.filter(fn w -> String.trim(w) == "president" || String.trim(w) == "today" end)
    |> Enum.join(" ")
  end

  @spec repeated_terms([TranscriptLine.t()]) :: %{String.t() => number()}
  def repeated_terms(transcript_lines) do
    transcript_lines
    |> Enum.map_join(" ", fn tr -> clean_document(tr.text) end)
    |> String.split(" ")
    |> Enum.frequencies()
  end

  defp clean_document(text) do
    # Steal from Standuops (remove grammer, port stem, etc)
  end
end
