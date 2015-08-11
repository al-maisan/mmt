defmodule MmtTest do
  use ExUnit.Case
  doctest Mmt

  test "email address substitution works" do
    template = """
      Hello buddy,
      this is your email: %EA%%EA%.

      Thanks!
      """
    body = """
      Hello buddy,
      this is your email: 1@xy.com1@xy.com.

      Thanks!
      """
    actual = Mmt.prep_email({template, "1@xy.com", "Not", "Needed"})
    assert {"1@xy.com", body} == actual
  end


  test "first name substitution works" do
    template = """
      Hello %FN%,
      this is your email: %EA%%EA%.

      Thanks!
      """
    body = """
      Hello Goth,
      this is your email: 2@xy.com2@xy.com.

      Thanks!
      """
    actual = Mmt.prep_email({template, "2@xy.com", "Goth", "Mox"})
    assert {"2@xy.com", body} == actual
  end


  test "last name substitution works" do
    template = """
      Hello %FN% // %LN%,
      this is your email: %EA%%EA%.

      Thanks!
      """
    body = """
      Hello King // Kong,
      this is your email: 3@xy.com3@xy.com.

      Thanks!
      """
    actual = Mmt.prep_email({template, "3@xy.com", "King", "Kong"})
    assert {"3@xy.com", body} == actual
  end
end


defmodule MmtFilesTest do
  use ExUnit.Case


  setup context do
    {fpath, 0} = System.cmd("mktemp", ["mmt.XXXXX.ini"])
    fpath = String.rstrip(fpath)
    write_file(fpath, context[:content])

    on_exit fn ->
      System.cmd("rm", ["-f", fpath])
    end

    {:ok, fpath: fpath}
  end


  @tag content: """
    # Easy version
    jd@example.com=John Doe III
    mm@gmail.com=Mickey Mouse   # trailing comment!!
    """
  test "read_config() works", context do
    expected = %{"jd@example.com" => ["John", "Doe III"],
                 "mm@gmail.com" => ["Mickey", "Mouse"]}
    actual = Mmt.read_config(context[:fpath])
    assert actual == expected
  end


  @tag content: """
    # config file with repeating keys (email addresses)
        # dangling comment
    abx.fgh@exact.ly=Éso Pita
    fheh@fphfdd.cc=Gulliver Jöllo
    abx.fgh@exact.ly=Charly De Gaulle
    """
  test "read_config() with repeated keys", context do
    expected = %{"abx.fgh@exact.ly" => ["Charly", "De Gaulle"],
                 "fheh@fphfdd.cc" => ["Gulliver", "Jöllo"]}
    actual = Mmt.read_config(context[:fpath])
    assert actual == expected
  end


  defp write_file(path, content) do
    {:ok, file} = File.open path, [:write]
    IO.binwrite file, content
    File.close file
  end
end
