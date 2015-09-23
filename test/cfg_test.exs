defmodule CfgTest do
  use ExUnit.Case
  doctest Cfg

  test "check_config() complains about missing sections" do
    config = """
      [a]
      [b]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["missing sections: 'recipients, sender'"]} == actual
  end


  test "check_config() complains about single missing section" do
    config = """
      [a]
      [recipients]
      [b]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["missing sections: 'sender'"]} == actual
  end


  test "check_config() complains about repeating sections" do
    config = """
      [sender]
      [sender]
      [recipients]
      [recipients]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["repeating sections: 'recipients, sender'"]} == actual
  end


  test "check_config() complains about single repeating section" do
    config = """
      [recipients]
      [sender]
      abc=xyz
      [recipients]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["repeating sections: 'recipients'"]} == actual
  end


  test "check_config() complains about missing, repeating sections" do
    config = """
      [a][b][c]
      [b][a]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["missing sections: 'recipients, sender'", "repeating sections: 'a, b'"]} == actual
  end


  test "check_config() complains about missing sender entry" do
    config = """
      [sender]
      [recipients]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["the sender section requires exactly one entry"]} == actual
  end


  test "check_config() complains about more than one sender entry" do
    config = """
      [sender]
      abc@def.hi=E One
      abd@def.hi=E Two
      [recipients]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["the sender section requires exactly one entry"]} == actual
  end


  test "check_config() recognizes correct config" do
    config = """
      [sender]
      abe@def.hi=This Is Correct
      [recipients]
      """
    actual = Cfg.check_config(config)
    assert :ok == actual
  end
end


defmodule CfgFilesTest do
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
    [sender]
    rts@example.com=Frodo Baggins
    [recipients]
    jd@example.com=John Doe III
    mm@gmail.com=Mickey Mouse   # trailing comment!!
    """
  test "read_config() works", context do
    expected = %{
      "sender" => %{"rts@example.com" => "Frodo Baggins"},
      "recipients" => %{"jd@example.com" => ["John", "Doe III"],
                        "mm@gmail.com" => ["Mickey", "Mouse"]}}
    {:ok, data} = File.open(context[:fpath],
                            fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  @tag content: """
    # config file with repeating keys (email addresses)
        # dangling comment
    [sender]
    rts@example.com=Frodo Baggins
    [recipients]
    abx.fgh@exact.ly=Éso Pita
    fheh@fphfdd.cc=Gulliver Jöllo
    abx.fgh@exact.ly=Charly De Gaulle
    """
  test "read_config() with repeated keys", context do
    expected = %{
      "sender" => %{"rts@example.com" => "Frodo Baggins"},
      "recipients" => %{"abx.fgh@exact.ly" => ["Charly", "De Gaulle"],
                        "fheh@fphfdd.cc" => ["Gulliver", "Jöllo"]}}
    {:ok, data} = File.open(context[:fpath],
                            fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  defp write_file(path, content) do
    {:ok, file} = File.open path, [:write]
    IO.binwrite file, content
    File.close file
  end
end
