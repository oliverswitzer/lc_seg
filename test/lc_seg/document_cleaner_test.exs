# test/lc_seg/document_cleaner_test.exs
defmodule LcSeg.DocumentCleanerTest do
  use ExUnit.Case

  alias LcSeg.DocumentCleaner

  describe "clean/1" do
    test "removes stopwords and grammar" do
      text = "Hi. How are you? Today we're going to discuss LcSeg"
      assert "discuss LcSeg" = DocumentCleaner.clean(text)
    end

    test "stems each non-stopword word" do
      text = "Hi. Today I received some futuristic letters in the mail"
      assert "receiv futurist letter mail" = DocumentCleaner.clean(text)
    end
  end
end
