defmodule CfgTest do
  @moduledoc """
  Tests pertaining to configuration files.

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
  doctest Cfg

  test "check_config() complains about missing sections" do
    config = """
      [a]
      [b]
      """
    actual = Cfg.check_config(config)
    assert {:error, ["missing sections: 'recipients'"]} == actual
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
    assert {:error, ["missing sections: 'recipients'", "repeating sections: 'a, b'"]} == actual
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


  test "convert_value() with true" do
    assert true == Cfg.convert_value("true")
    assert true == Cfg.convert_value("   true")
    assert true == Cfg.convert_value("   true   ")
  end


  test "convert_value() with false" do
    assert false == Cfg.convert_value("false")
    assert false == Cfg.convert_value("   false")
    assert false == Cfg.convert_value("   false   ")
  end


  test "convert_value() with integers" do
    assert 123 == Cfg.convert_value("123")
    assert 456 == Cfg.convert_value("   456")
    assert 789 == Cfg.convert_value("   789   ")
  end


  test "convert_value() with flotas" do
    assert 12.3 == Cfg.convert_value("12.3")
    assert 4.56 == Cfg.convert_value("   4.56")
    assert 0.789 == Cfg.convert_value("   0.789   ")
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
    [general]
    CC =  hello@joe.com , arhg@lhfe.ddk   
    """
  test "read_config(), multiple CC addresses", context do
    expected = %{
      "general" => %{"CC" => "hello@joe.com , arhg@lhfe.ddk"}}
    {:ok, data} = File.open(context[:fpath], fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  @tag content: """
    [general]
    CC =  hello@joe.com
    """
  test "read_config(), single CC address", context do
    expected = %{
      "general" => %{"CC" => "hello@joe.com"}}
    {:ok, data} = File.open(context[:fpath], fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  @tag content: """
    [general]
    CC =                    
    """
  test "read_config(), no CC address", context do
    expected = %{
      "general" => %{"CC" => ""}}
    {:ok, data} = File.open(context[:fpath], fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  @tag content: """
    # Easy version
    [general]
    attachment-name=%FN%-salary-info-for-Sep-2015
    attachment-path=/tmp
    encrypt-attachments=true
    sender-email=rts@example.com
    sender-name=Frodo Baggins
    [recipients]
    jd@example.com=John    Doe    III
    mm@gmail.com=Mickey     Mouse   # trailing comment!!
    [attachments]
    jd@example.com=aa
    mm@gmail.com=bb
    """
  test "read_config() works", context do
    expected = %{
      "general" => %{"attachment-path" => "/tmp",
                     "attachment-name" => "%FN%-salary-info-for-Sep-2015",
                     "encrypt-attachments" => "true",
                     "sender-email" => "rts@example.com",
                     "sender-name" => "Frodo Baggins"},
      "recipients" => %{"jd@example.com" => "John    Doe    III",
                        "mm@gmail.com" => "Mickey     Mouse"},
      "attachments" => %{"jd@example.com" => "aa",
                         "mm@gmail.com" => "bb"}}
    {:ok, data} = File.open(context[:fpath], fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  @tag content: """
    # config file with repeating keys (email addresses)
        # dangling comment
    [general]
    sender-email=rts@example.com
    sender-name=Frodo Baggins
    attachment-extension=doc
    [recipients]
    abx.fgh@exact.ly=Éso Pita
    fheh@fphfdd.cc=Gulliver    Jöllo
    abx.fgh@exact.ly=   Charly      De Gaulle
    [attachments]
    abx.fgh@exact.ly=01
    fheh@fphfdd.cc=02
    abx.fgh@exact.ly=03
    """
  test "read_config() with repeated keys", context do
    expected = %{
      "general" => %{"sender-email" => "rts@example.com",
                     "attachment-extension" => "doc",
                     "sender-name" => "Frodo Baggins"},
      "recipients" => %{"abx.fgh@exact.ly" => "Charly      De Gaulle",
                        "fheh@fphfdd.cc" => "Gulliver    Jöllo"},
      "attachments" => %{"abx.fgh@exact.ly" => "03",
                         "fheh@fphfdd.cc" => "02"}}
    {:ok, data} = File.open(context[:fpath], fn(f) -> IO.binread(f, :all) end)
    actual = Cfg.read_config(data)
    assert actual == expected
  end


  defp write_file(path, content) do
    {:ok, file} = File.open path, [:write]
    IO.binwrite file, content
    File.close file
  end
end
