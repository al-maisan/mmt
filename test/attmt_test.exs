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
    expected = %{
      "general" => %{"attachment-path" => context[:tpath],
                     "sender-name" => "Frodo Baggins"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
  end
end
