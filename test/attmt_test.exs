defmodule AttmtTest do
  @moduledoc """
  Tests pertaining to attachment functionality.

  mmt is a simple utility that allows the automated sending of emails
  using a configuration file and a template for the email body. It was
  written in Elixir and used mainly on linux systems like Arch Linux
  and Ubuntu.
  Copyright (C) 2015-2016  Muharem Hrnjadovic <muharem@linux.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
  """
  use ExUnit.Case

  test "attachments_present?(), happy case" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    assert Attmt.attachments_present?(config) == true
  end


  test "attachments_present?(), missing attachment path" do
    config = %{
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    assert Attmt.attachments_present?(config) == true
  end


  test "attachments_present?(), no attachments" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"}}
    assert Attmt.attachments_present?(config) == false
  end


  test "attachments_present?(), no attachments and no attachment path" do
    config = %{
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"}}
    assert Attmt.attachments_present?(config) == false
  end


  test "check_config(), happy case" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    assert Attmt.check_config(config) == {:ok, "all set!"}
  end


  test "check_config(), undefined attachment path" do
    config = %{
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = "check config: no attachment path defined"
    assert Attmt.check_config(config) == {:error, error_msg}
  end


  test "check_config(), no attachment defined for 1+ email" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse",
                        "xgt@gmx.com" => "Bugs Bunny"},
      "attachments" => %{"mm@gmail.com" => "bb.pdf"}}
    error_msg = "No attachments defined for: jd@example.com, xgt@gmx.com"
    assert Attmt.check_config(config) == {:error, String.rstrip(error_msg)}
  end


  test "check_config(), attachment defined for 1+ email not in recipients list" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{
                        "mm@gmail.com" => "Mickey     Mouse",
                        "mn@gmail.com" => "Goofy Goose",
                        "mo@gmail.com" => "Daisy Maze"},
      "attachments" => %{"jd@example.com" => "a1.pdf",
                         "mm@gmail.com" => "b2.pdf",
                         "mn@gmail.com" => "a3.pdf",
                         "mo@gmail.com" => "x4.pdf",
                         "xtg@gmx.com" => "b5.pdf"}}
    error_msg = "Unlisted recipients: jd@example.com, xtg@gmx.com"
    assert Attmt.check_config(config) == {:error, String.rstrip(error_msg)}
  end


  test "check_config(), no attachment defined at all" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse",
                        "xgt@gmx.com" => "Bugs Bunny"}}
    assert Attmt.check_config(config) == {:ok, "all set!"}
  end


  test "check_config(), same attachment defined for 1+ email" do
    config = %{
      "general" => %{"attachment-path" => "/whatever"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse",
                        "mn@gmail.com" => "Goofy Goose",
                        "mo@gmail.com" => "Daisy Maze",
                        "xgt@gmx.com" => "Bugs Bunny"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf",
                         "mn@gmail.com" => "aa.pdf",
                         "mo@gmail.com" => "xx.pdf",
                         "xgt@gmx.com" => "bb.pdf"}}
    error_msg = "Attachment(s) (aa.pdf, bb.pdf) used for more than one email"
    assert Attmt.check_config(config) == {:error, error_msg}
  end


  test "check_config(), same attachment defined for 1+ email and allow-dups flag set" do
    config = %{
      "general" => %{"attachment-path" => "/whatever",
                     "allow-duplicate-attachments" => true},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse",
                        "mn@gmail.com" => "Goofy Goose",
                        "mo@gmail.com" => "Daisy Maze",
                        "xgt@gmx.com" => "Bugs Bunny"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf",
                         "mn@gmail.com" => "aa.pdf",
                         "mo@gmail.com" => "xx.pdf",
                         "xgt@gmx.com" => "bb.pdf"}}
    assert Attmt.check_config(config) == {:ok, "all set!"}
  end
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
    if context[:dirmode] != nil do
      File.chmod!(tpath, context[:dirmode])
    end

    on_exit fn ->
      System.cmd("rm", ["-rf", tpath])
    end

    {:ok, tpath: tpath}
  end


  @tag afs: [{"aa.pdf", 0o600}, {"bb.pdf", 0o644}]
  test "check_files(), happy case", context do
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
    assert Attmt.check_files(config) == {:error, String.rstrip(error_msg)}
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
    assert Attmt.check_files(config) == {:error, String.rstrip(error_msg)}
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
    assert Attmt.check_files(config) == {:error, String.rstrip(error_msg)}
  end


  @tag afs: []
  test "check_files(), non-existent attachment path" do
    config = %{
      "general" => %{"attachment-path" => "/does/not/exist"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = "Missing or unreadable attachment path: /does/not/exist"
    assert Attmt.check_files(config) == {:error, error_msg}
  end


  @tag afs: []
  @tag dirmode: 0o255
  test "check_files(), unreadable attachment path", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = "Missing or unreadable attachment path: #{context[:tpath]}"
    assert Attmt.check_files(config) == {:error, error_msg}
  end


  @tag afs: []
  test "check_files(), undefined attachment path" do
    config = %{
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    error_msg = "check files: no attachment path defined"
    assert Attmt.check_files(config) == {:error, error_msg}
  end


  @tag afs: [{"aa.pdf", 0o600}, {"bb.pdf", 0o644}]
  test "encrypt_attachments(), happy case", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf"}}
    {:ok, cwd} = File.cwd()
    assert Attmt.encrypt_attachments(config, ["--homedir", cwd <> "/test/keyring"]) == {:ok, "all set!"}
    {:ok, atfs} = File.ls(context[:tpath])
    assert Enum.sort(atfs) == ["aa.pdf", "aa.pdf.gpg", "bb.pdf", "bb.pdf.gpg"]
  end


  @tag afs: [{"aa.pdf", 0o600}, {"bb.pdf", 0o644}, {"cc.pdf", 0o644}]
  test "encrypt_attachments(), one key missing", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse",
                        "mx@gmail.com" => "Mickey Xillu"},
      "attachments" => %{"jd@example.com" => "aa.pdf",
                         "mm@gmail.com" => "bb.pdf",
                         "mx@gmail.com" => "cc.pdf"}}
    {:ok, cwd} = File.cwd()
    {:error, message} = Attmt.encrypt_attachments(config, ["--homedir", cwd <> "/test/keyring"])
    gre = ~r/gpg: mx@gmail.com: skipped: No public key.*cc.pdf: encryption failed: No public key/s
    assert Regex.match?(gre, message)
    {:ok, atfs} = File.ls(context[:tpath])
    assert Enum.sort(atfs) == ["aa.pdf", "aa.pdf.gpg", "bb.pdf", "bb.pdf.gpg", "cc.pdf"]
  end


  @tag afs: [{"aa.pdf", 0o600}, {"bb.pdf", 0o644}]
  test "encrypt_attachments(), all keys missing", context do
    config = %{
      "general" => %{"attachment-path" => context[:tpath]},
      "recipients" => %{"ab@example.com" => "John    Doe    III",
                        "cd@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"ab@example.com" => "aa.pdf",
                         "cd@gmail.com" => "bb.pdf"}}

    {:ok, cwd} = File.cwd()
    {:error, message} = Attmt.encrypt_attachments(config, ["--homedir", cwd <> "/test/keyring"])
    IO.puts("\n#{message}")
    gre_string = """
      gpg: ab@example.com: skipped: No public key
      .*
      aa.pdf: encryption failed: No public key
      .*
      gpg: cd@gmail.com: skipped: No public key
      .*
      bb.pdf: encryption failed: No public key
      """
        |> String.split("\n") |> Enum.join
    gre = ~r/#{gre_string}/s
    assert Regex.match?(gre, message)
    {:ok, atfs} = File.ls(context[:tpath])
    assert Enum.sort(atfs) == ["aa.pdf", "bb.pdf"]
  end
end
