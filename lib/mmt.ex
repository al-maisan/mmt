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
    {:ok, config} = File.open(parse[:config_path], fn(f) -> IO.binread(f, :all) end)
    {:ok, template} = File.open(parse[:template_path],
                                fn(f) -> IO.binread(f, :all) end)
    case Cfg.check_config(config) do
      :ok -> do_mmt({template, config, parse[:dry_run], parse[:subject]})
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
      [general]
      attachment1-name=%FN%-salary-info-for-September-2015
      attachment-path=/tmp
      encrypt-attachments=true
      sender_email=rts@example.com
      sender_name=Frodo Baggins
      [recipients]
      01; jd@example.com=John Doe III
      02; mm@gmail.com=Mickey Mouse   # trailing comment!!
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


  @doc """
  Send out the emails given the template path, configuration path and
  dry-run parameters.
  """
  def do_mmt({template, config, dr, subj}) do
    mails = prep_emails(config, template)
    if dr do
      IO.puts(do_dryrun(mails, subj))
    else
      do_send(mails, subj, config["general"])
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
  def do_send([{addr, body}|mails], subj, general) do
    path = write_file(String.rstrip(body))
    cmd = construct_cmd(path, general, subj, addr)
    :os.cmd(cmd)
    System.cmd("rm", ["-f", path])
    do_send(mails, subj, general)
  end


  def construct_cmd(path, general, subj, addr) do
    eaddr = Map.get(general, "sender_email", "no@return.email")
    name = Map.get(general, "sender_name", "Do not reply")
    header = "\"From: #{name} <#{eaddr}>\""
    cmd = "cat #{path} | mail -a " <> header <> " -s \"#{subj}\" " <> addr
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


  def prep_emails(config, template) do
    config = Cfg.read_config(config)
    Enum.map(
      config["recipients"],
      fn {ea, {_, [fna, lna]}} -> prep_email({template, ea, fna, lna}) end)
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
end
