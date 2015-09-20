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
    do_mmt({parse[:template_path], parse[:config_path], parse[:dry_run],
            parse[:subject]})
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
  def do_mmt({tp, cp, dr, subj}) do
    {:ok, template} = File.open(tp, fn(f) -> IO.binread(f, :all) end)
    who = read_config(cp)
    mails = Enum.map(
      who, fn {ea, [fna, lna]} -> prep_email({template, ea, fna, lna}) end)

    if dr do
      IO.puts(do_dryrun(mails, subj))
    else
      do_send(mails, subj)
    end
  end


  def do_send(_m, _s) do
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
  def read_config(cp) do
    {:ok, data} = File.open(cp, fn(f) -> IO.binread(f, :all) end)
    String.split(data, "\n")
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
  Returns either :ok or {:error, message} if the config file is correct
  or faulty.
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
