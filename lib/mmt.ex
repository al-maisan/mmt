defmodule Mmt do
  @moduledoc """
  Mass mailing tool
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
    {:ok, data} = File.open(parse[:config_path],
                            fn(f) -> IO.binread(f, :all) end)
    case Mmt.check_config(data) do
      :ok -> do_mmt({parse[:template_path], data,
                     parse[:dry_run], parse[:subject]})
      {:error, errors} ->
        IO.puts "!! You have errors in the config file:"
        for e <- errors, do: IO.puts "    * #{e}"
        print_help()
        System.halt(104)
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
      [sender]
      rts@example.com=Frodo Baggins
      [recipients]
      jd@example.com=John Doe III
      mm@gmail.com=Mickey Mouse   # trailing comment!!
      """
    IO.puts help_text
  end


  defp print_sample_template() do
    help_text = """
      FN / LN / EA = first name / last name / email address

      Hello %FN% // %LN%,
      this is your email * 2: %EA%%EA%.

      Thanks!
      """
    IO.puts help_text
  end


  @doc """
  Send out the emails given the template path, configuration path and
  dry-run parameters.
  """
  def do_mmt({tp, config, dr, subj}) do
    {:ok, template} = File.open(tp, fn(f) -> IO.binread(f, :all) end)
    config = read_config(config)
    mails = Enum.map(
      config["recipients"],
      fn {ea, [fna, lna]} -> prep_email({template, ea, fna, lna}) end)

    if dr do
      IO.puts(do_dryrun(mails, subj))
    else
      do_send(mails, subj, config["sender"])
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
  def do_send([{addr, body}|mails], subj, sender) do
    path = write_file(String.rstrip(body))
    cmd = construct_cmd(path, sender, subj, addr)
    :os.cmd(cmd)
    System.cmd("rm", ["-f", path])
    do_send(mails, subj, sender)
  end


  def construct_cmd(path, sender, subj, addr) do
    [{ea, nl}] = Map.to_list(sender)
    header = "\"From: #{Enum.join(nl, " ")} <#{ea}>\""
    cmd = "cat #{path} | mail -a " <> header <> " -s \"#{subj}\" " <> addr
    IO.puts "'#{cmd}'"
    to_char_list(cmd)
  end


  @doc """
  Prepares the text to be printed in case of a dry run.
  """
  def do_dryrun(mails, subj) do
    mails |> Enum.map(fn {ea, body} ->
      body = String.rstrip(body)
      """
      To: #{ea}
      Subject: #{subj}

      #{body}
      ---
      """
      end)
  end


  @doc """
  Prepares a single email given a template and the recipient's email adress,
  first and last name. Returns a 2-tuple containing the recipient's email
  address and the body.
  """
  def prep_email({template, ea, fna, lna}) do
    body = Regex.replace(~r/%EA%/, template, ea, global: true)
    body = Regex.replace(~r/%FN%/, body, fna, global: true)
    body = Regex.replace(~r/%LN%/, body, lna, global: true)

    {ea, body}
  end


  @doc """
  Read the configuration file and return a Map where the keys are the email
  addresses and the values are the full names.
  """
  def read_config(config) do
    { :ok, rx } = Regex.compile(~S"\[(\w+)\]([^[]*)", "ums")
    content = Regex.scan(rx, config, [capture: :all_but_first])
    [sender] = for [k, v] <- content, k == "sender", do: v
    [recipients] = for [k, v] <- content, k == "recipients", do: v
    sender = read_single_config_section(sender)
    recipients = read_single_config_section(recipients)
    %{"sender" => sender, "recipients" => recipients}
  end


  def read_single_config_section(config) do
    String.split(config, "\n")
    |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(
      fn line ->
        [key, value] = String.split(line, "=")
        key = String.strip(key)
        {key, String.split(value, ~r{\s}, parts: 2, trim: true)}
      end)
    |> Enum.into(Map.new)
  end


  @doc """
  Returns :ok for correct config files and {:error, [messages]} for broken
  config files.
  """
  def check_config(config) do
    { :ok, rx } = Regex.compile(~S"\[(\w+)\]([^[]*)", "ums")
    content = Regex.scan(rx, config, [capture: :all_but_first])
    sections = for [k, _v] <- content, do: k
    errors = []

    {_, counts} = Enum.map_reduce(
      sections, HashDict.new,
      fn(x, acc) -> {x, Dict.put(acc, x, Dict.get(acc, x, 0) + 1)} end)

    # Check for missing sections
    missing = (for k <- ["sender", "recipients"], counts[k] == nil, do: k)
      |> Enum.sort
    if Enum.count(missing) > 0 do
      error = "missing sections: '" <> Enum.join(missing, ", ") <> "'"
      errors = [error | errors]
    end

    # Check for repeating sections
    repeating = Enum.filter(counts, fn({_k, v}) -> v > 1 end)
    if Enum.count(repeating) > 0 do
      repeating = (for {k, _v} <- repeating, do: k) |> Enum.sort
      error = "repeating sections: '" <> Enum.join(repeating, ", ") <> "'"
      errors = [error | errors]
    end

    # Check for single sender value
    if not "sender" in repeating && not "sender" in missing do
      [sender_value] = for [k, v] <- content, k == "sender", do: v
      senders = String.split(sender_value, "\n")
      |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
      |> Enum.filter(&String.contains?(&1, "="))
      |> Enum.count
      if senders != 1 do
        errors = ["the sender section requires exactly one entry" | errors]
      end
    end

    if Enum.count(errors) > 0 do
      {:error, errors |> Enum.sort}
    else
      :ok
    end
  end
end
