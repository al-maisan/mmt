defmodule MmtTest do
  use ExUnit.Case
  doctest Mmt

  test "construct_cmd()" do
    path = "/tmp/mmt.kTuJU.eml"
    sender = %{"mmt@chlo.cc" => ["Frodo", "Baggins"]}
    subj = "hello from mmt"
    addr = "r2@ahfdo.cc"
    expected = 'cat /tmp/mmt.kTuJU.eml | mail -a "From: Frodo Baggins <mmt@chlo.cc>" -s "hello from mmt" r2@ahfdo.cc'

    actual = Mmt.construct_cmd(path, sender, subj, addr)
    assert expected == actual
  end


  test "check_config() complains about missing sections" do
    config = """
      [a]
      [b]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["missing sections: 'recipients, sender'"]} == actual
  end


  test "check_config() complains about single missing section" do
    config = """
      [a]
      [recipients]
      [b]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["missing sections: 'sender'"]} == actual
  end


  test "check_config() complains about repeating sections" do
    config = """
      [sender]
      [sender]
      [recipients]
      [recipients]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["repeating sections: 'recipients, sender'"]} == actual
  end


  test "check_config() complains about single repeating section" do
    config = """
      [recipients]
      [sender]
      abc=xyz
      [recipients]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["repeating sections: 'recipients'"]} == actual
  end


  test "check_config() complains about missing, repeating sections" do
    config = """
      [a][b][c]
      [b][a]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["missing sections: 'recipients, sender'", "repeating sections: 'a, b'"]} == actual
  end


  test "check_config() complains about missing sender entry" do
    config = """
      [sender]
      [recipients]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["the sender section requires exactly one entry"]} == actual
  end


  test "check_config() complains about more than one sender entry" do
    config = """
      [sender]
      abc@def.hi=E One
      abd@def.hi=E Two
      [recipients]
      """
    actual = Mmt.check_config(config)
    assert {:error, ["the sender section requires exactly one entry"]} == actual
  end


  test "check_config() recognizes correct config" do
    config = """
      [sender]
      abe@def.hi=This Is Correct
      [recipients]
      """
    actual = Mmt.check_config(config)
    assert :ok == actual
  end


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


  test "dry_run() works" do
    body1 = """
      Hello Honky !! Tonk,
      this is your email: 11@xy.com11@xy.com.

      Thanks!
      """
    body2 = """
      Hola Mini ## Mouse,
      this is your email: 22@xy.com22@xy.com.

      Gracias
      """
    actual = Mmt.do_dryrun(
      [{"11@xy.com", body1}, {"22@xy.com", body2}], "Test 1")
    expected = ["To: 11@xy.com\nSubject: Test 1\n\nHello Honky !! Tonk,\nthis is your email: 11@xy.com11@xy.com.\n\nThanks!\n---\n",
            "To: 22@xy.com\nSubject: Test 1\n\nHola Mini ## Mouse,\nthis is your email: 22@xy.com22@xy.com.\n\nGracias\n---\n"]
    assert expected == actual
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
    [sender]
    rts@example.com=Frodo Baggins
    [recipients]
    jd@example.com=John Doe III
    mm@gmail.com=Mickey Mouse   # trailing comment!!
    """
  test "read_config() works", context do
    expected = %{
      "sender" => %{"rts@example.com" => ["Frodo", "Baggins"]},
      "recipients" => %{"jd@example.com" => ["John", "Doe III"],
                        "mm@gmail.com" => ["Mickey", "Mouse"]}}
    {:ok, data} = File.open(context[:fpath],
                            fn(f) -> IO.binread(f, :all) end)
    actual = Mmt.read_config(data)
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
      "sender" => %{"rts@example.com" => ["Frodo", "Baggins"]},
      "recipients" => %{"abx.fgh@exact.ly" => ["Charly", "De Gaulle"],
                        "fheh@fphfdd.cc" => ["Gulliver", "Jöllo"]}}
    {:ok, data} = File.open(context[:fpath],
                            fn(f) -> IO.binread(f, :all) end)
    actual = Mmt.read_config(data)
    assert actual == expected
  end


  defp write_file(path, content) do
    {:ok, file} = File.open path, [:write]
    IO.binwrite file, content
    File.close file
  end
end
