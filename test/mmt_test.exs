defmodule MmtTest do
  use ExUnit.Case
  doctest Mmt

  test "the truth" do
    assert 1 + 1 == 2
  end
end


defmodule MmtFilesTest do
  use ExUnit.Case


  setup context do
    {fpath, 0} = System.cmd("mktemp", ["exu.XXXXX.eft"])
    fpath = String.rstrip(fpath)
    write_file(fpath, context[:content])

    on_exit fn ->
      System.cmd("rm", ["-f", fpath])
    end

    {:ok, fpath: fpath}
  end


  @tag content: """
    jd@example.com=John Doe III
    mm@gmail.com=Mickey Mouse
    """
  test "read_config() works", context do
    expected = %{"jd@example.com" => "John Doe III",
                 "mm@gmail.com" => "Mickey Mouse"}
    actual = Mmt.read_config(context[:fpath])
    assert actual == expected
  end


  @tag content: """
    abx.fgh@exact.ly=Éso Pita
    fheh@fphfdd.cc=Gulliver Jöllo
    abx.fgh@exact.ly=Charly De Gaulle
    """
  test "read_config() with repeated keys", context do
    expected = %{"abx.fgh@exact.ly" => "Charly De Gaulle",
                 "fheh@fphfdd.cc" => "Gulliver Jöllo"}
    actual = Mmt.read_config(context[:fpath])
    assert actual == expected
  end


  defp write_file(path, content) do
    {:ok, file} = File.open path, [:write]
    IO.binwrite file, content
    File.close file
  end
end
