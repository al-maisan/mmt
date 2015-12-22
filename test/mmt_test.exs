defmodule MmtTest do
  use ExUnit.Case
  doctest Mmt


  test "prep_emails()" do
    config = """
      # config file with repeating keys (email addresses)
          # dangling comment
      [sender]
      rts@example.com=Frodo Baggins
      [recipients]
      abx.fgh@exact.ly=Éso Pita
      fheh@fphfdd.cc=Gulliver    Jöllo
      abx.fgh@exact.ly=   Charly      De Gaulle
      [attachments]
      abx.fgh@exact.ly=01
      fheh@fphfdd.cc=02
      abx.fgh@exact.ly=03
      """
    template = """
      Hello %FN% // %LN% // %EA%
      """
    expected = [
      {"abx.fgh@exact.ly", "Hello Charly // De Gaulle // abx.fgh@exact.ly\n"},
      {"fheh@fphfdd.cc", "Hello Gulliver // Jöllo // fheh@fphfdd.cc\n"}]
    config = Cfg.read_config(config)
    actual = Mmt.prep_emails(config, template)
    assert expected == actual
  end


  test "construct_cmd()" do
    path = "/tmp/mmt.kTuJU.eml"
    config = %{
      "general" => %{"sender-email" => "mmt@chlo.cc",
                     "sender-name" => "Frodo Baggins"}}
    subj = "hello from mmt"
    addr = "r2@ahfdo.cc"
    expected = 'cat /tmp/mmt.kTuJU.eml | mail -a "From: Frodo Baggins <mmt@chlo.cc>" -s "hello from mmt" r2@ahfdo.cc'

    actual = Mmt.construct_cmd(path, config, subj, addr)
    assert expected == actual
  end


  test "email address substitution works" do
    template = """
      Hello buddy,
      this is your email: %EA%%EA%.

      Thanks!
      """
    body = """
      Hello buddy,
      this is your email: 1@xy.com1@xy.com.

      Thanks!
      """
    actual = Mmt.prep_email({template, "1@xy.com", "Not Needed"})
    assert {"1@xy.com", body} == actual
  end


  test "first name substitution works" do
    template = """
      Hello %FN%,
      this is your email: %EA%%EA%.

      Thanks!
      """
    body = """
      Hello Goth,
      this is your email: 2@xy.com2@xy.com.

      Thanks!
      """
    actual = Mmt.prep_email({template, "2@xy.com", "Goth Mox"})
    assert {"2@xy.com", body} == actual
  end


  test "last name substitution works" do
    template = """
      Hello %FN% // %LN%,
      this is your email: %EA%%EA%.

      Thanks!
      """
    body = """
      Hello King // Kong,
      this is your email: 3@xy.com3@xy.com.

      Thanks!
      """
    actual = Mmt.prep_email({template, "3@xy.com", "King Kong"})
    assert {"3@xy.com", body} == actual
  end


  test "dry_run() works" do
    body1 = """
      Hello Honky !! Tonk,
      this is your email: 11@xy.com11@xy.com.

      Thanks!
      """
    body2 = """
      Hola Mini ## Mouse,
      this is your email: 22@xy.com22@xy.com.

      Gracias
      """
    actual = Mmt.do_dryrun(
      [{"11@xy.com", body1}, {"22@xy.com", body2}], "Test 1")
    expected = ["To: 11@xy.com\nSubject: Test 1\n\nHello Honky !! Tonk,\nthis is your email: 11@xy.com11@xy.com.\n\nThanks!\n---\n",
            "To: 22@xy.com\nSubject: Test 1\n\nHola Mini ## Mouse,\nthis is your email: 22@xy.com22@xy.com.\n\nGracias\n---\n"]
    assert expected == actual
  end
end
