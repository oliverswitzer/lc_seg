# test/measures_test.exs
defmodule Test.MeasuresTest do
  use ExUnit.Case

  describe "local_minima_and_maxima/1" do
    test "returns a map with indices of all local minima and maxima" do
      assert %{maxima: [0, 4, 7], minima: [2, 5]} =
               Measures.local_minima_and_maxima([10, 6, 3, 4, 5, 3, 4, 9])
    end

    test "picks up minima at beginning of a list" do
      assert %{maxima: [1, 5, 8], minima: [0, 3, 6, 9]} =
               Measures.local_minima_and_maxima([2, 10, 6, 3, 4, 5, 3, 4, 9, 1])
    end
  end
end
