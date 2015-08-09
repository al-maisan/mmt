defmodule Mmt do
  @moduledoc """
  Mass mailing tool
  """

  def main(argv) do
    { parse, _, _ } = OptionParser.parse(
      argv, strict: [help: :boolean, dry_run: :boolean,
                     subject: :string, template_path: :string,
                     config_path: :string])

    if parse[:help] do
      print_help()
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

        --help          print this help
        --config-path   path to the config file
        --dry-run       print commands that would be executed, but do not
                        execute them
        --subject       email subject
        --template-path path to the template file
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
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(fn(x) -> Regex.replace(~R/\s*#.*$/, x, "") end)
    |> Enum.map(
      fn line ->
        [key, value] = String.split(line, "=")
        key = String.strip(key)
        {key, String.split(value, ~r{\s}, parts: 2, trim: true)}
      end)
    |> Enum.into(Map.new)
  end
end
