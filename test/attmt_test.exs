defmodule AttmtTest do
  use ExUnit.Case

end


defmodule AttmtFilesTest do
  use ExUnit.Case
  doctest Attmt


  setup context do
    {tpath, 0} = System.cmd("mktemp", ["-d", "/tmp/mmt.XXXXX.atd"])
    tpath = String.rstrip(tpath)
    Enum.each(context[:afs], fn {af, mode} ->
      path = tpath <> "/" <> af
      File.touch!(path)
      File.chmod!(path, mode)
    end)

    on_exit fn ->
      System.cmd("rm", ["-rf", tpath])
    end

    {:ok, tpath: tpath}
  end


  @tag afs: [{"aa.pdf", 0o600}, {"bb.pdf", 0o644}]
  test "check_files(), happy path", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    assert Attmt.check_files(config) == {:ok, "all set!"}
  end


  @tag afs: [{"aa.pdf", 0o100}, {"bb.pdf", 0o244}]
  test "check_files(), no files readable", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = """
      Missing or unreadable attachment(s) in the #{context[:tpath]} directory:
          aa.pdf
          bb.pdf
      """
    assert Attmt.check_files(config) == {:error, error_msg}
  end


  @tag afs: [{"bb.pdf", 0o244}]
  test "check_files(), unreadable and missing files", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = """
      Missing or unreadable attachment(s) in the #{context[:tpath]} directory:
          aa.pdf
          bb.pdf
      """
    assert Attmt.check_files(config) == {:error, error_msg}
  end


  @tag afs: []
  test "check_files(), missing files", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = """
      Missing or unreadable attachment(s) in the #{context[:tpath]} directory:
          aa.pdf
          bb.pdf
      """
    assert Attmt.check_files(config) == {:error, error_msg}
  end
end