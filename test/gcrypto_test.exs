defmodule GCryptoTest do
  use ExUnit.Case
  doctest GCrypto

  @gpg_out ["""
  sub:f:1024:16:2B950D93B5252E67:1077658925::::::e:
  pub:-:1024:17:E9149F67EEA6AD6A:1155934878:::-:::scSC:
  uid:-::::1155934878::B38B08533690879502A95A76A0C1EC8FF819EC6B::http\x3a//bazaar-vcs.org package repository:
  pub:f:1024:17:40976EAF437D05B5:1095016255:::f:::scESC:
  uid:f::::1095016255::B84AE656F4F5A826C273A458512EF8E282754CE1::Ubuntu Archive Automatic Signing Key <ftpmaster@ubuntu.com>:
  sub:f:2048:16:D265ECE6D3FE78FB:1155594795::::::e:
  pub:f:1024:17:C2EB4CAB4DAD18FA:1170444744:::f:::scESC:
  uid:f::::1183154865::A3BCDF3DEDD753BC86761214CFB5BA9A1B8F16A5::Graham Binns <graham.binns@gmail.com>:
  uid:f::::1183154871::8E5BC7D0EE93B24A8C12FFDD23EF037D87E1D7BF::Graham Binns <graham@grahambinns.com>:
  uid:f::::1183385295::6C511FB919FFEFDC52ED7519DB7C07C62E60A8DA::Graham Binns <graham.binns@canonical.com>:
  uid:r::::::3B513AF02D63DD87FEB075EF7C6FCC0A750FFFBD::Graham Binns <graham.binns@monstermob.com>:
  uid:r::::::36AF7C338AB0E03DE1DAE24D6D20DD543E5E91CC::Graham Binns <graham@deadrobotssociety.com>:
  uid:r::::::BE586F7092096E45669578D8CE79FAE9B6C470B2::Graham Binns (Clog Project email) <graham@clogproject.org>:
  uat:f::::1204669224::F259C680AAE5582F16CFA4C86BA17B0EFCA4D679::1 6671:
  uid:f::::1205441526::3ABE3448306D07371DBA103924EA47DE796BF77B::Graham Binns <graham@ubuntu.com>:
  uid:f::::1205441606::419F8F4231D5A6BF4F20EF18DC2FB2CC9A922B19::Graham Binns <graham@canonical.com>:
  uid:f::::1208456249::0B99934698B9D9E71B135634E5481D44D1492A0A::Graham Binns <gmb@canonical.com>:
  uid:f::::1208456260::111AA2F1FF1F8A0FF39E4DBCED0AD060AA433039::Graham Binns <gmb@grahambinns.com>:
  sub:f:2048:16:0F50E7C0D6C989BC:1170444756::::::e:
  pub:f:1024:17:D9866941EA5BBD71:1132794790:::f:::scESC:
  uid:f::::1242262743::A852CD4022C0507FE210A510D70E6393C32CF7BC::Barry A. Warsaw <barry@warsaw.us>:
  uid:f::::1242262756::167453DD2586EC0EDC1A7B6FBC7968BC570E8F5A::Barry A. Warsaw <barry@wooz.org>:
  uid:f::::1242262756::8613B20771901EA1F102E19BF25D570AC863B42D::Barry A. Warsaw <barry@python.org>:
  uid:f::::1242262756::B354F1CA56573176BCC9E3144B7207EB788B3D2B::Barry A. Warsaw <barry@canonical.com>:
  uid:f::::1242262756::0A8A5728D3B50BFD144CBC326C68B954010431E9::Barry Warsaw (GNU Mailman) <barry@list.org>:
  uid:f::::1242262756::C462F982D911C23C9F20BD3B843EBC68AE06B4C1::Barry A. Warsaw <barry.warsaw@canonical.com>:
  sub:f:2048:16:4CA09D30D792C43B:1132794795::::::e:
  pub:f:1024:17:7757EF2381BB5910:1159786011:::f:::scaESCA:
  uid:f::::1172039015::CCE5AFF7E4088304AF9D2AA751C0C42C820F85C2::Tim Penhey <tim@penhey.net>:
  uid:f::::1159892758::152D425F246C83E9D846965EBC2ECF28EF3DFB5B::Tim Penhey <tim@canonical.com>:
  uid:f::::1159892797::DE3757A9D2608D1463F4E5F93B509367EDD78D5D::Tim Penhey <tim.penhey@canonical.com>:
  uid:f::::1159786011::28378A5E4880277C0F9B5EA666E5AE13C97F6810::Tim Penhey (Canonical key) <tim@penhey.net>:
  sub:f:1024:16:7459F6ACBB71DDA3:1159786012::::::e:
  pub:f:1024:17:01FA998FBAC6374A:1065074470:::f:::scESC:
  uid:f::::1242284167::D1B1C88C4725C9174B709CD878B46CCA54EE4E2F::Stuart Bishop <stuart@stuartbishop.net>:
  uid:f::::1242284167::C6047BBA854F25A940F76AAE2AC4678C53A33BEF::Stuart Bishop <stub@ubuntu.com>:
  uid:f::::1153318735::585135D671CE7D8BCE2582A013C4D91240D139B5::Stuart Bishop <stub@ubuntu.com>:
  uid:f::::1239187659::CD061BF38BF6005CB58ECB0192009F228460BFA2::Dave P Martin </o=arm/ou=EMEA/cn=Recipients/cn=davem>:
  """]

  test "filter_uids()" do
    expected = ["barry.warsaw@canonical.com", "barry@canonical.com",
      "barry@list.org", "barry@python.org", "barry@warsaw.us",
      "barry@wooz.org", "ftpmaster@ubuntu.com", "gmb@canonical.com",
      "gmb@grahambinns.com", "graham.binns@canonical.com",
      "graham.binns@gmail.com", "graham@canonical.com",
      "graham@grahambinns.com", "graham@ubuntu.com", "stuart@stuartbishop.net",
      "stub@ubuntu.com", "tim.penhey@canonical.com", "tim@canonical.com",
      "tim@penhey.net"]

    actual = GCrypto.filter_uids(@gpg_out)
    assert expected == actual
  end


  test "check_keys() with empty uid list" do
    config = %{"general" => %{"encrypt-attachments" => "true"},
               "recipients" => %{
                  "jd@example.com" => {"01", ["John", "Doe III"]},
                  "mm@gmail.com" => {"02", ["Mickey", "Mouse"]}}}
    expected = {:error, "No gpg keys for:\n  jd@example.com\n  mm@gmail.com\n"}
    assert expected == GCrypto.check_keys(config, [])
  end


  test "check_keys() with partial uid list" do
    config = %{"general" => %{"encrypt-attachments" => "true"},
               "recipients" => %{
                  "jd@example.com" => {"01", ["John", "Doe III"]},
                  "mm@gmail.com" => {"02", ["Mickey", "Mouse"]}}}
    expected = {:error, "No gpg keys for:\n  mm@gmail.com\n"}
    assert expected == GCrypto.check_keys(config, ["jd@example.com"])
  end


  test "check_keys() with full uid list" do
    config = %{"general" => %{"encrypt-attachments" => "true"},
               "recipients" => %{
                  "jd@example.com" => {"01", ["John", "Doe III"]},
                  "mm@gmail.com" => {"02", ["Mickey", "Mouse"]}}}
    expected = {:ok, "all set!"}
    assert expected == GCrypto.check_keys(config, ["jd@example.com", "mm@gmail.com"])
  end


  test "check_keys() with clear text attachments" do
    config = %{"general" => %{"encrypt-attachments" => "false"},
               "recipients" => %{
                  "jd@example.com" => {"01", ["John", "Doe III"]},
                  "mm@gmail.com" => {"02", ["Mickey", "Mouse"]}}}
    expected = {:ok, "attachments not crypted"}
    assert expected == GCrypto.check_keys(config, ["jd@example.com"])
  end


  test "check_keys() with no recipients" do
    config = %{"general" => %{"encrypt-attachments" => "false"}}
    expected = {:ok, "attachments not crypted"}
    assert expected == GCrypto.check_keys(config, [])
  end


  test "check_keys() with no general config section" do
    config = %{"recipients" => %{
                  "jd@example.com" => {"01", ["John", "Doe III"]},
                  "mm@gmail.com" => {"02", ["Mickey", "Mouse"]}}}
    expected = {:ok, "attachments not crypted"}
    assert expected == GCrypto.check_keys(config, ["jd@example.com"])
  end
end
