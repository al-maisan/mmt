defmodule Mmt do
  @moduledoc """
  Mass mailing tool
  """

  def main(argv) do
    { parse, _, _ } = OptionParser.parse(
      argv, strict: [help: :boolean, dry_run: :boolean,
                     template_path: :string, config_path: :string])

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
    do_mmt({parse[:template_path], parse[:config_path], parse[:dry_run]})
  end


  defp print_help() do
    help_text = """

      Send emails in bulk based on a template and a config file containing
      the email body and recipient names/addresses respectively.

        --help          print this help
        --config-path   path to the config file
        --dry-run       print commands that would be executed, but do not
                        execute them
        --template-path path to the template file
      """
    IO.puts help_text
  end


  def do_mmt({tp, cp, dr}) do
  end


  def read_config(cp) do
    {:ok, data} = File.open(cp, fn(f) -> IO.read(f, :all) end)
    String.split(data, "\n")
    |> Enum.filter(&String.contains?(&1, "="))
    |> Enum.map(fn(x) -> Regex.replace(~R/#.*$/, x, "") end)
    |> Enum.map(
      fn line ->
        [key, value] = String.split(line, "=")
        key = String.strip(key)
        {key, String.strip(value)}
      end)
    |> Enum.into(Map.new)
  end
end
