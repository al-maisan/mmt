defmodule Mmt do
  @moduledoc """
  Mass mailing tool

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

  def main(argv) do
    { parse, _, _ } = OptionParser.parse(
      argv, strict: [help: :boolean, dry_run: :boolean,
                     subject: :string, template_path: :string,
                     config_path: :string, sample_config: :boolean,
                     sample_template: :boolean])

    if parse[:help] do
      print_help()
      System.halt(0)
    end
    if parse[:sample_config] do
      print_sample_config()
      System.halt(0)
    end
    if parse[:sample_template] do
      print_sample_template()
      System.halt(0)
    end
    if !parse[:template_path] do
      IO.puts "Please specify the template file!"
      print_help()
      System.halt(101)
    end
    if !parse[:config_path] do
      IO.puts "Please specify the config file!"
      print_help()
      System.halt(102)
    end
    if !parse[:subject] do
      IO.puts "Please specify the email subject!"
      print_help()
      System.halt(103)
    end
    {:ok, config} = File.open(parse[:config_path], fn(f) -> IO.binread(f, :all) end)
    {:ok, template} = File.open(parse[:template_path], fn(f) -> IO.binread(f, :all) end)
    case Cfg.check_config(config) do
      :ok ->
        config = Cfg.read_config(config)
        do_mmt({template, config, parse[:dry_run], parse[:subject]})
      {:error, errors} ->
        IO.puts "!! You have errors in the config file:"
        for e <- errors, do: IO.puts "    * #{e}"
        print_help()
        System.halt(104)
    end
  end


  @doc """
  Send out the emails given the template, configuration, dry-run flag,
  subject line and the do-attachments flag.
  """
  def do_mmt({template, config, dryrun, subj}) do
    case Attmt.prepare_attachments(config) do
      {:ok, _} ->
        mails = prep_emails(config, template)
        if dryrun do
          IO.puts(do_dryrun(mails, subj, config))
        else
          do_send(mails, subj, config)
          IO.puts("\nSent #{Enum.count(mails)} emails.\n")
        end
      {:error, error_msg} -> IO.puts error_msg; System.halt(105)
    end
  end


  defp write_file(content) do
    {path, 0} = System.cmd("mktemp", ["/tmp/mmt.XXXXX.eml"])
    path = String.rstrip(path)
    {:ok, file} = File.open path, [:write]
    IO.binwrite file, content
    File.close file
    path
  end


  @doc """
  Tail recursive function that actually sends the emails by calling
  the 'mail' command via a shell.
  """
  def do_send([], _, _), do: nil
  def do_send([{eaddr, body}|mails], subj, config) do
    path = write_file(String.rstrip(body))
    cmd = construct_cmd(path, config, subj, eaddr)
    :os.cmd(cmd)
    System.cmd("rm", ["-f", path])
    do_send(mails, subj, config)
  end


  @doc """
  Return possibly empty list with email headers.
  """
  def prep_headers(config) do
    saddr = Map.get(config["general"], "sender-email")
    sname = Map.get(config["general"], "sender-name")
    headers = if saddr != nil and sname != nil do
      ["From: #{sname} <#{saddr}>"]
    else
      []
    end
    # According to https://www.ietf.org/rfc/rfc2822.txt Cc and Reply-To have
    # the same form/syntax
    cc = Map.get(config["general"], "Cc")
    headers = if cc != nil do
      ccs = String.split(cc, ~r{\s*,\s*}) |> Enum.sort |> Enum.join(", ")
      ["Cc: #{String.trim(ccs)}" | headers]
    else
      headers
    end
    rt = Map.get(config["general"], "Reply-To")
    headers = if rt != nil do
      rts = String.split(rt, ~r{\s*,\s*}) |> Enum.sort |> Enum.join(", ")
      ["Reply-To: #{String.trim(rts)}" | headers]
    else
      headers
    end
    headers |> Enum.sort
  end


  def construct_cmd(path, config, subj, eaddr) do
    mprog = Map.get(config["general"], "mail-prog", "mail")
    atp = get_attachment_path(eaddr, config)
    cmd = if atp != nil do
      "cat #{path} | #{mprog} -s \"#{subj}\" -A #{atp}"
    else
      "cat #{path} | #{mprog} -s \"#{subj}\""
    end
    [cmd,
     (prep_headers(config) |> Enum.map(fn h -> "-a \"#{h}\"" end) |> Enum.join(" ")),
     "#{eaddr}"]
    |> Enum.filter(fn s -> String.length(s) > 0 end)
    |> Enum.join(" ")
    |> to_char_list
  end


  @doc """
  Checks whether the recipient's email should include an attachment and
  whether the latter was crypted.
  Return `nil` if there is no attachment or the proper path.
  """
  def get_attachment_path(eaddr, config) do
    if config["attachments"] do
      atf = config["attachments"][eaddr]
      atp = config["general"]["attachment-path"] <> "/" <> atf
      if config["general"]["encrypt-attachments"] do
        atp <> ".gpg"
      else
        atp
      end
    else
      nil
    end
  end


  @doc """
  Prepares the text to be printed in case of a dry run.
  """
  def do_dryrun(mails, subj, config) do
    mails |> Enum.map(fn {eaddr, body} ->
      body = String.rstrip(body)
      case get_attachment_path(eaddr, config) do
        nil ->
          """
          To: #{eaddr}
          Subject: #{subj}

          #{body}
          ---
          """
        atp ->
          """
          To: #{eaddr}
          Subject: #{subj}

          #{body}

          <<#{atp}>>
          ---
          """
      end
    end)
  end


  @doc """
  Generates the email bodies for all the recipients.
  Return a list of tuples of `[{eaddr1, body1}, .., {eaddrN, bodyN}]`
  """
  def prep_emails(config, template) do
    Enum.map(
      config["recipients"],
      fn {eaddr, name} -> prep_email({template, eaddr, name}) end)
  end


  @doc """
  Prepares a single email given a template, the recipient's email adress
  and name.
  Return a tuple of `{eaddr, body}`
  """
  def prep_email({template, eaddr, name}) do
    body = Regex.replace(~r/%EA%/, template, eaddr, global: true)
    nd = parse_name_data(name)
    body = Regex.replace(~r/%FN%/, body, nd["FN"], global: true)
    body = Regex.replace(~r/%LN%/, body, nd["LN"], global: true)
    body = Enum.reduce(nd, body, fn {k,v}, acc ->
        if k != "FN" and k != "LN" do
          Regex.replace(~r/%#{k}%/, acc, v, global: true)
        else
          acc
        end
      end)

    {eaddr, body}
  end


  @doc """
  Parses name data e.g. something like

    Hans Dieter Maier|BN=3345|TAGS=security,bug,cloud|FN=Joe

  would result in the following `Map`:

    %{ "FN" => "Joe", "LN" => "Dieter Maier", "BN" => "3345",
       "TAGS" => "security,bug,cloud" }

  Return a `Map` with the data found
  """
  def parse_name_data(name_data) do
    if String.length(name_data) > 0 do
      [name | data] = String.split(name_data, "|", trim: true)
      |> Enum.map(&String.trim/1)
      [fname | lnames] = String.split(name, ~r{\s+}, trim: true)
      result = %{ "FN" => fname, "LN" => Enum.join(lnames, " ")}
      try do
        Enum.reduce(data, result, fn x, acc ->
            [k, v] = Regex.split(~r/=/, x) |> Enum.map(&String.trim/1)
            Map.put(acc, k, v)
          end)
      rescue
        e in MatchError -> raise "Invalid config: #{e.term}"
      end
    else
      %{}
    end
  end


  defp print_help() do
    help_text = """

      Send emails in bulk based on a template and a config file containing
      the email body and recipient names/addresses respectively.

        --help            print this help
        --config-path     path to the config file
        --dry-run         print commands that would be executed, but do not
                          execute them
        --subject         email subject
        --template-path   path to the template file
        --sample-config   prints a sample config file to stdout
        --sample-template prints a sample template file to stdout
      """
    IO.puts help_text
  end


  defp print_sample_config() do
    help_text = """
      # anything that follows a hash is a comment
      # email address is to the left of the '=' sign, first word after is
      # the first name, the rest is the surname
      [general]
      mail-prog=gnu-mail # arch linux, just 'mail' on ubuntu
      #attachment-path=/tmp
      #encrypt-attachments=true
      sender-email=rts@example.com
      sender-name=Frodo Baggins
      #Cc=weirdo@nsb.gov, cc@example.com
      [recipients]
      jd@example.com=John Doe III
      mm@gmail.com=Mickey Mouse   # trailing comment!!
      [attachments]
      jd@example.com=01.pdf
      mm@gmail.com=02.pdf
      """
    IO.puts help_text
  end


  defp print_sample_template() do
    help_text = """
      FN / LN / EA = first name / last name / email address

      Hello %FN% // %LN%,
      this is your email * 2: %EA%%EA%.
      """
    IO.puts help_text
  end
end
